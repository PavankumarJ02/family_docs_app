import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:family_docs_app/db/database_helper.dart';
import 'package:family_docs_app/services/document_classifier_service.dart';
import 'package:family_docs_app/services/expiry_detector_service.dart';
import 'package:family_docs_app/services/notification_service.dart';
import 'package:family_docs_app/services/ocr_service.dart';

class _FakeOcrEngine implements OcrEngine {
  final Map<String, OcrPageResult> responses;
  final Exception? errorToThrow;

  _FakeOcrEngine({this.responses = const {}, this.errorToThrow});

  @override
  Future<OcrPageResult> recognizeImageFile(
    String imagePath, {
    int pageNumber = 1,
  }) async {
    if (errorToThrow != null) throw errorToThrow!;
    return responses[imagePath] ??
        OcrPageResult(pageNumber: pageNumber, text: '', confidence: 0.0);
  }

  @override
  Future<void> dispose() async {}
}

class _FakeNotificationBackend implements NotificationBackend {
  final List<ScheduledReminderSpec> scheduled = [];
  final List<int> cancelledIds = [];

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<void> schedule(ScheduledReminderSpec spec) async {
    scheduled.add(spec);
  }

  @override
  Future<void> cancel(int notificationId) async {
    cancelledIds.add(notificationId);
  }
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Stage E - On-Device OCR Pipeline', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ocr_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('Clear image extracts text with confidence', () async {
      final imgFile = File(p.join(tempDir.path, 'clear.jpg'))
        ..writeAsBytesSync([1, 2, 3]);
      final service = OcrService(
        engine: _FakeOcrEngine(
          responses: {
            imgFile.path: const OcrPageResult(
              pageNumber: 1,
              text: 'GOVERNMENT OF INDIA\nAADHAAR\n2345 6789 0123',
              confidence: 0.92,
            ),
          },
        ),
      );

