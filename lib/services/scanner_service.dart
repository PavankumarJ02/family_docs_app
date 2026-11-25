import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

enum ScanFilter {
  original('Original'),
  enhanced('Enhanced'),
  grayscale('Grayscale'),
  crispBw('Crisp B&W');

  final String label;
  const ScanFilter(this.label);
}

/// Normalized (0.0 .. 1.0) four-corner quad for perspective correction.
class NormalizedQuad {
  final math.Point<double> topLeft;
  final math.Point<double> topRight;
  final math.Point<double> bottomLeft;
  final math.Point<double> bottomRight;

  const NormalizedQuad({
    this.topLeft = const math.Point(0.0, 0.0),
    this.topRight = const math.Point(1.0, 0.0),
    this.bottomLeft = const math.Point(0.0, 1.0),
    this.bottomRight = const math.Point(1.0, 1.0),
  });

  bool get isFullFrame =>
      topLeft.x <= 0.01 &&
      topLeft.y <= 0.01 &&
      topRight.x >= 0.99 &&
      topRight.y <= 0.01 &&
      bottomLeft.x <= 0.01 &&
      bottomLeft.y >= 0.99 &&
      bottomRight.x >= 0.99 &&
      bottomRight.y >= 0.99;

  NormalizedQuad copyWith({
    math.Point<double>? topLeft,
    math.Point<double>? topRight,
    math.Point<double>? bottomLeft,
    math.Point<double>? bottomRight,
  }) {
    return NormalizedQuad(
      topLeft: topLeft ?? this.topLeft,
      topRight: topRight ?? this.topRight,
      bottomLeft: bottomLeft ?? this.bottomLeft,
      bottomRight: bottomRight ?? this.bottomRight,
    );
  }
}

class ScannedPageData {
  final String id;
  final Uint8List originalBytes;
  Uint8List processedBytes;
  int rotationDegrees;
  ScanFilter filter;
  NormalizedQuad corners;

  ScannedPageData({
    required this.id,
    required this.originalBytes,
    required this.processedBytes,
    this.rotationDegrees = 0,
    this.filter = ScanFilter.original,
    this.corners = const NormalizedQuad(),
  });
}

class ScannerPermissionException implements Exception {
  final String message;
  const ScannerPermissionException(this.message);

  @override
  String toString() => 'ScannerPermissionException: $message';
}

/// Abstraction over native auto-edge-detection scanner (ML Kit / VisionKit)
/// for testability and clean architecture boundaries.
abstract class NativeScannerGateway {
  Future<List<String>?> scanWithAutoEdgeDetection({int maxPages = 12});
}

class CunningNativeScannerGateway implements NativeScannerGateway {
  @override
  Future<List<String>?> scanWithAutoEdgeDetection({int maxPages = 12}) async {
    try {
      final result = await CunningDocumentScanner.scanDocuments(
        noOfPages: maxPages,
        scannerSource: ScannerSource.cameraAndGallery,
        output: ScanOutput.images,
      );
      if (result == null || result.images.isEmpty) return null;
      return result.images;
    } on CunningDocumentScannerException catch (e) {
      if (e.code == 'permission_denied') {
        throw const ScannerPermissionException(
          'Camera permission was denied. Please grant camera access in Settings.',
        );
      }
      rethrow;
    }
  }
}

/// Pure-Dart image processing & multi-page PDF assembly service for Stage D.
class ScannerService {
  final NativeScannerGateway nativeGateway;

  ScannerService({NativeScannerGateway? nativeGateway})
    : nativeGateway = nativeGateway ?? CunningNativeScannerGateway();

  /// Applies 4-corner perspective crop, rotation, and enhancement filter.
  Uint8List processPageImage(
    Uint8List sourceBytes, {
    int rotationDegrees = 0,
    ScanFilter filter = ScanFilter.original,
    NormalizedQuad corners = const NormalizedQuad(),
  }) {
    final decoded = img.decodeImage(sourceBytes);
    if (decoded == null) {
      throw const FormatException('Unable to decode captured image.');
    }

    img.Image current = decoded;

    // 1. 4-corner perspective correction if corners were adjusted
    if (!corners.isFullFrame) {
      final w = current.width.toDouble();
      final h = current.height.toDouble();
      current = img.copyRectify(
        current,
        topLeft: img.Point(
          (corners.topLeft.x.clamp(0.0, 1.0) * w).round(),
          (corners.topLeft.y.clamp(0.0, 1.0) * h).round(),
        ),
        topRight: img.Point(
          (corners.topRight.x.clamp(0.0, 1.0) * w).round(),
          (corners.topRight.y.clamp(0.0, 1.0) * h).round(),
        ),
        bottomLeft: img.Point(
          (corners.bottomLeft.x.clamp(0.0, 1.0) * w).round(),
          (corners.bottomLeft.y.clamp(0.0, 1.0) * h).round(),
        ),
        bottomRight: img.Point(
          (corners.bottomRight.x.clamp(0.0, 1.0) * w).round(),
          (corners.bottomRight.y.clamp(0.0, 1.0) * h).round(),
        ),
        interpolation: img.Interpolation.linear,
      );
    }

    // 2. Rotation (90° increments)
    final normalizedRot = ((rotationDegrees % 360) + 360) % 360;
    if (normalizedRot != 0) {
      current = img.copyRotate(current, angle: normalizedRot);
    }

    // 3. Filters & enhancement
    switch (filter) {
      case ScanFilter.original:
        break;
      case ScanFilter.enhanced:
        current = img.adjustColor(
          current,
          contrast: 1.25,
          brightness: 1.05,
          saturation: 1.1,
        );
        break;
      case ScanFilter.grayscale:
        current = img.grayscale(current);
        break;
      case ScanFilter.crispBw:
        current = img.grayscale(current);
        current = img.adjustColor(current, contrast: 1.65, brightness: 1.1);
        break;
    }

    return Uint8List.fromList(img.encodeJpg(current, quality: 88));
  }

  /// Generates a multi-page PDF document from processed page image bytes.
  Future<Uint8List> generateMultiPagePdf(
    List<Uint8List> pageImages, {
    String? title,
  }) async {
    if (pageImages.isEmpty) {
      throw ArgumentError('At least one scanned page is required.');
    }

    final pdf = pw.Document(
      title: title ?? 'Scanned Document',
      creator: 'Family Docs 2.0',
    );

    for (final pageBytes in pageImages) {
      final imageProvider = pw.MemoryImage(pageBytes);
      final decoded = img.decodeImage(pageBytes);
      final pageFormat = (decoded != null && decoded.width > decoded.height)
          ? PdfPageFormat.a4.landscape
          : PdfPageFormat.a4;

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(12),
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Image(imageProvider, fit: pw.BoxFit.contain),
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  /// Convenience helper to invoke native auto-edge-detection and load bytes.
  Future<List<ScannedPageData>?> scanAutoPages({int maxPages = 12}) async {
    final paths = await nativeGateway.scanWithAutoEdgeDetection(
      maxPages: maxPages,
    );
    if (paths == null || paths.isEmpty) return null;

    final pages = <ScannedPageData>[];
    for (var i = 0; i < paths.length; i++) {
      final file = File(paths[i]);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        pages.add(
          ScannedPageData(
            id: '${DateTime.now().microsecondsSinceEpoch}_$i',
            originalBytes: bytes,
            processedBytes: bytes,
          ),
        );
      }
    }
    return pages.isEmpty ? null : pages;
  }
}
