import 'package:flutter/material.dart';

import '../state/app_controller.dart';

abstract final class AppMotion {
  static const fast = Duration(milliseconds: 160);
  static const base = Duration(milliseconds: 240);
  static const slow = Duration(milliseconds: 420);
  static const breathing = Duration(milliseconds: 2400);

  static const standardCurve = Curves.easeOutCubic;
  static const sheetCurve = Cubic(0.32, 0.72, 0, 1);

  static bool isReduced(BuildContext context) {
    final mediaQuery = context.getInheritedWidgetOfExactType<MediaQuery>()?.data;
    final reduceMotion = AppScope.maybeRead(context)?.reduceMotion ?? false;
    return reduceMotion || (mediaQuery?.disableAnimations ?? false);
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

  static AnimationStyle sheetAnimationStyle(BuildContext context) {
    if (isReduced(context)) return AnimationStyle.noAnimation;
    return const AnimationStyle(
      duration: slow,
      reverseDuration: base,
      curve: sheetCurve,
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

class ReducedMotionPageScrollPhysics extends PageScrollPhysics {
  const ReducedMotionPageScrollPhysics({super.parent});

  static const _settleSpring = SpringDescription(
    mass: 1,
    stiffness: 900,
    damping: 60,
  );

  @override
  ReducedMotionPageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return ReducedMotionPageScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if (position.viewportDimension <= 0) return null;
    if (position.outOfRange) {
      return super.createBallisticSimulation(position, 0);
    }

    final target =
        ((position.pixels / position.viewportDimension).round() *
                position.viewportDimension)
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble();
    if ((target - position.pixels).abs() <= toleranceFor(position).distance) {
      return null;
    }
    return ScrollSpringSimulation(
      _settleSpring,
      position.pixels,
      target,
      0,
      tolerance: toleranceFor(position),
    );
  }
}
