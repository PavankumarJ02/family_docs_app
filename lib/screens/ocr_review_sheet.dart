import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/document_item.dart';
import '../services/document_classifier_service.dart';
import '../services/expiry_detector_service.dart';
import '../services/notification_service.dart';
import '../services/ocr_service.dart';
import '../theme/app_colors.dart';

/// In-memory OCR analysis & user-confirmed metadata review bottom sheet.
/// Never persists raw OCR text or unmasked government IDs.
class OcrReviewSheet extends StatefulWidget {
  final DocumentItem document;
  final String resolvedFilePath;
  final OcrService? ocrService;

  const OcrReviewSheet({
    super.key,
    required this.document,
    required this.resolvedFilePath,
    this.ocrService,
  });

  static Future<DocumentItem?> show(
    BuildContext context, {
    required DocumentItem document,
    required String resolvedFilePath,
    OcrService? ocrService,
  }) {
    return showModalBottomSheet<DocumentItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => OcrReviewSheet(
        document: document,
        resolvedFilePath: resolvedFilePath,
        ocrService: ocrService,
      ),
    );
  }

  @override
  State<OcrReviewSheet> createState() => _OcrReviewSheetState();
}

class _OcrReviewSheetState extends State<OcrReviewSheet> {
  late final OcrService _ocrService;
  final _classifier = DocumentClassifierService();
  final _expiryDetector = ExpiryDetectorService();
  final _token = OcrCancellationToken();

  bool _isAnalyzing = true;
  String? _error;
  String? _warning;
  int _progressPage = 0;
  int _totalPages = 0;

  ClassificationResult? _classification;
  ExpiryDetectionResult? _expiryDetection;

  late String _selectedDocType;
  late TextEditingController _maskedIdController;
  late TextEditingController _notesController;
  DateTime? _issueDate;
  DateTime? _expiryDate;
  bool _confirmExpiry = false;

