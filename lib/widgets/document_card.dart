import 'package:flutter/material.dart';
import '../models/document_item.dart';
import '../theme/app_colors.dart';
import 'animated_press_card.dart';

class DocumentCard extends StatelessWidget {
  final DocumentItem document;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onDelete;

  const DocumentCard({
    super.key,
    required this.document,
    required this.onTap,
    required this.onLongPress,
    this.onDelete,
  });

  Color _getBadgeColor() {
    if (document.isPdf) return const Color(0xFFDC2626); // Crimson PDF
    if (document.isImage) return AppColors.categorySky; // Sky image
    return AppColors.securityIndigo;
  }

  IconData _getFileIcon() {
    if (document.isPdf) return Icons.picture_as_pdf_rounded;
    if (document.isImage) return Icons.image_rounded;
    return Icons.insert_drive_file_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final badgeColor = _getBadgeColor();

    return AnimatedPressCard(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceBorder, width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x080F172A),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left File Type Avatar
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(_getFileIcon(), color: badgeColor, size: 24),
              ),
            ),
            const SizedBox(width: 14),

            // Center Content Stack
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.enclavePrimary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        document.formattedSize,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        "•",
                        style: TextStyle(
                          color: AppColors.textSubtle,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        document.formattedDate,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Right Status Badge & Options
            _buildStatusBadge(),
            const SizedBox(width: 4),

            // Options Overflow Button
            IconButton(
              icon: const Icon(
                Icons.more_vert_rounded,
                color: AppColors.textSubtle,
                size: 20,
              ),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: onLongPress,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color bg = AppColors.surfaceMuted;
    Color fg = AppColors.textMuted;
    String label = 'Local';
    IconData icon = Icons.folder_outlined;

    if (document.isExpired) {
      bg = AppColors.alertRoseSubtle;
      fg = AppColors.alertRose;
      label = 'Expired';
      icon = Icons.warning_amber_rounded;
    } else if (document.isExpiringSoon) {
      bg = AppColors.warningAmberSubtle;
      fg = AppColors.warningAmber;
      label = 'Expiring';
      icon = Icons.schedule_rounded;
    } else if (document.docType != null && document.docType!.isNotEmpty) {
      bg = AppColors.securityIndigoSubtle;
      fg = AppColors.securityIndigo;
      label = document.docType!;
      icon = Icons.verified_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: fg, size: 11),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
