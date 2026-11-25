import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import '../db/database_helper.dart';
import '../models/document_item.dart';
import '../services/document_storage_service.dart';
import '../theme/app_colors.dart';

class DocumentViewerScreen extends StatefulWidget {
  final DocumentItem document;
  final String? ownerName;
  final String? categoryName;
  final Future<DocumentItem?> Function(DocumentItem doc, String resolvedPath)?
  onAnalyzeDocument;

  const DocumentViewerScreen({
    super.key,
    required this.document,
    this.ownerName,
    this.categoryName,
    this.onAnalyzeDocument,
  });

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  late DocumentItem _doc;
  final PdfViewerController _pdfController = PdfViewerController();

  String? _resolvedPath;
  String? _ownerName;
  String? _categoryName;
  bool _isLoading = true;
  String? _errorMessage;

  // PDF state
  int _currentPage = 1;
  int _totalPages = 0;

  // Image state
  int _quarterTurns = 0;
  bool _isFullScreen = false;

  @override
  void initState() {
    super.initState();
    _doc = widget.document;
    _ownerName = widget.ownerName;
    _categoryName = widget.categoryName;
    _resolveDocument();
  }

  Future<void> _resolveDocument() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final path = await DocumentStorageService().resolveFilePath(
        _doc.filePath,
      );
      final exists = path.isNotEmpty && await File(path).exists();

      // Lookup owner and category names if not passed in
      String? owner = _ownerName;
      String? category = _categoryName;
      if (owner == null || category == null) {
        final db = await DatabaseHelper.instance.database;
        if (owner == null) {
          final m = await db.query(
            'members',
            where: 'id = ?',
            whereArgs: [_doc.memberId],
          );
          if (m.isNotEmpty) owner = m.first['name'] as String?;
        }
        if (category == null) {
          final c = await db.query(
            'categories',
            where: 'id = ?',
            whereArgs: [_doc.categoryId],
          );
          if (c.isNotEmpty) category = c.first['name'] as String?;
        }
      }

      if (!mounted) return;
      if (!exists) {
        setState(() {
          _resolvedPath = path;
          _ownerName = owner;
          _categoryName = category;
          _isLoading = false;
          _errorMessage =
              'Document file could not be located on device storage.';
        });
        return;
      }