  bool _remind30d = true;
  bool _remind7d = true;
  bool _remind1d = true;
  DateTime? _customReminderDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _ocrService = widget.ocrService ?? OcrService();
    _selectedDocType = widget.document.docType ?? DocumentTypes.other;
    _maskedIdController = TextEditingController(
      text: widget.document.maskedId ?? '',
    );
    _notesController = TextEditingController(text: widget.document.notes ?? '');
    if (widget.document.issueDate != null) {
      _issueDate = DateTime.tryParse(widget.document.issueDate!);
    }
    if (widget.document.expiryDate != null) {
      _expiryDate = DateTime.tryParse(widget.document.expiryDate!);
      _confirmExpiry = widget.document.expiryConfirmed;
    }
    _runOcrAnalysis();
  }

  @override
  void dispose() {
    _token.cancel();
    if (widget.ocrService == null) {
      _ocrService.dispose();
    }
    _maskedIdController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _runOcrAnalysis() async {
    setState(() {
      _isAnalyzing = true;
      _error = null;
      _warning = null;
    });

    try {
      final ocr = await _ocrService.extractTextFromFile(
        widget.resolvedFilePath,
        cancellationToken: _token,
        onProgress: (page, total) {
          if (!mounted) return;
          setState(() {
            _progressPage = page;
            _totalPages = total;
          });
        },
      );

      // Process strictly in memory; discard ocr.combinedText after method returns
      final classification = _classifier.classify(ocr.combinedText);
      final expiry = _expiryDetector.detect(ocr.combinedText);

      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _warning = ocr.warning;
        _classification = classification;
        _expiryDetection = expiry;

        if (!classification.isLowConfidence) {
          _selectedDocType = classification.suggestedType;
        }
        if (classification.maskedIdentifier != null &&
            _maskedIdController.text.isEmpty) {
          _maskedIdController.text = classification.maskedIdentifier!;
        }
        if (expiry.primaryIssue?.asDateTime != null && _issueDate == null) {
          _issueDate = expiry.primaryIssue!.asDateTime;
        }
        if (expiry.primaryExpiry?.asDateTime != null && _expiryDate == null) {
          _expiryDate = expiry.primaryExpiry!.asDateTime;
        }
      });
    } on OcrCancelledException {
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _warning = 'OCR scan cancelled. You can still edit metadata manually.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _error = 'On-device OCR failed: $e';
      });
    }
  }

  Future<void> _pickDate({
    required DateTime? initial,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(1950),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      onPicked(picked);
    }
  }

  String _formatIso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _saveMetadata() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final expiryIso = _expiryDate != null ? _formatIso(_expiryDate!) : null;
      final issueIso = _issueDate != null ? _formatIso(_issueDate!) : null;

      final updates = <String, dynamic>{
        'doc_type': _selectedDocType,
        'masked_id': _maskedIdController.text.trim().isEmpty
            ? null
            : _maskedIdController.text.trim(),
        'issue_date': issueIso,
        'expiry_date': expiryIso,
        'expiry_confirmed': (_expiryDate != null && _confirmExpiry) ? 1 : 0,
        'ocr_status': _error == null ? 'completed' : 'manual',
        'notes': _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      };

      await DatabaseHelper.instance.updateDocumentMetadata(
        widget.document.id,
        updates,
      );

      if (_expiryDate != null && _confirmExpiry) {
        await NotificationService.instance.scheduleExpiryReminders(
          documentId: widget.document.id,
          documentName: widget.document.fileName,
          expiryDate: _expiryDate!,
          remind30Days: _remind30d,
          remind7Days: _remind7d,
          remind1Day: _remind1d,
          customReminderDate: _customReminderDate,
        );
      } else {
        await NotificationService.instance.cancelDocumentReminders(
          widget.document.id,
        );
      }

      final refreshed = await DatabaseHelper.instance.getDocumentById(
        widget.document.id,
      );
      if (!mounted) return;
      Navigator.pop(
        context,
        refreshed != null ? DocumentItem.fromMap(refreshed) : null,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save metadata: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
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
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'On-Device Analysis & Metadata',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.enclavePrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.trustEmeraldSubtle,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Offline Only',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF065F46),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Raw text is analyzed in memory and discarded immediately. Confirm extracted details below.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),

            if (_isAnalyzing) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    const LinearProgressIndicator(),
                    const SizedBox(height: 12),
                    Text(
                      _totalPages > 1
                          ? 'Scanning page $_progressPage of $_totalPages locally...'
                          : 'Running on-device OCR...',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => _token.cancel(),
                      child: const Text('Cancel Scan'),
                    ),
                  ],
                ),
              ),
            ] else ...[
              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.alertRoseSubtle,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: AppColors.alertRose,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.alertRose,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _runOcrAnalysis,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              if (_warning != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warningAmberSubtle,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _warning!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.enclavePrimary,
                    ),
                  ),
                ),
              if (_classification != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Icon(
                        _classification!.isLowConfidence
                            ? Icons.help_outline_rounded
                            : Icons.verified_outlined,
                        size: 16,
                        color: _classification!.isLowConfidence
                            ? AppColors.warningAmber
                            : AppColors.trustEmerald,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _classification!.isLowConfidence
                              ? 'Low classification confidence (${(_classification!.confidence * 100).round()}%). Please select type manually.'
                              : 'Suggested: ${_classification!.suggestedType} (${(_classification!.confidence * 100).round()}% match)',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.enclavePrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Document Type Selector
              DropdownButtonFormField<String>(
                initialValue: _selectedDocType,
                decoration: const InputDecoration(
                  labelText: 'Document Type',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: DocumentTypes.all
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedDocType = val);
                },
              ),
              const SizedBox(height: 12),

              // Masked ID Field
              TextField(
                controller: _maskedIdController,
                decoration: const InputDecoration(
                  labelText: 'Masked ID (Optional, never store full ID)',
                  hintText: 'e.g. XXXX-XXXX-1234',
                  prefixIcon: Icon(Icons.shield_outlined),
                ),
              ),
              const SizedBox(height: 12),

              // Issue & Expiry Date Pickers
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(
                        initial: _issueDate,
                        onPicked: (d) => setState(() => _issueDate = d),
                      ),
                      icon: const Icon(Icons.event_available_rounded, size: 16),
                      label: Text(
                        _issueDate == null
                            ? 'Issue Date'
                            : _formatIso(_issueDate!),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(
                        initial: _expiryDate,
                        onPicked: (d) => setState(() => _expiryDate = d),
                      ),
                      icon: const Icon(Icons.event_busy_rounded, size: 16),
                      label: Text(
                        _expiryDate == null
                            ? 'Expiry Date'
                            : _formatIso(_expiryDate!),
                      ),
                    ),
                  ),
                ],
              ),

              if (_expiryDetection?.primaryExpiry != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Detected from label "${_expiryDetection!.primaryExpiry!.matchedLabel}"'
                    '${_expiryDetection!.isAmbiguous ? ' (Multiple dates found — please verify)' : ''}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.securityIndigo,
                    ),
                  ),
                ),

              if (_expiryDate != null) ...[
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _confirmExpiry,
                  onChanged: (v) => setState(() => _confirmExpiry = v ?? false),
                  title: const Text(
                    'Confirm Expiry Date & Enable Reminders',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    _expiryDate!.isBefore(DateTime.now())
                        ? 'Note: This document is already expired.'
                        : 'Schedule local renewal notifications before ${_formatIso(_expiryDate!)}.',
                    style: const TextStyle(fontSize: 11.5),
                  ),
                ),
                if (_confirmExpiry)
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('30 days'),
                        selected: _remind30d,
                        onSelected: (v) => setState(() => _remind30d = v),
                      ),
                      FilterChip(
                        label: const Text('7 days'),
                        selected: _remind7d,
                        onSelected: (v) => setState(() => _remind7d = v),
                      ),
                      FilterChip(
                        label: const Text('1 day'),
                        selected: _remind1d,
                        onSelected: (v) => setState(() => _remind1d = v),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.calendar_month, size: 15),
                        label: Text(
                          _customReminderDate == null
                              ? 'Custom'
                              : _formatIso(_customReminderDate!),
                        ),
                        onPressed: () => _pickDate(
                          initial: _customReminderDate ?? _expiryDate,
                          onPicked: (d) =>
                              setState(() => _customReminderDate = d),
                        ),
                      ),
                    ],
                  ),
              ],

              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveMetadata,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('Confirm & Save Metadata'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
