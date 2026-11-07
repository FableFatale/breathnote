import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

class MotionLinearProgress extends StatelessWidget {
  const MotionLinearProgress({
    required this.value,
    super.key,
    this.minHeight = 4,
    this.backgroundColor,
    this.color,
    this.duration = AppMotion.slow,
  });

  final double value;
  final double minHeight;
  final Color? backgroundColor;
  final Color? color;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final target = value.clamp(0.0, 1.0).toDouble();
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: target),
      duration: AppMotion.duration(context, duration),
      curve: AppMotion.standardCurve,
      builder: (context, animatedValue, _) {
        return LinearProgressIndicator(
          value: animatedValue,
          minHeight: minHeight,
          backgroundColor: backgroundColor,
          color: color,
        );
      },
    );
  }
}

class BreathingPulse extends StatefulWidget {
  const BreathingPulse({
    required this.active,
    required this.color,
    required this.child,
    super.key,
    this.shape = BoxShape.rectangle,
    this.borderRadius = const BorderRadius.all(Radius.circular(22)),
  });

  final bool active;
  final Color color;
  final Widget child;
  final BoxShape shape;
  final BorderRadius borderRadius;

  @override
  State<BreathingPulse> createState() => _BreathingPulseState();
}

class _BreathingPulseState extends State<BreathingPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.breathing,
  );
  late final Animation<double> _wave = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 0,
        end: 1,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 50,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1,
        end: 0,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 50,
    ),
  ]).animate(_controller);
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = AppMotion.isReduced(context);
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant BreathingPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  void _syncAnimation() {
    if (widget.active && !_reduceMotion) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
      return;
    }
    _controller
      ..stop()
      ..value = 0;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active || _reduceMotion) return widget.child;
    return RepaintBoundary(
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                key: const Key('breathing-pulse-ring'),
                animation: _wave,
                builder: (context, _) {
                  return Transform.scale(
                    scale: 1 + (_wave.value * 0.18),
                    child: Opacity(
                      opacity: 0.20 - (_wave.value * 0.14),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: widget.shape,
                          borderRadius: widget.shape == BoxShape.rectangle
                              ? widget.borderRadius
                              : null,
                          border: Border.all(color: widget.color, width: 2),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class AnimatedTabStack extends StatefulWidget {
  const AnimatedTabStack({
    required this.index,
    required this.children,
    required this.duration,
    super.key,
  });

  final int index;
  final List<Widget> children;
  final Duration duration;

  @override
  State<AnimatedTabStack> createState() => _AnimatedTabStackState();
}

class _AnimatedTabStackState extends State<AnimatedTabStack>
    with SingleTickerProviderStateMixin {
  late int _previousIndex = widget.index;
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: 1,
  );

  @override
  void didUpdateWidget(covariant AnimatedTabStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = widget.duration;
    if (oldWidget.index == widget.index) {
      if (widget.duration == Duration.zero) _controller.value = 1;
      return;
    }
    _previousIndex = oldWidget.index;
    if (widget.duration == Duration.zero) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    assert(widget.index >= 0 && widget.index < widget.children.length);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = AppMotion.standardCurve.transform(_controller.value);
        return Stack(
          fit: StackFit.expand,
          children: List.generate(widget.children.length, (index) {
            final current = index == widget.index;
            final previous =
                index == _previousIndex && _controller.value < 1 && !current;
            final visible = current || previous;
            final opacity = current ? progress : 1 - progress;
            return Offstage(
              offstage: !visible,
              child: IgnorePointer(
                ignoring: !current,
                child: TickerMode(
                  enabled: current,
                  child: Opacity(
                    opacity: visible ? opacity : 0,
                    child: widget.children[index],
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
