import 'package:flutter/material.dart';

import '../state/app_controller.dart';

abstract final class AppMotion {
  static const fast = Duration(milliseconds: 160);
  static const base = Duration(milliseconds: 240);
  static const slow = Duration(milliseconds: 420);
  static const breathing = Duration(milliseconds: 2400);

  static const standardCurve = Curves.easeOutCubic;

  static bool isReduced(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    return AppScope.of(context).reduceMotion ||
        (mediaQuery?.disableAnimations ?? false);
  }

  static Duration duration(BuildContext context, Duration duration) {
    return isReduced(context) ? Duration.zero : duration;
  }

  static AnimationStyle animationStyle(
    BuildContext context, {
    Duration duration = base,
    Duration reverseDuration = fast,
  }) {
    if (isReduced(context)) return AnimationStyle.noAnimation;
    return AnimationStyle(
      duration: duration,
      reverseDuration: reverseDuration,
      curve: standardCurve,
      reverseCurve: Curves.easeInCubic,
    );
  }
}

class AppPageRoute<T> extends MaterialPageRoute<T> {
  AppPageRoute({
    required super.builder,
    required this.reduceMotion,
    super.settings,
  });

  final bool reduceMotion;

  @override
  Duration get transitionDuration =>
      reduceMotion ? Duration.zero : AppMotion.slow;

  @override
  Duration get reverseTransitionDuration =>
      reduceMotion ? Duration.zero : AppMotion.base;
}
