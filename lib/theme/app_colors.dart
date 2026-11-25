import 'package:flutter/material.dart';

/// Semantic Design Tokens for Family Docs 2.0 (Family Vault Sanctuary theme)
class AppColors {
  AppColors._();

  // Canvas & Surfaces
  static const Color surfaceBackground = Color(0xFFF8FAFC);
  static const Color cardSurface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF1F5F9);
  static const Color surfaceBorder = Color(0xFFE2E8F0);
  static const Color surfaceBorderSubtle = Color(0xFFF1F5F9);

  // Enclave Primary & Text
  static const Color enclavePrimary = Color(0xFF0F172A); // Slate 900
  static const Color enclaveSecondary = Color(0xFF1E293B); // Slate 800
  static const Color textMuted = Color(0xFF64748B); // Slate 500
  static const Color textSubtle = Color(0xFF94A3B8); // Slate 400

  // Security & Trust Accents
  static const Color securityIndigo = Color(0xFF4F46E5); // Indigo 600
  static const Color securityIndigoSubtle = Color(0xFFEEF2FF);
  static const Color trustEmerald = Color(0xFF10B981); // Emerald 500
  static const Color trustEmeraldSubtle = Color(0xFFECFDF5);
  static const Color warningAmber = Color(0xFFF59E0B); // Amber 500
  static const Color warningAmberSubtle = Color(0xFFFFFBEB);
  static const Color alertRose = Color(0xFFEF4444); // Rose 500
  static const Color alertRoseSubtle = Color(0xFFFEF2F2);

  // Category Accents
  static const Color categorySky = Color(0xFF0284C7);
  static const Color categorySkySubtle = Color(0xFFF0F9FF);
  static const Color categoryPurple = Color(0xFF8B5CF6);
  static const Color categoryPurpleSubtle = Color(0xFFF5F3FF);

  // Gradients
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
  );

  static const LinearGradient accentPillGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
  );
}