      setState(() {
        _resolvedPath = path;
        _ownerName = owner;
        _categoryName = category;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to open document: $e';
      });
    }
  }

  Future<void> _refreshDocumentRecord() async {
    final row = await DatabaseHelper.instance.getDocumentById(_doc.id);
    if (row != null && mounted) {
      setState(() {
        _doc = DocumentItem.fromMap(row);
      });
    }
  }

  Future<void> _triggerAnalysis() async {
    if (_resolvedPath == null || widget.onAnalyzeDocument == null) return;
    final updated = await widget.onAnalyzeDocument!(_doc, _resolvedPath!);
    if (updated != null && mounted) {
      setState(() => _doc = updated);
    } else {
      await _refreshDocumentRecord();
    }
  }

  void _showMetadataSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.securityIndigoSubtle,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _doc.isPdf
                          ? Icons.picture_as_pdf_rounded
                          : Icons.image_rounded,
                      color: AppColors.securityIndigo,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _doc.fileName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.enclavePrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_doc.formattedSize} • Imported ${_doc.formattedDate}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: Column(
                  children: [
                    _metaRow('Owner', _ownerName ?? 'Member #${_doc.memberId}'),
                    const Divider(height: 14, color: AppColors.surfaceBorder),
                    _metaRow(
                      'Category',
                      _categoryName ?? 'Category #${_doc.categoryId}',
                    ),
                    const Divider(height: 14, color: AppColors.surfaceBorder),
                    _metaRow(
                      'Document Type',
                      _doc.docType ?? 'Not classified yet',
                    ),
                    if (_doc.maskedId != null && _doc.maskedId!.isNotEmpty) ...[
                      const Divider(height: 14, color: AppColors.surfaceBorder),
                      _metaRow('Identifier', _doc.maskedId!),
                    ],
                    if (_doc.issueDate != null &&
                        _doc.issueDate!.isNotEmpty) ...[
                      const Divider(height: 14, color: AppColors.surfaceBorder),
                      _metaRow('Issue Date', _doc.issueDate!),
                    ],
                    const Divider(height: 14, color: AppColors.surfaceBorder),
                    _metaRow(
                      'Expiry Date',
                      _doc.expiryDate != null && _doc.expiryDate!.isNotEmpty
                          ? '${_doc.expiryDate!}${_doc.expiryConfirmed ? ' (Confirmed)' : ' (Unconfirmed)'}'
                          : 'No expiry set',
                    ),
                    const Divider(height: 14, color: AppColors.surfaceBorder),
                    _metaRow(
                      'Storage',
                      'Local Device Storage (Unencrypted Phase 2)',
                    ),
                  ],
                ),
              ),
              if (widget.onAnalyzeDocument != null) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _triggerAnalysis();
                    },
                    icon: const Icon(Icons.document_scanner_rounded, size: 18),
                    label: const Text('Run On-Device OCR & Edit Metadata'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.enclavePrimary,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isFullScreen
          ? Colors.black
          : AppColors.surfaceBackground,
      appBar: _isFullScreen
          ? null
          : AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _doc.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16),
                  ),
                  if (_doc.docType != null && _doc.docType!.isNotEmpty)
                    Text(
                      _doc.docType!,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.securityIndigo,
                      ),
                    ),
                ],
              ),
              actions: [
                if (widget.onAnalyzeDocument != null && _resolvedPath != null)
                  IconButton(
                    icon: const Icon(Icons.document_scanner_outlined),
                    tooltip: 'Analyze with On-Device OCR',
                    onPressed: _triggerAnalysis,
                  ),
                IconButton(
                  icon: const Icon(Icons.info_outline_rounded),
                  tooltip: 'Document Details',
                  onPressed: _showMetadataSheet,
                ),
              ],
            ),
      body: _buildBody(),
      bottomNavigationBar: _isFullScreen || _isLoading || _errorMessage != null
          ? null
          : _buildBottomToolbar(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null || _resolvedPath == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.broken_image_outlined,
                size: 56,
                color: AppColors.alertRose,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage ?? 'Unable to load document.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.enclavePrimary,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _resolveDocument,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_doc.isPdf) {
      return PdfViewer.file(
        _resolvedPath!,
        controller: _pdfController,
        params: PdfViewerParams(
          onViewerReady: (document, controller) {
            if (!mounted) return;
            setState(() {
              _totalPages = document.pages.length;
              _currentPage = controller.pageNumber ?? 1;
            });
          },
          onPageChanged: (pageNumber) {
            if (!mounted || pageNumber == null) return;
            setState(() => _currentPage = pageNumber);
          },
          loadingBannerBuilder: (context, bytesDownloaded, totalBytes) {
            return const Center(child: CircularProgressIndicator());
          },
          errorBannerBuilder: (context, error, stackTrace, documentRef) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.picture_as_pdf_outlined,
                      size: 48,
                      color: AppColors.alertRose,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Could not render PDF: $error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    if (_doc.isImage) {
      return GestureDetector(
        onTap: () => setState(() => _isFullScreen = !_isFullScreen),
        child: Container(
          color: _isFullScreen ? Colors.black : const Color(0xFF0F172A),
          width: double.infinity,
          height: double.infinity,
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 5.0,
            child: Center(
              child: RotatedBox(
                quarterTurns: _quarterTurns,
                child: Image.file(
                  File(_resolvedPath!),
                  fit: BoxFit.contain,
                  errorBuilder: (_, err, __) => Center(
                    child: Text(
                      'Failed to decode image: $err',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Center(
      child: Text(
        'Preview not available for .${_doc.fileExtension} files.',
        style: const TextStyle(color: AppColors.textMuted),
      ),
    );
  }

  Widget? _buildBottomToolbar() {
    if (_doc.isPdf) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(
          color: AppColors.cardSurface,
          border: Border(top: BorderSide(color: AppColors.surfaceBorder)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    tooltip: 'Previous Page',
                    onPressed: _currentPage > 1 && _pdfController.isReady
                        ? () => _pdfController.goToPage(
                            pageNumber: _currentPage - 1,
                          )
                        : null,
                  ),
                  Text(
                    _totalPages > 0
                        ? 'Page $_currentPage of $_totalPages'
                        : 'Loading...',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.enclavePrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    tooltip: 'Next Page',
                    onPressed:
                        _currentPage < _totalPages && _pdfController.isReady
                        ? () => _pdfController.goToPage(
                            pageNumber: _currentPage + 1,
                          )
                        : null,
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.zoom_out_rounded),
                    tooltip: 'Zoom Out',
                    onPressed: _pdfController.isReady
                        ? () => _pdfController.zoomDown()
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.zoom_in_rounded),
                    tooltip: 'Zoom In',
                    onPressed: _pdfController.isReady
                        ? () => _pdfController.zoomUp()
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (_doc.isImage) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(
          color: AppColors.cardSurface,
          border: Border(top: BorderSide(color: AppColors.surfaceBorder)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                onPressed: () {
                  setState(() => _quarterTurns = (_quarterTurns + 1) % 4);
                },
                icon: const Icon(Icons.rotate_right_rounded),
                label: const Text('Rotate 90°'),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _isFullScreen = true),
                icon: const Icon(Icons.fullscreen_rounded),
                label: const Text('Full Screen'),
              ),
            ],
          ),
        ),
      );
    }

    return null;
  }
}
