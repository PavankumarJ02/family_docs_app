import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/members_screen.dart';
import 'screens/system_lock_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: FamilyDocsApp()));
}

class FamilyDocsApp extends StatelessWidget {
  const FamilyDocsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Family Docs',
      theme: AppTheme.lightTheme,
      home: const SystemLockScreen(nextScreen: MembersScreen()),
    );
  }
}
