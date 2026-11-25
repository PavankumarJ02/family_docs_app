import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:family_docs_app/services/scanner_service.dart';

class _FakeNativeScannerGateway implements NativeScannerGateway {
  final List<String>? pathsToReturn;
  final Exception? errorToThrow;

  _FakeNativeScannerGateway({this.pathsToReturn, this.errorToThrow});

  @override
  Future<List<String>?> scanWithAutoEdgeDetection({int maxPages = 12}) async {
    if (errorToThrow != null) throw errorToThrow!;
    return pathsToReturn;
  }
}

Uint8List _createSampleJpg({int width = 120, int height = 160}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(240, 244, 248));
  return Uint8List.fromList(img.encodeJpg(image));
}

void main() {
  group('ScannerService - Stage D Tests', () {
    test(
      'Throws ScannerPermissionException when camera permission denied',
      () async {
        final service = ScannerService(
          nativeGateway: _FakeNativeScannerGateway(
            errorToThrow: const ScannerPermissionException(
              'Camera permission denied',
            ),
          ),
        );

        expect(
          () => service.scanAutoPages(),
          throwsA(isA<ScannerPermissionException>()),
        );
      },
    );

    test('Returns null cleanly when user cancels scan', () async {
      final service = ScannerService(
        nativeGateway: _FakeNativeScannerGateway(pathsToReturn: null),
      );

      final pages = await service.scanAutoPages();
      expect(pages, isNull);
    });

    test('Multi-page capture loads all pages in order', () async {
      final tempDir = await Directory.systemTemp.createTemp('scanner_pages_');
      final p1 = File(p.join(tempDir.path, 'p1.jpg'))
        ..writeAsBytesSync(_createSampleJpg());
      final p2 = File(p.join(tempDir.path, 'p2.jpg'))
        ..writeAsBytesSync(_createSampleJpg());

      final service = ScannerService(
        nativeGateway: _FakeNativeScannerGateway(
          pathsToReturn: [p1.path, p2.path],
        ),
      );

      final pages = await service.scanAutoPages();
      expect(pages, isNotNull);
      expect(pages!.length, equals(2));

      await tempDir.delete(recursive: true);
    });

    test('Image processing rotates, crops 4-corners, and applies filters', () {
      final service = ScannerService();
      final src = _createSampleJpg(width: 100, height: 200);

      // Rotate 90 degrees swaps width/height roughly
      final rotated = service.processPageImage(
        src,
        rotationDegrees: 90,
        filter: ScanFilter.crispBw,
        corners: const NormalizedQuad(
          topLeft: math.Point(0.1, 0.1),
          topRight: math.Point(0.9, 0.1),
          bottomLeft: math.Point(0.1, 0.9),
          bottomRight: math.Point(0.9, 0.9),
        ),
      );
      final decoded = img.decodeImage(rotated);
      expect(decoded, isNotNull);
      expect(decoded!.width, greaterThan(decoded.height));
    });

    test('generateMultiPagePdf creates valid multi-page PDF bytes', () async {
      final service = ScannerService();
      final pdfBytes = await service.generateMultiPagePdf([
        _createSampleJpg(),
        _createSampleJpg(),
      ], title: 'Test Scan');

      // PDF header starts with %PDF-
      final header = String.fromCharCodes(pdfBytes.take(5));
      expect(header, equals('%PDF-'));
      expect(pdfBytes.length, greaterThan(500));
    });
  });
}
