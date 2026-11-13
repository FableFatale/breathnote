import 'package:flutter/material.dart';

/// Semantic color family from Palermo Design System (`palermo.tryprofound.com/docs/colors`)
/// Each accent family provides 4 coordinated tokens:
/// - [base]: Primary vibrant fill / icon color
/// - [border]: Subtle hairline border tint
/// - [mutedFill]: Soft background badge/pill fill
/// - [emphasis]: High-contrast text / ink color on [mutedFill]
@immutable
class PalermoSemanticFamily {
  const PalermoSemanticFamily({
    required this.base,
    required this.border,
    required this.mutedFill,
    required this.emphasis,
  });

  final Color base;
  final Color border;
  final Color mutedFill;
  final Color emphasis;
}

/// Complete Palermo Design System Tokens adapted for Breathnote (初鸣)
abstract final class PalermoTokens {
  // ── Light Mode Surfaces (`--color-bg-*`) ──────────────────────────
  static const lightBgBase = Color(0xFFFFFFFF);
  static const lightBgPrimary = Color(0xFFFFFFFF);
  static const lightBgSecondary = Color(0xFFFAFAFA);
  static const lightBgTertiary = Color(0xFFF5F5F5);
  static const lightBgQuaternary = Color(0xFFE8E8E8);

  // ── Light Mode Foregrounds & Borders (`--color-text-*`, `--ds-border`) ──
  static const lightTextPrimary = Color(0xFF18181A);
  static const lightTextSecondary = Color(0xFF787878);
  static const lightTextTertiary = Color(0xFF969696);
  static const lightTextQuaternary = Color(0xFFB4B4B4);
  static const lightBorder = Color(0xFFEBEBEB);
  static const lightBorderHard = Color(0xFFD4D4D8);

  // ── Dark Mode Surfaces (`--ds-bg-*`) ──────────────────────────────
  static const darkBgBase = Color(0xFF18181A);
  static const darkBgPrimary = Color(0xFF222224);
  static const darkBgSecondary = Color(0xFF27272A);
  static const darkBgTertiary = Color(0xFF2E2E32);
  static const darkBgQuaternary = Color(0xFF3F3F46);

  // ── Dark Mode Foregrounds & Borders ───────────────────────────────
  static const darkTextPrimary = Color(0xFFF4F4F5);
  static const darkTextSecondary = Color(0xFFA1A1AA);
  static const darkTextTertiary = Color(0xFF71717A);
  static const darkBorder = Color(0x14FFFFFF);

  // ── Semantic Accent Families (Light Mode) ─────────────────────────
  static const blueLight = PalermoSemanticFamily(
    base: Color(0xFF376CFF),
    border: Color(0xFFE0EDFF),
    mutedFill: Color(0xFFEFF6FF),
    emphasis: Color(0xFF1B3EA7),
  );

  static const greenLight = PalermoSemanticFamily(
    base: Color(0xFF15B462),
    border: Color(0xFFC7F4D7),
    mutedFill: Color(0xFFE6FBEC),
    emphasis: Color(0xFF0D542B),
  );

  static const orangeLight = PalermoSemanticFamily(
    base: Color(0xFFFE6E00),
    border: Color(0xFFF7E4CB),
    mutedFill: Color(0xFFFFF7ED),
    emphasis: Color(0xFF9F2D00),
  );

  static const amberLight = PalermoSemanticFamily(
    base: Color(0xFFF99C00),
    border: Color(0xFFF5ECC4),
    mutedFill: Color(0xFFFFFBEB),
    emphasis: Color(0xFF953D00),
  );

  static const redLight = PalermoSemanticFamily(
    base: Color(0xFFFF5F57),
    border: Color(0xFFFFE6E6),
    mutedFill: Color(0xFFFEF2F2),
    emphasis: Color(0xFF9F0712),
  );

  static const purpleLight = PalermoSemanticFamily(
    base: Color(0xFF9747FF),
    border: Color(0xFFF1E4FA),
    mutedFill: Color(0xFFFAF5FF),
    emphasis: Color(0xFF59168B),
  );

  static const cyanLight = PalermoSemanticFamily(
    base: Color(0xFF00B5BC),
    border: Color(0xFFC7EDEF),
    mutedFill: Color(0xFFE6FAFA),
    emphasis: Color(0xFF006469),
  );

  // ── Semantic Accent Families (Dark Mode) ──────────────────────────
  static const blueDark = PalermoSemanticFamily(
    base: Color(0xFF5E9EFF),
    border: Color(0xFF28467A),
    mutedFill: Color(0xFF17233B),
    emphasis: Color(0xFF99C2FF),
  );

  static const greenDark = PalermoSemanticFamily(
    base: Color(0xFF60F178),
    border: Color(0xFF1E542B),
    mutedFill: Color(0xFF122B18),
    emphasis: Color(0xFF98F7A7),
  );

  static const orangeDark = PalermoSemanticFamily(
    base: Color(0xFFFF8940),
    border: Color(0xFF613417),
    mutedFill: Color(0xFF2E190B),
    emphasis: Color(0xFFFFB380),
  );

  static const redDark = PalermoSemanticFamily(
    base: Color(0xFFFF6369),
    border: Color(0xFF632427),
    mutedFill: Color(0xFF301214),
    emphasis: Color(0xFFFFA1A4),
  );

  static PalermoSemanticFamily blue(bool isDark) =>
      isDark ? blueDark : blueLight;
  static PalermoSemanticFamily green(bool isDark) =>
      isDark ? greenDark : greenLight;
  static PalermoSemanticFamily orange(bool isDark) =>
      isDark ? orangeDark : orangeLight;
  static PalermoSemanticFamily red(bool isDark) =>
      isDark ? redDark : redLight;

  // ── 10-Hole Chromatic Spectrum (Palermo Workflow Palette) ─────────
  static const List<Color> holeSpectrum = [
    Color(0xFFFF5F57), // Hole 1 - Coral Red
    Color(0xFFFE6E00), // Hole 2 - Warm Orange
    Color(0xFFF99C00), // Hole 3 - Golden Amber
    Color(0xFF15B462), // Hole 4 - Emerald Green (First Note C5)
    Color(0xFF00B5BC), // Hole 5 - Teal Cyan
    Color(0xFF3080FF), // Hole 6 - Sky Blue
    Color(0xFF376CFF), // Hole 7 - Profound Blue
    Color(0xFF6366F1), // Hole 8 - Indigo
    Color(0xFF9747FF), // Hole 9 - Vivid Purple
    Color(0xFFF57FA7), // Hole 10 - Rose Pink
  ];

  // ── Border Radii (`--radius-*`) ───────────────────────────────────
  static const double radius4 = 4;
  static const double radius6 = 6;
  static const double radius8 = 8;
  static const double radius10 = 10;
  static const double radius12 = 12;
  static const double radius16 = 16;
  static const double radius20 = 20;
  static const double radius24 = 24;
  static const double radiusFull = 9999;

  // ── Palermo Surface Shadows (`--shadow-low`, `--shadow-medium`) ───
  static const List<BoxShadow> shadowLowLight = [
    BoxShadow(
      color: Color(0x06000000),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
    BoxShadow(
      color: Color(0x08000000),
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> shadowMediumLight = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x05000000),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];
}
