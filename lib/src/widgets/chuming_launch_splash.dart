import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';
import 'cute_illustrations.dart';

/// 启动过渡动画层：承接 Android 原生启动页的小鸟居中画面，
/// 播放初鸣小鸟欢跃、声波涟漪与音簧律动动画后平滑淡出进入主页，彻底消除启动黑屏与生硬跳变。
class ChumingLaunchSplashOverlay extends StatefulWidget {
  const ChumingLaunchSplashOverlay({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<ChumingLaunchSplashOverlay> createState() =>
      _ChumingLaunchSplashOverlayState();
}

class _ChumingLaunchSplashOverlayState extends State<ChumingLaunchSplashOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 920),
  );

  bool _started = false;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _completed = true);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (AppMotion.isReduced(context)) {
      _completed = true;
      _controller.value = 1;
      return;
    }
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_completed) return widget.child;

    final palette = context.colors;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value.clamp(0.0, 1.0);
        if (t >= 1.0) return child!;

        // 0.00 -> 0.64: 小鸟欢跃与声波绽放；0.64 -> 1.00: 整体轻盈放大并淡出揭示主页
        final exitT = const Interval(
          0.64,
          1.0,
          curve: Curves.easeInOutCubic,
        ).transform(t);
        final overlayOpacity = (1.0 - exitT).clamp(0.0, 1.0);
        final overlayScale = 1.0 + 0.05 * exitT;

        final introT = const Interval(
          0.0,
          0.68,
          curve: Curves.easeOutCubic,
        ).transform(t);
        final hopT = math.sin(introT * math.pi);
        final birdScale = 0.92 + 0.10 * Curves.easeOutBack.transform(introT);
        final birdOffsetY = -12.0 * hopT;

        final titleT = const Interval(
          0.12,
          0.58,
          curve: Curves.easeOutCubic,
        ).transform(t);

        return Stack(
          fit: StackFit.expand,
          children: [
            child!,
            IgnorePointer(
              child: Opacity(
                key: const Key('chuming-launch-splash'),
                opacity: overlayOpacity,
                child: ColoredBox(
                  color: scaffoldBg,
                  child: Transform.scale(
                    scale: overlayScale,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 184,
                            height: 184,
                            child: CustomPaint(
                              painter: _SplashAcousticRipplePainter(
                                progress: introT,
                                primaryColor: palette.primary,
                                accentColor: const Color(0xFF15B462),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  _FloatingNoteBadge(
                                    symbol: '♪',
                                    progress: introT,
                                    angle: -0.72,
                                    distance: 66,
                                    color: palette.primary,
                                  ),
                                  _FloatingNoteBadge(
                                    symbol: '♫',
                                    progress: introT,
                                    angle: 0.65,
                                    distance: 68,
                                    color: const Color(0xFF15B462),
                                  ),
                                  _FloatingNoteBadge(
                                    symbol: '✦',
                                    progress: introT,
                                    angle: -2.25,
                                    distance: 58,
                                    color: const Color(0xFFFF8B1A),
                                  ),
                                  Transform.translate(
                                    offset: Offset(0, birdOffsetY),
                                    child: Transform.scale(
                                      scale: birdScale,
                                      child: const ChumingBird(
                                        size: 112,
                                        mood: ChumingMood.celebrating,
                                        interactive: false,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Opacity(
                            opacity: titleT,
                            child: Transform.translate(
                              offset: Offset(0, (1 - titleT) * 8),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const HarmonicaBrandIcon(size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        context.strings.t('appTitle'),
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 1.2,
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _ReedEqualizerWave(
                                    progress: t,
                                    primaryColor: palette.primary,
                                    accentColor: const Color(0xFF15B462),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: widget.child,
    );
  }
}

class _FloatingNoteBadge extends StatelessWidget {
  const _FloatingNoteBadge({
    required this.symbol,
    required this.progress,
    required this.angle,
    required this.distance,
    required this.color,
  });

  final String symbol;
  final double progress;
  final double angle;
  final double distance;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
    final radius = 24.0 + distance * p;
    final dx = math.cos(angle - math.pi / 2) * radius;
    final dy = math.sin(angle - math.pi / 2) * radius - 6 * p;
    final opacity = math.sin(p * math.pi).clamp(0.0, 1.0);

    return Transform.translate(
      offset: Offset(dx, dy),
      child: Opacity(
        opacity: opacity,
        child: Text(
          symbol,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ReedEqualizerWave extends StatelessWidget {
  const _ReedEqualizerWave({
    required this.progress,
    required this.primaryColor,
    required this.accentColor,
  });

  final double progress;
  final Color primaryColor;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 18,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (index) {
          final phase = progress * math.pi * 2.6 - index * 0.55;
          final wave = (math.sin(phase) + 1) * 0.5;
          final height = 6.0 + 10.0 * wave;
          final isFourthHole = index == 3;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.5),
            child: Container(
              width: 4.5,
              height: height,
              decoration: BoxDecoration(
                color: isFourthHole
                    ? accentColor
                    : primaryColor.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _SplashAcousticRipplePainter extends CustomPainter {
  const _SplashAcousticRipplePainter({
    required this.progress,
    required this.primaryColor,
    required this.accentColor,
  });

  final double progress;
  final Color primaryColor;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.shortestSide * 0.48;

    // 柔和常驻内环底衬
    canvas.drawCircle(
      center,
      maxRadius * 0.66,
      Paint()
        ..color = primaryColor.withValues(alpha: 0.08)
        ..style = PaintingStyle.fill,
    );

    // 两层扩散声波环
    for (var i = 0; i < 2; i++) {
      final ringProgress = ((progress * 1.25) - i * 0.25).clamp(0.0, 1.0);
      if (ringProgress <= 0) continue;
      final radius = maxRadius * (0.48 + 0.52 * ringProgress);
      final alpha = (1.0 - ringProgress) * 0.26;
      final color = i == 0 ? primaryColor : accentColor;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SplashAcousticRipplePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.accentColor != accentColor;
  }
}
