import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/document_item.dart';
import '../theme/app_colors.dart';
import '../widgets/empty_state_view.dart';
import 'document_viewer_screen.dart';
import 'ocr_review_sheet.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  List<DocumentItem> _expiryDocs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExpiryDocuments();
  }

  Future<void> _loadExpiryDocuments() async {
    setState(() => _isLoading = true);
    final rows = await DatabaseHelper.instance.getDocumentsWithExpiry();
    if (!mounted) return;
    setState(() {
      _expiryDocs = rows.map((m) => DocumentItem.fromMap(m)).toList();
      _isLoading = false;
    });
  }

  void _openDoc(DocumentItem doc) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentViewerScreen(
          document: doc,
          onAnalyzeDocument: (d, path) =>
              OcrReviewSheet.show(context, document: d, resolvedFilePath: path),
        ),
      ),
    ).then((_) => _loadExpiryDocuments());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Expiry & Reminders')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadExpiryDocuments,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.securityIndigoSubtle,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.securityIndigo.withValues(alpha: 0.25),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.notifications_active_outlined,
                          color: AppColors.securityIndigo,
                          size: 26,
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Confirmed Expiry Reminders',
                                style: TextStyle(
                                  color: AppColors.enclavePrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Open any document and run On-Device OCR to detect and confirm renewal dates (30d, 7d, 1d alerts).',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12.5,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_expiryDocs.isEmpty)
                    const EmptyStateView(
                      icon: Icons.event_available_rounded,
                      title: 'No Confirmed Expiry Dates',
                      description:
                          'Open a Passport, Driving Licence, or Insurance document and run On-Device OCR to confirm its expiry date.',
                    )
                  else
                    ..._expiryDocs.map(_buildExpiryTile),
                ],
              ),
            ),
    );
  }

  Widget _buildExpiryTile(DocumentItem doc) {
    final days = doc.daysUntilExpiry;
    final isExpired = doc.isExpired;
    final isSoon = doc.isExpiringSoon;

    final Color badgeBg = isExpired
        ? AppColors.alertRoseSubtle
        : isSoon
        ? AppColors.warningAmberSubtle
        : AppColors.trustEmeraldSubtle;
    final Color badgeFg = isExpired
        ? AppColors.alertRose
        : isSoon
        ? AppColors.warningAmber
        : AppColors.trustEmerald;

    final String statusText = days == null
        ? 'No Date'
        : isExpired
        ? 'Expired ${-days}d ago'
        : days == 0
        ? 'Expires Today'
        : '$days days left';

    return InkWell(
      onTap: () => _openDoc(doc),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isExpired
                    ? Icons.warning_amber_rounded
                    : Icons.calendar_today_rounded,
                size: 20,
                color: badgeFg,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.enclavePrimary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${doc.docType ?? 'Document'} • Expires ${doc.expiryDate ?? ''}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  color: badgeFg,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
