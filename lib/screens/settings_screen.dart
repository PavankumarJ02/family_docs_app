import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/vault_providers.dart';
import '../theme/app_colors.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(vaultMetricsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings & Security"),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.trustEmeraldSubtle,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.trustEmerald.withValues(alpha: 0.3),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_rounded,
                  size: 13,
                  color: AppColors.trustEmerald,
                ),
                SizedBox(width: 4),
                Text(
                  "Enclave Active",
                  style: TextStyle(
                    color: Color(0xFF065F46),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Hardware Keystore Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.surfaceBorder, width: 1),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.trustEmerald.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.security_rounded,
                    color: AppColors.trustEmerald,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Hardware-Backed Security",
                        style: TextStyle(
                          color: AppColors.enclavePrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        "Protected by platform biometrics (Local Authentication)",
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section 1: Security Controls
          _buildSectionHeader("SECURITY & ACCESS"),
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.surfaceBorder, width: 1),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  value: true,
                  onChanged: (val) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("App Lock is enforced on app launch."),
                      ),
                    );
                  },
                  activeThumbColor: AppColors.securityIndigo,
                  activeTrackColor: AppColors.securityIndigoSubtle,
                  title: const Text(
                    "Biometric / Passcode Lock",
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.enclavePrimary,
                    ),
                  ),
                  subtitle: const Text(
                    "Require Face ID, fingerprint, or device lock on cold launch",
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ),
                const Divider(height: 1, color: AppColors.surfaceBorderSubtle),
                ListTile(
                  leading: const Icon(
                    Icons.timer_outlined,
                    color: AppColors.textMuted,
                  ),
                  title: const Text(
                    "Inactivity Re-lock",
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.enclavePrimary,
                    ),
                  ),
                  subtitle: const Text(
                    "Phase 2 Security Specification (Lifecycle observer)",
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      "Phase 2",
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section 2: Storage & Backup
          _buildSectionHeader("CLOUD BACKUP & STORAGE"),
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.surfaceBorder, width: 1),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.cloud_upload_outlined,
                    color: AppColors.textMuted,
                  ),
                  title: const Text(
                    "Google Drive Backup",
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.enclavePrimary,
                    ),
                  ),
                  subtitle: const Text(
                    "Architecture planned for Phase 3 (Personal & Shared)",
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.securityIndigoSubtle,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      "Planned",
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.securityIndigo,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1, color: AppColors.surfaceBorderSubtle),
                metricsAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (metrics) {
                    return ListTile(
                      leading: const Icon(
                        Icons.storage_rounded,
                        color: AppColors.textMuted,
                      ),
                      title: const Text(
                        "Local Vault Storage",
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.enclavePrimary,
                        ),
                      ),
                      subtitle: Text(
                        "${metrics.formattedStorage} used across ${metrics.totalDocuments} files",
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // About Card
          Center(
            child: Column(
              children: [
                const Text(
                  "Family Docs 2.0 (Phase 1)",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Family Vault Sanctuary • Stitch ID: 1822699660294662437",
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSubtle.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
