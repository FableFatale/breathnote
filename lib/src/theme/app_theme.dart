import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFF14151A);
  static const surface = Color(0xFF1E1F25);
  static const surfaceHigh = Color(0xFF2A2B32);
  static const primary = Color(0xFF93A9E8);
  static const onPrimary = Color(0xFF10131F);
  static const accent = Color(0xFFEDB07A);
  static const text = Color(0xFFF2F0EC);
  static const muted = Color(0xFFA3A1A8);
  static const success = Color(0xFF8CCFA4);
  static const outline = Color(0xFF3A3B43);
}

abstract final class AppTheme {
  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      surface: AppColors.surface,
      onSurface: AppColors.text,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'sans-serif',
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          color: AppColors.text,
          fontSize: 31,
          height: 1.16,
          fontWeight: FontWeight.w700,
        ),
        headlineSmall: TextStyle(
          color: AppColors.text,
          fontSize: 22,
          height: 1.25,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          color: AppColors.text,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        bodyMedium: TextStyle(
          color: AppColors.text,
          fontSize: 14,
          height: 1.45,
          fontWeight: FontWeight.w500,
        ),
        bodySmall: TextStyle(
          color: AppColors.muted,
          fontSize: 12,
          height: 1.4,
          fontWeight: FontWeight.w500,
        ),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.outline),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primary.withValues(alpha: 0.22),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.muted,
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w600,
          );
        }),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: AppColors.surfaceHigh,
        thumbColor: AppColors.primary,
      ),
    );
  }
}
