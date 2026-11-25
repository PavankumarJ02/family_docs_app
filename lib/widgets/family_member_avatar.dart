import 'package:flutter/material.dart';
import '../models/member.dart';
import '../theme/app_colors.dart';
import 'animated_press_card.dart';

class FamilyMemberCard extends StatelessWidget {
  final Member member;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const FamilyMemberCard({
    super.key,
    required this.member,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isAdmin = member.role.toLowerCase() == 'admin';

    return AnimatedPressCard(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isAdmin
                ? AppColors.securityIndigo.withValues(alpha: 0.3)
                : AppColors.surfaceBorder,
            width: isAdmin ? 1.5 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x080F172A),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Avatar with Role Halo
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: isAdmin
                      ? AppColors.securityIndigoSubtle
                      : AppColors.surfaceMuted,
                  child: Text(
                    member.name.isNotEmpty
                        ? member.name.substring(0, 1).toUpperCase()
                        : 'M',
                    style: TextStyle(
                      color: isAdmin
                          ? AppColors.securityIndigo
                          : AppColors.enclavePrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (isAdmin)
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: AppColors.securityIndigo,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shield,
                        color: Colors.white,
                        size: 11,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Name
            Text(
              member.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.enclavePrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 4),

            // Role & Document count pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "${member.documentCount} ${member.documentCount == 1 ? 'doc' : 'docs'}",
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
