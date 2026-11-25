import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../theme/app_colors.dart';

class SystemLockScreen extends StatefulWidget {
  final Widget nextScreen;

  const SystemLockScreen({super.key, required this.nextScreen});

  @override
  State<SystemLockScreen> createState() => _SystemLockScreenState();
}

class _SystemLockScreenState extends State<SystemLockScreen>
    with SingleTickerProviderStateMixin {
  final LocalAuthentication auth = LocalAuthentication();
  bool isAuthenticating = false;
  String? errorMessage;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    // Initial unlock attempt on launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      authenticate();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> authenticate() async {
    if (isAuthenticating) return;

    setState(() {
      isAuthenticating = true;
      errorMessage = null;
    });

    try {
      final isSupported = await auth.isDeviceSupported();
      if (!isSupported) {
        setState(() {
          isAuthenticating = false;
          errorMessage =
              "Device security or biometrics not detected on this system.";
        });
        return;
      }

      final success = await auth.authenticate(
        localizedReason: 'Unlock to access Family Docs Sanctuary',
        options: const AuthenticationOptions(
          biometricOnly: false,
          useErrorDialogs: true,
          stickyAuth: false,
        ),
      );

      if (!mounted) return;

      if (success) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => widget.nextScreen,
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      } else {
        setState(() {
          isAuthenticating = false;
          errorMessage = "Authentication was cancelled. Tap below to retry.";
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isAuthenticating = false;
        errorMessage = "Security error: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // Sanctuary Vault Medallion
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.cardSurface,
                      border: Border.all(
                        color: AppColors.securityIndigo.withValues(
                          alpha: 0.2 + (_pulseController.value * 0.3),
                        ),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.securityIndigo.withValues(
                            alpha: 0.08 + (_pulseController.value * 0.12),
                          ),
                          blurRadius: 24,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.securityIndigoSubtle,
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          color: AppColors.securityIndigo,
                          size: 30,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // App Name & Security Badge
              const Text(
                "Family Docs",
                style: TextStyle(
                  color: AppColors.enclavePrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
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
                      Icons.shield_rounded,
                      color: AppColors.trustEmerald,
                      size: 13,
                    ),
                    SizedBox(width: 5),
                    Text(
                      "ENCRYPTED SANCTUARY",
                      style: TextStyle(
                        color: Color(0xFF065F46),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              const Text(
                "Unlock with device credentials or biometrics to access your family documents",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),

              // 6 PIN Dots Indicator (Visual Feedback matching Stitch Screen 11)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  final isFilled = isAuthenticating && index < 4;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFilled
                          ? AppColors.securityIndigo
                          : AppColors.surfaceMuted,
                      border: Border.all(
                        color: isFilled
                            ? AppColors.securityIndigo
                            : AppColors.surfaceBorder,
                        width: 1.5,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),

              // Unlock CTA or Error Message
              if (errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.alertRoseSubtle,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.alertRose.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.alertRose,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],

              ElevatedButton.icon(
                onPressed: isAuthenticating ? null : authenticate,
                icon: isAuthenticating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.fingerprint_rounded, size: 22),
                label: Text(isAuthenticating ? "Verifying..." : "Unlock Vault"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.enclavePrimary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(200, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),

              const Spacer(),

              // Security Footnote
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_clock_rounded,
                    color: AppColors.textSubtle,
                    size: 14,
                  ),
                  SizedBox(width: 6),
                  Text(
                    "Local Enclave • Zero-Knowledge Architecture",
                    style: TextStyle(
                      color: AppColors.textSubtle,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
