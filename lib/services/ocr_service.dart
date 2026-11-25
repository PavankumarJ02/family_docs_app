import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

/// Token to cancel an in-flight multi-page OCR operation.
class OcrCancellationToken {
  bool _isCancelled = false;
  bool get isCancelled => _isCancelled;
  void cancel() => _isCancelled = true;
}

class OcrCancelledException implements Exception {
  const OcrCancelledException();
  @override
  String toString() => 'OCR processing was cancelled.';
}

class OcrPageResult {
  final int pageNumber;
  final String text;
  final double? confidence;
  final bool fromEmbeddedPdfText;

  const OcrPageResult({
    required this.pageNumber,
    required this.text,
    this.confidence,
    this.fromEmbeddedPdfText = false,
  });
}

class OcrExtractionResult {
  final List<OcrPageResult> pages;
  final String combinedText;
  final double averageConfidence;
  final String? warning;

  const OcrExtractionResult({
    required this.pages,
    required this.combinedText,
    required this.averageConfidence,
    this.warning,
  });

  bool get isEmpty => combinedText.trim().isEmpty;
}

/// Abstract OCR engine interface so unit tests can run deterministically
/// without native platform channels, and future engines (e.g. Tamil/iOS Vision)
/// can plug in cleanly.
abstract class OcrEngine {
  Future<OcrPageResult> recognizeImageFile(
    String imagePath, {
    int pageNumber = 1,
  });
  Future<void> dispose();
}

/// On-device Google ML Kit OCR implementation (Latin script).
/// Note: Tamil script recognition is NOT claimed here; it requires a separate
/// platform-specific evaluation (ML Kit Tamil / iOS Vision).
class MlKitOcrEngine implements OcrEngine {
  final TextRecognizer _recognizer;

  MlKitOcrEngine({TextRecognitionScript script = TextRecognitionScript.latin})
    : _recognizer = TextRecognizer(script: script);

  @override
  Future<OcrPageResult> recognizeImageFile(
    String imagePath, {
    int pageNumber = 1,
  }) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognized = await _recognizer.processImage(inputImage);

    // Estimate confidence from line/element confidences when provided by ML Kit
    final confidences = <double>[];
    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        if (line.confidence != null) {
          confidences.add(line.confidence!);
        }
      }
    }
    final avgConf = confidences.isEmpty
        ? (recognized.text.trim().isEmpty ? 0.0 : 0.75)
        : confidences.reduce((a, b) => a + b) / confidences.length;

    return OcrPageResult(
      pageNumber: pageNumber,
      text: recognized.text,
      confidence: avgConf,
      fromEmbeddedPdfText: false,
    );
  }

  @override
  Future<void> dispose() => _recognizer.close();
}

/// In-memory OCR pipeline.
/// PRIVACY RULE: Extracted text is processed strictly in memory and never
/// persisted to SQLite or written to logs.
class OcrService {
  final OcrEngine _engine;

  OcrService({OcrEngine? engine}) : _engine = engine ?? MlKitOcrEngine();

  /// Runs OCR on an image or PDF document (embedded text first, then page-by-page
  /// rasterized OCR for scanned PDFs).
  Future<OcrExtractionResult> extractTextFromFile(
    String filePath, {
    OcrCancellationToken? cancellationToken,
    void Function(int currentPage, int totalPages)? onProgress,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('Document file not found.', filePath);
    }

    final ext = p.extension(filePath).toLowerCase();
    if (ext == '.pdf') {
      return _extractFromPdf(
        filePath,
        cancellationToken: cancellationToken,
        onProgress: onProgress,
      );
    }

    onProgress?.call(1, 1);
    if (cancellationToken?.isCancelled ?? false) {
      throw const OcrCancelledException();
    }

    final pageResult = await _engine.recognizeImageFile(
      filePath,
      pageNumber: 1,
    );
    return OcrExtractionResult(
      pages: [pageResult],
      combinedText: pageResult.text,
      averageConfidence: pageResult.confidence ?? 0.0,
      warning: pageResult.text.trim().isEmpty
          ? 'No readable text detected. The image may be blurry or blank.'
          : null,
    );
  }

  Future<OcrExtractionResult> _extractFromPdf(
    String pdfPath, {
    OcrCancellationToken? cancellationToken,
    void Function(int currentPage, int totalPages)? onProgress,
  }) async {
    final doc = await PdfDocument.openFile(pdfPath);
    final results = <OcrPageResult>[];
    final tempDir = await getTemporaryDirectory();

    try {
      final totalPages = doc.pages.length;
      for (var i = 0; i < totalPages; i++) {
        if (cancellationToken?.isCancelled ?? false) {
          throw const OcrCancelledException();
        }
        onProgress?.call(i + 1, totalPages);

        final page = doc.pages[i];
        final embedded = await page.loadText();
        final embeddedText = embedded?.fullText.trim() ?? '';

        if (embeddedText.length >= 20) {
          results.add(
            OcrPageResult(
              pageNumber: i + 1,
              text: embeddedText,
              confidence: 0.98,
              fromEmbeddedPdfText: true,
            ),
          );
          continue;
        }

        // Scanned PDF fallback: render page to a temporary PNG, run ML Kit OCR,
        // and immediately delete the temporary image.
        final rendered = await page.render(
          fullWidth: (page.width * 2).clamp(800, 2200),
          fullHeight: (page.height * 2).clamp(800, 3000),
        );
        if (rendered == null) {
          results.add(
            OcrPageResult(pageNumber: i + 1, text: '', confidence: 0.0),
          );
          continue;
        }

        final tempFile = File(
          p.join(
            tempDir.path,
            'ocr_tmp_${DateTime.now().microsecondsSinceEpoch}_p${i + 1}.png',
          ),
        );
        try {
          final uiImg = await rendered.createImage();
          final byteData = await uiImg.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          uiImg.dispose();
          rendered.dispose();

          if (byteData != null) {
            final encoded = img.encodePng(
              img.Image.fromBytes(
                width: rendered.width,
                height: rendered.height,
                bytes: byteData.buffer,
                numChannels: 4,
                order: img.ChannelOrder.rgba,
              ),
            );
            await tempFile.writeAsBytes(encoded, flush: true);
            final ocrPage = await _engine.recognizeImageFile(
              tempFile.path,
              pageNumber: i + 1,
            );
            results.add(ocrPage);
          }
        } finally {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        }
      }
    } finally {
      await doc.dispose();
    }

    final combined = results
        .map((r) => r.text)
        .where((t) => t.trim().isNotEmpty)
        .join('\n\n');
    final confList = results
        .map((r) => r.confidence)
        .whereType<double>()
        .toList();
    final avgConf = confList.isEmpty
        ? 0.0
        : confList.reduce((a, b) => a + b) / confList.length;

    return OcrExtractionResult(
      pages: results,
      combinedText: combined,
      averageConfidence: avgConf,
      warning: combined.trim().isEmpty
          ? 'No readable text found in PDF pages.'
          : null,
    );
  }

  Future<void> dispose() async {
    if (!kIsWeb) {
      await _engine.dispose();
    }
  }
}
