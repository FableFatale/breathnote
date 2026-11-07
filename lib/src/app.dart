import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'localization/app_strings.dart';
import 'screens/home_shell.dart';
import 'state/app_controller.dart';
import 'theme/app_motion.dart';
import 'theme/app_theme.dart';

class BreathnoteApp extends StatefulWidget {
  const BreathnoteApp({super.key, this.controller});

  final AppController? controller;

  @override
  State<BreathnoteApp> createState() => _BreathnoteAppState();
}

class _BreathnoteAppState extends State<BreathnoteApp> {
  late final AppController _controller = widget.controller ?? AppController();
  late final bool _ownsController = widget.controller == null;

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: _controller,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final animationDuration = _controller.reduceMotion
              ? Duration.zero
              : AppMotion.base;
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            onGenerateTitle: (context) => context.strings.t('appTitle'),
            locale: Locale(_controller.languageCode),
            supportedLocales: const [Locale('zh'), Locale('en'), Locale('ja')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            theme: AppTheme.light(
              highContrast: _controller.highContrast,
              reduceMotion: _controller.reduceMotion,
            ),
            darkTheme: AppTheme.dark(
              highContrast: _controller.highContrast,
              reduceMotion: _controller.reduceMotion,
            ),
            themeMode: _controller.themeMode,
            themeAnimationDuration: animationDuration,
            builder: (context, child) {
              final mediaQuery = MediaQuery.of(context);
              final systemScale = mediaQuery.textScaler.scale(1);
              final effectiveScale = (systemScale * _controller.textScale)
                  .clamp(0.9, 1.5);
              return MediaQuery(
                data: mediaQuery.copyWith(
                  textScaler: TextScaler.linear(effectiveScale.toDouble()),
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: const HomeShell(),
          );
        },
      ),
    );
  }
}
