import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/haptics.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';

/// 左右滑动交互手势引导（首次自动播放一次，用户点击可随时多次重播）
class SwipeGestureGuide extends StatefulWidget {
  const SwipeGestureGuide({
    super.key,
    required this.label,
  });

  final String label;

  @override
  State<SwipeGestureGuide> createState() => _SwipeGestureGuideState();
}

class _SwipeGestureGuideState extends State<SwipeGestureGuide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  bool _playedInitial = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_playedInitial) {
      _playedInitial = true;
      _playOnce();
    }
  }

  void _playOnce() {
    if (AppMotion.isReduced(context)) return;
    _controller.forward(from: 0);
  }

  void _replay() {
    unawaited(AppHaptics.selection(context));
    _playOnce();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final isReduced = AppMotion.isReduced(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('swipe-gesture-guide'),
        onTap: _replay,
        borderRadius: BorderRadius.circular(999),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.surfaceHigh.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: palette.outline,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = isReduced ? 0.0 : _controller.value;
                // 两次柔和摆动后归位: sin(t * 2 * pi) * (1 - t)
                final slideOffset =
                    math.sin(t * math.pi * 2) * (1.0 - t * 0.5) * 8.0;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.translate(
                      offset: Offset(slideOffset, 0),
                      child: Icon(
                        Icons.swipe_rounded,
                        size: 15,
                        color: palette.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: palette.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.replay_rounded,
                      size: 13,
                      color: palette.muted,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// 吹吸垂直呼吸动势手势引导（首次自动引导，切换音符自动触发，点击可随时重播）
class BreathGestureGuide extends StatefulWidget {
  const BreathGestureGuide({
    super.key,
    required this.isBlow,
    required this.label,
    this.compact = false,
  });

  final bool isBlow;
  final String label;
  final bool compact;

  @override
  State<BreathGestureGuide> createState() => _BreathGestureGuideState();
}

class _BreathGestureGuideState extends State<BreathGestureGuide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );

  bool _playedInitial = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_playedInitial) {
      _playedInitial = true;
      _playOnce();
    }
  }

  @override
  void didUpdateWidget(covariant BreathGestureGuide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isBlow != widget.isBlow || oldWidget.label != widget.label) {
      _playOnce();
    }
  }

  void _playOnce() {
    if (AppMotion.isReduced(context)) return;
    _controller.forward(from: 0);
  }

  void _replay() {
    unawaited(AppHaptics.selection(context));
    _playOnce();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final isReduced = AppMotion.isReduced(context);
    final isBlow = widget.isBlow;
    final color = isBlow ? palette.primary : palette.accent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('breath-gesture-guide'),
        onTap: _replay,
        borderRadius: BorderRadius.circular(999),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: color.withValues(alpha: 0.28),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: widget.compact ? 10 : 12,
              vertical: widget.compact ? 4 : 6,
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = isReduced ? 0.0 : _controller.value;
                // 垂直呼吸位移曲线：在重播过程中平滑上浮（吹气）或下沉（吸气）后归位
                final wave = math.sin(t * math.pi);
                final dy = (isBlow ? -1.0 : 1.0) * wave * 5.0;

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.translate(
                      offset: Offset(0, dy),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                        child: SizedBox.square(
                          dimension: widget.compact ? 18 : 20,
                          child: Icon(
                            isBlow
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
                            size: widget.compact ? 12 : 14,
                            color: palette.onPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: widget.compact ? 11 : 12,
                          fontWeight: FontWeight.w700,
                          color: isBlow ? palette.primary : palette.accentInk,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.replay_rounded,
                      size: widget.compact ? 12 : 14,
                      color: isBlow ? palette.primary : palette.accentInk,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// 轻触点击波纹引导（首次进入自动播放两道光环后静止，外部也可通过点击触发）
class TapGesturePulse extends StatefulWidget {
  const TapGesturePulse({
    super.key,
    required this.child,
    this.enabled = true,
  });

  final Widget child;
  final bool enabled;

  @override
  State<TapGesturePulse> createState() => _TapGesturePulseState();
}

class _TapGesturePulseState extends State<TapGesturePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  bool _playedInitial = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_playedInitial && widget.enabled) {
      _playedInitial = true;
      if (!AppMotion.isReduced(context)) {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void didUpdateWidget(covariant TapGesturePulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.enabled && widget.enabled && !AppMotion.isReduced(context)) {
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
    if (!widget.enabled || AppMotion.isReduced(context)) {
      return widget.child;
    }

    final palette = context.colors;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          foregroundPainter: _PulseRingPainter(
            progress: _controller.value,
            color: palette.primary,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _PulseRingPainter extends CustomPainter {
  _PulseRingPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;

    final inflate = 10.0 * progress;
    final rect = (Offset.zero & size).inflate(inflate);
    final cornerRadius = math.min(size.width, size.height) * 0.34 + inflate;
    final alpha = (1.0 - progress) * 0.45;

    final paint = Paint()
      ..color = color.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(cornerRadius)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _PulseRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
