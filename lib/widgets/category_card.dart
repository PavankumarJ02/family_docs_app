import 'package:flutter/material.dart';
import '../models/category_item.dart';
import '../theme/app_colors.dart';
import 'animated_press_card.dart';

class CategoryCard extends StatelessWidget {
  final CategoryItem category;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const CategoryCard({
    super.key,
    required this.category,
    required this.onTap,
    required this.onLongPress,
  });

  IconData _getCategoryIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('identity') ||
        lower.contains('passport') ||
        lower.contains('id') ||
        lower.contains('aadhaar')) {
      return Icons.verified_user_rounded;
    }
    if (lower.contains('property') ||
        lower.contains('real estate') ||
        lower.contains('house') ||
        lower.contains('home')) {
      return Icons.home_work_rounded;
    }
    if (lower.contains('health') ||
        lower.contains('medical') ||
        lower.contains('insurance')) {
      return Icons.favorite_rounded;
    }
    if (lower.contains('finance') ||
        lower.contains('tax') ||
        lower.contains('bank') ||
        lower.contains('pan')) {
      return Icons.account_balance_rounded;
    }
    if (lower.contains('education') ||
        lower.contains('certificate') ||
        lower.contains('school') ||
        lower.contains('degree')) {
      return Icons.school_rounded;
    }
    if (lower.contains('vehicle') || lower.contains('car')) {
      return Icons.directions_car_rounded;
    }
    return Icons.folder_rounded;
  }

  Color _getCategoryColor(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('identity') || lower.contains('passport')) {
      return AppColors.trustEmerald;
    }
    if (lower.contains('property')) return AppColors.securityIndigo;
    if (lower.contains('health') || lower.contains('medical')) {
      return AppColors.categorySky;
    }
    if (lower.contains('finance') || lower.contains('tax')) {
      return AppColors.warningAmber;
    }
    if (lower.contains('education')) return AppColors.categoryPurple;
    return AppColors.securityIndigo;
  }

  @override
  Widget build(BuildContext context) {
    final color = _getCategoryColor(category.name);
    final icon = _getCategoryIcon(category.name);

    return AnimatedPressCard(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.surfaceBorder, width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x060F172A),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Row: Icon badge + Options menu
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(child: Icon(icon, color: color, size: 22)),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: AppColors.textSubtle,
                    size: 20,
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  onPressed: onLongPress,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Bottom Stack: Title + Document Count Pill
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.enclavePrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "${category.documentCount} ${category.documentCount == 1 ? 'doc' : 'docs'}",
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
