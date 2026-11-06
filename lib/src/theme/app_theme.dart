import 'package:flutter/material.dart';

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.primary,
    required this.onPrimary,
    required this.accent,
    required this.accentInk,
    required this.text,
    required this.muted,
    required this.success,
    required this.warning,
    required this.danger,
    required this.outline,
  });

  static const light = AppPalette(
    background: Color(0xFFF6F1E9),
    surface: Color(0xFFFFFCF7),
    surfaceHigh: Color(0xFFEFE7DA),
    primary: Color(0xFF2F4A8A),
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFFE39B5B),
    accentInk: Color(0xFFA35A1F),
    text: Color(0xFF2A2620),
    muted: Color(0xFF7A7064),
    success: Color(0xFF3E8A5E),
    warning: Color(0xFF8A5A00),
    danger: Color(0xFFB3261E),
    outline: Color(0xFFDDD3C5),
  );

  static const dark = AppPalette(
    background: Color(0xFF14151A),
    surface: Color(0xFF1E1F25),
    surfaceHigh: Color(0xFF2A2B32),
    primary: Color(0xFF93A9E8),
    onPrimary: Color(0xFF10131F),
    accent: Color(0xFFEDB07A),
    accentInk: Color(0xFFEDB07A),
    text: Color(0xFFF2F0EC),
    muted: Color(0xFFA3A1A8),
    success: Color(0xFF8CCFA4),
    warning: Color(0xFFF0C46A),
    danger: Color(0xFFF08A80),
    outline: Color(0xFF3A3B43),
  );

  final Color background;
  final Color surface;
  final Color surfaceHigh;
  final Color primary;
  final Color onPrimary;
  final Color accent;
  final Color accentInk;
  final Color text;
  final Color muted;
  final Color success;
  final Color warning;
  final Color danger;
  final Color outline;

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceHigh,
    Color? primary,
    Color? onPrimary,
    Color? accent,
    Color? accentInk,
    Color? text,
    Color? muted,
    Color? success,
    Color? warning,
    Color? danger,
    Color? outline,
  }) {
    return AppPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      accent: accent ?? this.accent,
      accentInk: accentInk ?? this.accentInk,
      text: text ?? this.text,
      muted: muted ?? this.muted,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      outline: outline ?? this.outline,
    );
  }

  @override
  AppPalette lerp(covariant AppPalette? other, double t) {
    if (other == null) return this;
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentInk: Color.lerp(accentInk, other.accentInk, t)!,
      text: Color.lerp(text, other.text, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppPalette get colors =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}

abstract final class AppTheme {
  static ThemeData light({
    required bool highContrast,
    required bool reduceMotion,
  }) {
    return _build(
      palette: AppPalette.light,
      brightness: Brightness.light,
      highContrast: highContrast,
      reduceMotion: reduceMotion,
    );
  }

  static ThemeData dark({
    required bool highContrast,
    required bool reduceMotion,
  }) {
    return _build(
      palette: AppPalette.dark,
      brightness: Brightness.dark,
      highContrast: highContrast,
      reduceMotion: reduceMotion,
    );
  }

  static ThemeData _build({
    required AppPalette palette,
    required Brightness brightness,
    required bool highContrast,
    required bool reduceMotion,
  }) {
    final textColor = highContrast
        ? brightness == Brightness.dark
              ? Colors.white
              : Colors.black
        : palette.text;
    final outline = highContrast ? palette.muted : palette.outline;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: palette.primary,
          brightness: brightness,
          primary: palette.primary,
          onPrimary: palette.onPrimary,
          secondary: palette.accent,
          surface: palette.surface,
          error: palette.danger,
        ).copyWith(
          onSurface: textColor,
          onSurfaceVariant: palette.muted,
          surfaceContainer: palette.surface,
          surfaceContainerHigh: palette.surfaceHigh,
          outline: outline,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.background,
      extensions: [palette],
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          for (final platform in TargetPlatform.values)
            platform: reduceMotion
                ? const _NoTransitionsBuilder()
                : const FadeForwardsPageTransitionsBuilder(),
        },
      ),
      textTheme: TextTheme(
        displaySmall: TextStyle(
          color: textColor,
          fontFamily: 'serif',
          fontSize: 30,
          height: 1.22,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        headlineSmall: TextStyle(
          color: textColor,
          fontFamily: 'serif',
          fontSize: 20,
          height: 1.3,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        titleLarge: TextStyle(
          color: textColor,
          fontFamily: 'serif',
          fontSize: 20,
          height: 1.3,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        titleMedium: TextStyle(
          color: textColor,
          fontSize: 16,
          height: 1.35,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        bodyMedium: TextStyle(
          color: textColor,
          fontSize: 14,
          height: 1.55,
          fontWeight: FontWeight.w500,
          letterSpacing: 0,
        ),
        bodySmall: TextStyle(
          color: palette.muted,
          fontSize: 11,
          height: 1.45,
          fontWeight: FontWeight.w500,
          letterSpacing: 0,
        ),
        labelLarge: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
      cardTheme: CardThemeData(
        color: palette.surface,
        elevation: brightness == Brightness.light ? 1 : 0,
        shadowColor: const Color(0x332A2118),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: outline),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        foregroundColor: textColor,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: textColor,
          fontFamily: 'serif',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 80,
        elevation: 0,
        backgroundColor: palette.surfaceHigh,
        indicatorColor: palette.primary.withValues(alpha: 0.12),
        indicatorShape: const StadiumBorder(),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? palette.primary
                : palette.muted,
            size: 22,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            color: states.contains(WidgetState.selected)
                ? palette.primary
                : palette.muted,
            fontSize: 10,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w600,
            letterSpacing: 0,
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          side: BorderSide(color: outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: palette.primary, width: 2),
        ),
      ),
      dividerColor: outline,
      sliderTheme: SliderThemeData(
        activeTrackColor: palette.primary,
        inactiveTrackColor: palette.surfaceHigh,
        thumbColor: palette.primary,
        overlayColor: palette.primary.withValues(alpha: 0.12),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? palette.onPrimary
              : palette.surface;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? palette.primary
              : palette.surfaceHigh;
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: textColor,
        contentTextStyle: TextStyle(color: palette.background),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),
    );
  }
}

class _NoTransitionsBuilder extends PageTransitionsBuilder {
  const _NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}
