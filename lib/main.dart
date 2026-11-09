import 'package:flutter/material.dart';

import 'screens/members_screen.dart';
import 'screens/system_lock_screen.dart';

void main() {
  runApp(const FamilyDocsApp());
}

class FamilyDocsApp extends StatelessWidget {
  const FamilyDocsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Family Documents',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: SystemLockScreen(nextScreen: const MembersScreen()),
    );
  }
}