      final res = await service.extractTextFromFile(imgFile.path);
      expect(res.isEmpty, isFalse);
      expect(res.averageConfidence, closeTo(0.92, 0.01));
      expect(res.warning, isNull);
    });

    test('Empty or blurry image returns warning gracefully', () async {
      final imgFile = File(p.join(tempDir.path, 'empty.jpg'))
        ..writeAsBytesSync([1, 2, 3]);
      final service = OcrService(engine: _FakeOcrEngine());

      final res = await service.extractTextFromFile(imgFile.path);
      expect(res.isEmpty, isTrue);
      expect(res.warning, isNotNull);
    });

    test('Cancellation stops OCR cleanly', () async {
      final imgFile = File(p.join(tempDir.path, 'cancel.jpg'))
        ..writeAsBytesSync([1, 2, 3]);
      final service = OcrService(engine: _FakeOcrEngine());
      final token = OcrCancellationToken()..cancel();

      expect(
        () =>
            service.extractTextFromFile(imgFile.path, cancellationToken: token),
        throwsA(isA<OcrCancelledException>()),
      );
    });

    test('OCR failure propagates error for Retry UI', () async {
      final imgFile = File(p.join(tempDir.path, 'fail.jpg'))
        ..writeAsBytesSync([1, 2, 3]);
      final service = OcrService(
        engine: _FakeOcrEngine(errorToThrow: Exception('ML Kit model error')),
      );

      expect(() => service.extractTextFromFile(imgFile.path), throwsException);
    });
  });

  group('Stage F - Document Classification & Masking', () {
    final classifier = DocumentClassifierService();

    test('Classifies Aadhaar and masks first 8 digits', () {
      const text =
          'Unique Identification Authority of India\nMera Aadhaar\n9999 8888 7774';
      final res = classifier.classify(text);
      expect(res.suggestedType, equals(DocumentTypes.aadhaar));
      expect(res.isLowConfidence, isFalse);
      expect(res.maskedIdentifier, equals('XXXX-XXXX-7774'));
      expect(res.maskedIdentifier!.contains('9999'), isFalse);
    });

    test('Classifies PAN and masks middle characters', () {
      const text =
          'INCOME TAX DEPARTMENT\nGOVT. OF INDIA\nPermanent Account Number\nABCDE1234F';
      final res = classifier.classify(text);
      expect(res.suggestedType, equals(DocumentTypes.pan));
      expect(res.maskedIdentifier, equals('ABXXX1234F'));
    });

    test('Classifies Passport with MRZ/header', () {
      const text = 'REPUBLIC OF INDIA\nPASSPORT\nP<IND\nZ1234567';
      final res = classifier.classify(text);
      expect(res.suggestedType, equals(DocumentTypes.passport));
      expect(res.maskedIdentifier, equals('ZXXXX567'));
    });

    test('Classifies Insurance policy', () {
      const text =
          'Health Insurance Policy\nPolicy No: POL-9981\nSum Insured: 500000\nPremium Paid';
      final res = classifier.classify(text);
      expect(res.suggestedType, equals(DocumentTypes.insurance));
    });

    test('Ambiguous or unknown text triggers low confidence', () {
      const text = 'Random handwritten grocery note milk eggs bread';
      final res = classifier.classify(text);
      expect(res.isLowConfidence, isTrue);
      expect(res.suggestedType, equals(DocumentTypes.other));
    });
  });

  group('Stage G & H - Expiry Detection & Notifications', () {
    final detector = ExpiryDetectorService();

    test('Extracts labeled expiry date and ignores unlabeled DOB', () {
      const text =
          'DOB: 12/05/1990\nDate of Issue: 10/01/2020\nDate of Expiry: 09/01/2030';
      final res = detector.detect(text);
      expect(res.hasExpiryCandidate, isTrue);
      expect(res.primaryExpiry!.normalizedIsoDate, equals('2030-01-09'));
      expect(res.primaryIssue!.normalizedIsoDate, equals('2020-01-10'));
      expect(res.isAmbiguous, isFalse);
    });

    test('Handles missing expiry dates without inventing one', () {
      const text = 'Date of Birth: 01/01/1985\nAadhaar Card';
      final res = detector.detect(text);
      expect(res.hasExpiryCandidate, isFalse);
      expect(res.primaryExpiry, isNull);
    });

    test('Flags ambiguous multiple expiry dates', () {
      const text = 'Valid Until: 01/01/2028\nPolicy End Date: 31/12/2029';
      final res = detector.detect(text);
      expect(res.hasExpiryCandidate, isTrue);
      expect(res.isAmbiguous, isTrue);
    });

    test('Notification scheduling, rescheduling, and cancellation', () async {
      final dbDir = await Directory.systemTemp.createTemp('notif_db_');
      await DatabaseHelper.configureForTesting(p.join(dbDir.path, 'test.db'));

      final backend = _FakeNotificationBackend();
      final service = NotificationService.forTesting(backend: backend);

      final now = DateTime(2026, 11, 1);
      final expiry = DateTime(2027, 1, 15);

      // Schedule 30d, 7d, 1d
      final specs = await service.scheduleExpiryReminders(
        documentId: 42,
        documentName: 'Passport.pdf',
        expiryDate: expiry,
        nowOverride: now,
      );
      expect(specs.length, equals(3));
      expect(backend.scheduled.length, equals(3));

      // Reschedule cancels old notifications before scheduling new ones (no duplicates)
      final specs2 = await service.scheduleExpiryReminders(
        documentId: 42,
        documentName: 'Passport.pdf',
        expiryDate: DateTime(2027, 3, 1),
        remind30Days: true,
        remind7Days: false,
        remind1Day: false,
        nowOverride: now,
      );
      expect(backend.cancelledIds.length, equals(3));
      expect(specs2.length, equals(1));

      await DatabaseHelper.configureForTesting(null);
      await dbDir.delete(recursive: true);
    });
  });
}
