import 'package:flutter/material.dart';

/// Semantic Design Tokens for Blee.
/// Never hardcode hex values inside presentation widgets.
abstract final class AppColors {
  // Brand Accents
  static const Color primary = Color(0xFFE5F925); // Electric Cyber Lime / Hi-Vis Amber
  static const Color onPrimary = Color(0xFF000000); // Deep Black
  static const Color primaryMuted = Color(0x33E5F925); // 20% opacity primary

  static const Color electricCobalt = Color(0xFF2B66FF); // Secondary / Pacer tier
  static const Color onElectricCobalt = Color(0xFFFFFFFF);

  static const Color safetyOrange = Color(0xFFFF5500); // Elite tier / Warning

  // Dark Elevated Slates (Depth without harsh pure black)
  static const Color surfaceBackground = Color(0xFF0D0F12); // Deep Charcoal Slate
  static const Color surfaceBase = Color(0xFF14171C); // Card Background
  static const Color surfaceElevated = Color(0xFF1C2028); // Elevated Card / Modal
  static const Color surfaceBorder = Color(0xFF2A303C); // Subtle dividing line
  static const Color surfaceBorderLight = Color(0xFF384050);

  // Content & Typography
  static const Color textPrimary = Color(0xFFF3F5F7); // High-contrast primary text (14:1)
  static const Color textSecondary = Color(0xFF9DA8B9); // Muted secondary text (5.5:1 WCAG AA)
  static const Color textTertiary = Color(0xFF626E80); // Captions and disabled text

  // Semantic Status
  static const Color success = Color(0xFF00E676);
  static const Color danger = Color(0xFFFF3B30);
  static const Color warning = Color(0xFFFFCC00);
}
