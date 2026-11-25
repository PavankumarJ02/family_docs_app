import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../db/database_helper.dart';
import '../models/document_item.dart';
import '../services/document_storage_service.dart';
import '../theme/app_colors.dart';
import '../widgets/document_card.dart';
import '../widgets/empty_state_view.dart';
import 'document_viewer_screen.dart';
import 'ocr_review_sheet.dart';
import 'scanner_screen.dart';

class DocumentsScreen extends StatefulWidget {
  final int memberId;
  final int categoryId;
  final String categoryName;

  const DocumentsScreen({
    super.key,
    required this.memberId,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  List<DocumentItem> _documents = [];
  bool _isLoading = true;
  String _activeFilter = 'All'; // 'All', 'PDFs', 'Images'

  @override
  void initState() {
    super.initState();
    loadDocuments();
  }

  Future<void> loadDocuments() async {
    setState(() => _isLoading = true);
    final db = await DatabaseHelper.instance.database;
    final data = await db.query(
      'documents',
      where: 'member_id = ? AND category_id = ?',
      whereArgs: [widget.memberId, widget.categoryId],
      orderBy: 'created_at DESC',
    );

    if (!mounted) return;
    setState(() {
      _documents = data.map((m) => DocumentItem.fromMap(m)).toList();
      _isLoading = false;
    });
  }

  List<DocumentItem> get _filteredDocuments {
    if (_activeFilter == 'PDFs') {
      return _documents.where((d) => d.isPdf).toList();
    }
    if (_activeFilter == 'Images') {
      return _documents.where((d) => d.isImage).toList();
    }
    return _documents;
  }

  Future<void> pickAndSaveDocument() async {
    final typeGroup = XTypeGroup(
      label: 'documents',
      extensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
    );

    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return;

    try {
      final pickedFile = File(file.path);
      final fileName = p.basename(pickedFile.path);

      final storage = DocumentStorageService();
      final saved = await storage.saveDocument(
        sourceFile: pickedFile,
        memberId: widget.memberId,
        categoryId: widget.categoryId,
        originalName: fileName,
      );

      final docId = await DatabaseHelper.instance.addDocument({
        'uuid': saved.uuid,
        'member_id': widget.memberId,
        'category_id': widget.categoryId,
        'file_name': fileName,
        'file_path': saved.relativePath,
        'size': saved.sizeBytes,
        'created_at': DateTime.now().toIso8601String(),
        'sync_status': 'local_only',
        'ocr_status': 'pending',
      });

      await loadDocuments();
      if (!mounted) return;
      final row = await DatabaseHelper.instance.getDocumentById(docId);
      if (row != null && mounted) {
        final created = DocumentItem.fromMap(row);
        await OcrReviewSheet.show(
          context,
          document: created,
          resolvedFilePath: saved.fullPath,
        );
        loadDocuments();
      }
    } on DocumentImportException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _openScanner() async {
    final created = await Navigator.push<DocumentItem?>(
      context,
      MaterialPageRoute(
        builder: (_) => ScannerScreen(
          memberId: widget.memberId,
          categoryId: widget.categoryId,
          categoryName: widget.categoryName,
        ),
      ),
    );
    await loadDocuments();
    if (created != null && mounted) {
      final resolved = await DocumentStorageService().resolveFilePath(
        created.filePath,
      );
      if (!mounted) return;
      await OcrReviewSheet.show(
        context,
        document: created,
        resolvedFilePath: resolved,
      );
      loadDocuments();
    }
  }

  void _openInAppViewer(DocumentItem doc) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentViewerScreen(
          document: doc,
          categoryName: widget.categoryName,
          onAnalyzeDocument: (d, path) =>
              OcrReviewSheet.show(context, document: d, resolvedFilePath: path),
        ),
      ),
    ).then((_) => loadDocuments());
  }

  void showDocumentDetailsModal(DocumentItem doc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
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
              const SizedBox(height: 18),

              // Title and Type Header
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color:
                          (doc.isPdf
                                  ? const Color(0xFFDC2626)
                                  : AppColors.categorySky)
                              .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Icon(
                        doc.isPdf
                            ? Icons.picture_as_pdf_rounded
                            : Icons.image_rounded,
                        color: doc.isPdf
                            ? const Color(0xFFDC2626)
                            : AppColors.categorySky,
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doc.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.enclavePrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          "${doc.formattedSize} • Added ${doc.formattedDate}",
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
              const SizedBox(height: 20),

              // Metadata Ledger Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.surfaceBorder, width: 1),
                ),
                child: Column(
                  children: [
                    _buildMetaLine("Category", widget.categoryName),
                    const Divider(height: 16, color: AppColors.surfaceBorder),
                    _buildMetaLine(
                      "File Format",
                      doc.fileExtension.toUpperCase(),
                    ),
                    const Divider(height: 16, color: AppColors.surfaceBorder),
                    _buildMetaLine("Encryption", "Protected by Local Enclave"),
                    const Divider(height: 16, color: AppColors.surfaceBorder),
                    _buildMetaLine("Disk Path", doc.filePath, isPath: true),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: const Text("Open"),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _openInAppViewer(doc);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.alertRose,
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text("Delete"),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await DatabaseHelper.instance.deleteDocument(
                          doc.id,
                          doc.filePath,
                        );
                        loadDocuments();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaLine(String label, String value, {bool isPath = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
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
            maxLines: isPath ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isPath ? FontWeight.w400 : FontWeight.w600,
              color: AppColors.enclavePrimary,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final docs = _filteredDocuments;

    return Scaffold(
      backgroundColor: AppColors.surfaceBackground,
      appBar: AppBar(
        title: Text(widget.categoryName),
        actions: [
          IconButton(
            icon: const Icon(Icons.document_scanner_outlined),
            tooltip: "Scan Document",
            onPressed: _openScanner,
          ),
          IconButton(
            icon: const Icon(Icons.upload_file_rounded),
            tooltip: "Import Document",
            onPressed: pickAndSaveDocument,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: loadDocuments,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Filter Chips Row
                  Row(
                    children: [
                      _buildFilterChip("All", _documents.length),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        "PDFs",
                        _documents.where((d) => d.isPdf).length,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        "Images",
                        _documents.where((d) => d.isImage).length,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Documents List or Empty State
                  if (docs.isEmpty)
                    EmptyStateView(
                      icon: Icons.insert_drive_file_outlined,
                      title: "No Documents in this Category",
                      description:
                          "Upload PDF identity cards, insurance documents, or photos into ${widget.categoryName}.",
                      actionLabel: "Import Document",
                      onAction: pickAndSaveDocument,
                    )
                  else
                    ...docs.map((doc) {
                      return DocumentCard(
                        document: doc,
                        onTap: () => _openInAppViewer(doc),
                        onLongPress: () {
                          showDocumentDetailsModal(doc);
                        },
                      );
                    }),
                ],
              ),
            ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'scan_fab',
            onPressed: _openScanner,
            backgroundColor: AppColors.securityIndigo,
            foregroundColor: Colors.white,
            tooltip: 'Scan Document',
            child: const Icon(Icons.document_scanner_rounded),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'import_fab',
            onPressed: pickAndSaveDocument,
            backgroundColor: AppColors.enclavePrimary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text("Import Document"),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int count) {
    final isSelected = _activeFilter == label;

    return GestureDetector(
      onTap: () => setState(() => _activeFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.enclavePrimary : AppColors.cardSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.enclavePrimary
                : AppColors.surfaceBorder,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.enclavePrimary,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.2)
                    : AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "$count",
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
