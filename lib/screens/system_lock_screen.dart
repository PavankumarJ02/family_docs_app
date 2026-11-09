import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

class SystemLockScreen extends StatefulWidget {
  final Widget nextScreen;

  const SystemLockScreen({super.key, required this.nextScreen});

  @override
  State<SystemLockScreen> createState() => _SystemLockScreenState();
}

class _SystemLockScreenState extends State<SystemLockScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  bool isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    authenticate(); // 🔐 ONLY ONCE
  }

  Future<void> authenticate() async {
    try {
      final isSupported = await auth.isDeviceSupported();
      if (!isSupported) {
        showError("Device security not supported");
        return;
      }

      final success = await auth.authenticate(
        localizedReason: 'Unlock to access family documents',
        options: const AuthenticationOptions(
          biometricOnly: false, // 🔑 REQUIRED
          useErrorDialogs: true,
          stickyAuth: false,
        ),
      );

      if (!mounted) return;

      if (success) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => widget.nextScreen),
        );
      }
    } catch (e) {
      showError("Authentication error: $e");
    }
  }

  void showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
