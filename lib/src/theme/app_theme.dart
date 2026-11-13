import 'package:flutter/material.dart';

import 'palermo_tokens.dart';

export 'palermo_tokens.dart';

const _lightPrimary = Color(0xFF376CFF);
const _lightAccent = Color(0xFFFE6E00);
const _darkPrimary = Color(0xFF6FA8FF);
const _darkAccent = Color(0xFFF2B272);

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

  /// Palermo Light Mode Palette (`palermo.tryprofound.com/docs/colors`)
  static const light = AppPalette(
    background: PalermoTokens.lightBgSecondary, // #FAFAFA
    surface: PalermoTokens.lightBgPrimary, // #FFFFFF
    surfaceHigh: PalermoTokens.lightBgTertiary, // #F5F5F5
    primary: _lightPrimary, // #376CFF
    onPrimary: Color(0xFFFFFFFF),
    accent: _lightAccent, // #FE6E00
    accentInk: Color(0xFF1B3EA7),
    text: PalermoTokens.lightTextPrimary, // #18181A
    muted: PalermoTokens.lightTextSecondary, // #787878
    success: Color(0xFF15B462), // #15B462
    warning: Color(0xFFF99C00), // #F99C00
    danger: Color(0xFFFF5F57), // #FF5F57
    outline: PalermoTokens.lightBorder, // #EBEBEB
  );

  /// Palermo Dark Mode Palette
  static const dark = AppPalette(
    background: Color(0xFF18181A),
    surface: Color(0xFF222224),
    surfaceHigh: Color(0xFF2A2A2D),
    primary: _darkPrimary,
    onPrimary: Color(0xFF101319),
    accent: _darkAccent,
    accentInk: _darkPrimary,
    text: Color(0xFFF2F0EC),
    muted: Color(0xFFAAA7A3),
    success: _darkPrimary,
    warning: _darkAccent,
    danger: Color(0xFFF08AB8),
    outline: Color(0x12FFFFFF),
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

  static const List<Color> holeSpectrum = PalermoTokens.holeSpectrum;

  static Color holeColor(int hole) {
    final index = (hole - 1).clamp(0, holeSpectrum.length - 1);
    return holeSpectrum[index];
  }
}

extension AppThemeContext on BuildContext {
  AppPalette get colors =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;

  AppPalette get palette => colors;
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
          secondary: palette.primary,
          surface: palette.surface,
          error: palette.danger,
        ).copyWith(
          primary: palette.primary,
          onPrimary: palette.onPrimary,
          secondary: palette.primary,
          onSecondary: palette.onPrimary,
          primaryContainer: palette.primary.withValues(alpha: 0.10),
          onPrimaryContainer: textColor,
          surface: palette.surface,
          onSurface: textColor,
          onSurfaceVariant: palette.muted,
          surfaceContainerLow: palette.surface,
          surfaceContainer: palette.surface,
          surfaceContainerHigh: palette.surfaceHigh,
          surfaceContainerHighest: palette.surfaceHigh,
          outline: outline,
          error: palette.danger,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: 'MingjieSans',
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
        displayLarge: TextStyle(
          color: textColor,
          fontFamily: 'MingjieSans',
          fontSize: 60,
          height: 1.0,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.0,
        ),
        displaySmall: TextStyle(
          color: textColor,
          fontFamily: 'MingjieSans',
          fontSize: 28,
          height: 1.2,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.25,
        ),
        headlineSmall: TextStyle(
          color: textColor,
          fontFamily: 'MingjieSans',
          fontSize: 20,
          height: 1.3,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.25,
        ),
        titleLarge: TextStyle(
          color: textColor,
          fontFamily: 'MingjieSans',
          fontSize: 20,
          height: 1.3,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.25,
        ),
        titleMedium: TextStyle(
          color: textColor,
          fontFamily: 'MingjieSans',
          fontSize: 18,
          height: 1.33,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.25,
        ),
        bodyMedium: TextStyle(
          color: textColor,
          fontSize: 14,
          height: 1.5,
          fontWeight: FontWeight.w500,
          letterSpacing: 0,
        ),
        bodySmall: TextStyle(
          color: palette.muted,
          fontSize: 12,
          height: 1.4,
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
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PalermoTokens.radius20),
          side: BorderSide(color: outline),
        ),
      ),
      dialogTheme: DialogThemeData(
        elevation: 8,
        shadowColor: const Color(0x1F000000),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PalermoTokens.radius20),
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
          fontFamily: 'MingjieSans',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.25,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 76,
        elevation: 0,
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
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
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            letterSpacing: 0,
          );
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PalermoTokens.radius12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          side: BorderSide(color: outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PalermoTokens.radius12),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PalermoTokens.radius12),
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
          borderRadius: BorderRadius.circular(PalermoTokens.radius12),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PalermoTokens.radius12),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PalermoTokens.radius12),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PalermoTokens.radius12),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        modalElevation: 8,
        shadowColor: const Color(0x1F000000),
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
