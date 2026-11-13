import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/haptics.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';

enum ChumingMood {
  idle,
  listening,
  blowing,
  drawing,
  celebrating,
}

/// 定制无角一体口琴品牌图标（替换原有的钢琴图标与带角图标）
class HarmonicaBrandIcon extends StatelessWidget {
  const HarmonicaBrandIcon({
    super.key,
    this.size = 22,
    this.color,
    this.accentColor,
  });

  final double size;
  final Color? color;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return CustomPaint(
      size: Size.square(size),
      painter: _HarmonicaBrandIconPainter(
        color: color ?? palette.primary,
        accentColor: accentColor ?? palette.accent,
      ),
    );
  }
}

class _HarmonicaBrandIconPainter extends CustomPainter {
  const _HarmonicaBrandIconPainter({
    required this.color,
    required this.accentColor,
  });

  final Color color;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 阶梯一体口琴外框（无任何顶部突兀角线）
    final bodyPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final bodyPath = Path()
      ..moveTo(w * 0.14, h * 0.34)
      ..lineTo(w * 0.46, h * 0.34)
      ..quadraticBezierTo(w * 0.51, h * 0.34, w * 0.54, h * 0.28)
      ..quadraticBezierTo(w * 0.57, h * 0.24, w * 0.62, h * 0.24)
      ..lineTo(w * 0.86, h * 0.24)
      ..arcToPoint(
        Offset(w * 0.94, h * 0.32),
        radius: Radius.circular(w * 0.08),
      )
      ..lineTo(w * 0.94, h * 0.68)
      ..arcToPoint(
        Offset(w * 0.86, h * 0.76),
        radius: Radius.circular(w * 0.08),
      )
      ..lineTo(w * 0.14, h * 0.76)
      ..arcToPoint(
        Offset(w * 0.06, h * 0.68),
        radius: Radius.circular(w * 0.08),
      )
      ..lineTo(w * 0.06, h * 0.42)
      ..arcToPoint(
        Offset(w * 0.14, h * 0.34),
        radius: Radius.circular(w * 0.08),
      )
      ..close();

    canvas.drawPath(bodyPath, bodyPaint);

    // 内部琴格与 5 个代表性音孔窗口（第 2 孔高亮代表初鸣第 4 孔）
    final holePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.92)
      ..style = PaintingStyle.fill;
    final highlightPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;

    const count = 5;
    final startX = w * 0.16;
    final endX = w * 0.84;
    final holeW = w * 0.085;
    final gap = (endX - startX - holeW * count) / (count - 1);

    for (var i = 0; i < count; i++) {
      final x = startX + i * (holeW + gap);
      final isFourth = i == 1;
      final top = isFourth ? h * 0.43 : h * 0.46;
      final bottom = isFourth ? h * 0.65 : h * 0.62;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(x, top, x + holeW, bottom),
          Radius.circular(holeW * 0.45),
        ),
        isFourth ? highlightPaint : holePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HarmonicaBrandIconPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.accentColor != accentColor;
  }
}

/// 初鸣吉祥物小鸟（纯矢量绘制，首次自动播放一次动画，点击可多次重播）
class ChumingBird extends StatefulWidget {
  const ChumingBird({
    super.key,
    this.mood = ChumingMood.idle,
    this.size = 64,
    this.primaryColor,
    this.accentColor,
    this.interactive = true,
  });

  final ChumingMood mood;
  final double size;
  final Color? primaryColor;
  final Color? accentColor;
  final bool interactive;

  @override
  State<ChumingBird> createState() => _ChumingBirdState();
}

class _ChumingBirdState extends State<ChumingBird>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final Animation<double> _wave = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(begin: 0, end: 1)
          .chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 50,
    ),
    TweenSequenceItem(
      tween: Tween<double>(begin: 1, end: 0)
          .chain(CurveTween(curve: Curves.easeInOutCubic)),
      weight: 50,
    ),
  ]).animate(_animController);

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
  void didUpdateWidget(covariant ChumingBird oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mood != widget.mood) {
      _playOnce();
    }
  }

  void _playOnce() {
    if (AppMotion.isReduced(context)) return;
    _animController.forward(from: 0);
  }

  void _handleReplay() {
    unawaited(AppHaptics.selection(context));
    _playOnce();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final isReduced = AppMotion.isReduced(context);

    final bird = AnimatedBuilder(
      animation: _wave,
      builder: (context, _) {
        final animValue = isReduced ? 0.0 : _wave.value;
        return CustomPaint(
          size: Size.square(widget.size),
          painter: _ChumingBirdPainter(
            mood: widget.mood,
            animProgress: animValue,
            bodyColor: widget.primaryColor ?? palette.primary,
            accentColor: widget.accentColor ?? palette.accent,
            isDark: Theme.of(context).brightness == Brightness.dark,
          ),
        );
      },
    );

    if (!widget.interactive) return bird;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleReplay,
      child: bird,
    );
  }
}

class _ChumingBirdPainter extends CustomPainter {
  _ChumingBirdPainter({
    required this.mood,
    required this.animProgress,
    required this.bodyColor,
    required this.accentColor,
    required this.isDark,
  });

  final ChumingMood mood;
  final double animProgress;
  final Color bodyColor;
  final Color accentColor;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2 - (animProgress * h * 0.04));

    // 1. 底部柔和阴影
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: isDark ? 0.24 : 0.08);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, h * 0.88),
        width: w * (0.58 - animProgress * 0.06),
        height: h * 0.12,
      ),
      shadowPaint,
    );

    // 2. 圆润雏鸟躯干
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          bodyColor.withValues(alpha: isDark ? 0.96 : 0.88),
          bodyColor,
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    final bodyRadius = w * 0.35;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + h * 0.04),
        width: bodyRadius * 2,
        height: bodyRadius * 1.88,
      ),
      bodyPaint,
    );

    // 肚皮暖白绒毛
    final bellyPaint = Paint()
      ..color = const Color(0xFFFFFCF7).withValues(alpha: isDark ? 0.22 : 0.55);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + h * 0.12),
        width: bodyRadius * 1.28,
        height: bodyRadius * 1.06,
      ),
      bellyPaint,
    );

    // 3. 头顶音符呆毛羽冠
    final crestPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;
    final crestBase = Offset(center.dx, center.dy - bodyRadius * 0.86);
    final crestPath = Path()
      ..moveTo(crestBase.dx - w * 0.03, crestBase.dy)
      ..quadraticBezierTo(
        crestBase.dx - w * 0.05 + (animProgress * 3),
        crestBase.dy - h * 0.16,
        crestBase.dx + w * 0.05,
        crestBase.dy - h * 0.18,
      )
      ..quadraticBezierTo(
        crestBase.dx + w * 0.03,
        crestBase.dy - h * 0.08,
        crestBase.dx + w * 0.06,
        crestBase.dy,
      )
      ..close();
    canvas.drawPath(crestPath, crestPaint);
    canvas.drawCircle(
      Offset(crestBase.dx + w * 0.05, crestBase.dy - h * 0.18),
      w * 0.04,
      crestPaint,
    );

    // 4. 小翅膀
    final wingPaint = Paint()
      ..color = bodyColor.withValues(alpha: isDark ? 0.82 : 0.92);
    final wingAngle = 0.22 + animProgress * 0.24;

    canvas.save();
    canvas.translate(center.dx - bodyRadius * 0.86, center.dy + h * 0.05);
    canvas.rotate(wingAngle);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: w * 0.17, height: h * 0.25),
      wingPaint,
    );
    canvas.restore();

    canvas.save();
    canvas.translate(center.dx + bodyRadius * 0.86, center.dy + h * 0.05);
    canvas.rotate(-wingAngle);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: w * 0.17, height: h * 0.25),
      wingPaint,
    );
    canvas.restore();

    // 5. 面部表情
    _drawFace(canvas, size, center, bodyRadius);

    // 6. 状态专属装饰
    if (mood == ChumingMood.listening) {
      _drawHeadphones(canvas, size, center, bodyRadius);
    } else if (mood == ChumingMood.celebrating) {
      _drawCrownAndStars(canvas, size, center, bodyRadius);
    } else if (mood == ChumingMood.blowing) {
      _drawBreathBubbles(canvas, size, center, isUp: true);
    } else if (mood == ChumingMood.drawing) {
      _drawBreathBubbles(canvas, size, center, isUp: false);
    }
  }

  void _drawFace(Canvas canvas, Size size, Offset center, double bodyRadius) {
    final w = size.width;
    final h = size.height;

    // 粉嫩腮红
    final blushPaint = Paint()
      ..color = const Color(0xFFFF85A1).withValues(alpha: 0.5);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx - w * 0.17, center.dy + h * 0.05),
        width: w * 0.10,
        height: h * 0.06,
      ),
      blushPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx + w * 0.17, center.dy + h * 0.05),
        width: w * 0.10,
        height: h * 0.06,
      ),
      blushPaint,
    );

    final leftEyeCenter = Offset(center.dx - w * 0.115, center.dy - h * 0.015);
    final rightEyeCenter = Offset(center.dx + w * 0.115, center.dy - h * 0.015);
    final eyeRadius = w * 0.044;

    if (mood == ChumingMood.celebrating) {
      final happyEyePaint = Paint()
        ..color = const Color(0xFF1E212B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.032
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: leftEyeCenter, radius: eyeRadius),
        math.pi * 1.1,
        math.pi * 0.8,
        false,
        happyEyePaint,
      );
      canvas.drawArc(
        Rect.fromCircle(center: rightEyeCenter, radius: eyeRadius),
        math.pi * 1.1,
        math.pi * 0.8,
        false,
        happyEyePaint,
      );
    } else {
      final eyePaint = Paint()..color = const Color(0xFF1E212B);
      final highlightPaint = Paint()..color = Colors.white;
      canvas.drawCircle(leftEyeCenter, eyeRadius, eyePaint);
      canvas.drawCircle(rightEyeCenter, eyeRadius, eyePaint);
      canvas.drawCircle(
        Offset(leftEyeCenter.dx - eyeRadius * 0.3, leftEyeCenter.dy - eyeRadius * 0.3),
        eyeRadius * 0.36,
        highlightPaint,
      );
      canvas.drawCircle(
        Offset(rightEyeCenter.dx - eyeRadius * 0.3, rightEyeCenter.dy - eyeRadius * 0.3),
        eyeRadius * 0.36,
        highlightPaint,
      );
    }

    // 鹅黄小鸟喙
    final beakPaint = Paint()..color = const Color(0xFFFFB834);
    final beakY = center.dy + h * 0.018;
    final beakPath = Path()
      ..moveTo(center.dx - w * 0.055, beakY)
      ..lineTo(center.dx + w * 0.055, beakY)
      ..lineTo(center.dx, beakY + h * 0.075)
      ..close();
    canvas.drawPath(beakPath, beakPaint);
  }

  void _drawHeadphones(
    Canvas canvas,
    Size size,
    Offset center,
    double bodyRadius,
  ) {
    final w = size.width;
    final h = size.height;
    final bandPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.048
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy - h * 0.06),
        width: bodyRadius * 2.04,
        height: bodyRadius * 1.72,
      ),
      math.pi * 1.1,
      math.pi * 0.8,
      false,
      bandPaint,
    );

    final muffPaint = Paint()..color = accentColor;
    for (final sign in [-1.0, 1.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(center.dx + sign * bodyRadius * 0.96, center.dy - h * 0.01),
            width: w * 0.088,
            height: h * 0.15,
          ),
          const Radius.circular(6),
        ),
        muffPaint,
      );
    }
  }

  void _drawCrownAndStars(
    Canvas canvas,
    Size size,
    Offset center,
    double bodyRadius,
  ) {
    final w = size.width;
    final h = size.height;
    final crownPaint = Paint()..color = const Color(0xFFFFD043);
    final cx = center.dx;
    final cy = center.dy - bodyRadius * 0.90;
    final crownPath = Path()
      ..moveTo(cx - w * 0.09, cy)
      ..lineTo(cx - w * 0.11, cy - h * 0.09)
      ..lineTo(cx - w * 0.045, cy - h * 0.045)
      ..lineTo(cx, cy - h * 0.115)
      ..lineTo(cx + w * 0.045, cy - h * 0.045)
      ..lineTo(cx + w * 0.11, cy - h * 0.09)
      ..lineTo(cx + w * 0.09, cy)
      ..close();
    canvas.drawPath(crownPath, crownPaint);

    final starPaint = Paint()..color = accentColor.withValues(alpha: 0.85);
    canvas.drawCircle(
      Offset(cx + w * 0.28, cy - h * 0.04 - animProgress * 3),
      w * 0.028,
      starPaint,
    );
    canvas.drawCircle(
      Offset(cx - w * 0.28, cy + h * 0.01 - animProgress * 2),
      w * 0.024,
      starPaint,
    );
  }

  void _drawBreathBubbles(
    Canvas canvas,
    Size size,
    Offset center, {
    required bool isUp,
  }) {
    final w = size.width;
    final h = size.height;
    final bubblePaint = Paint()
      ..color = (isUp ? const Color(0xFF5B9BD1) : const Color(0xFFD48A62))
          .withValues(alpha: 0.65);

    final dir = isUp ? -1.0 : 1.0;
    final shift = animProgress * 6 * dir;
    canvas.drawCircle(
      Offset(center.dx + w * 0.12, center.dy + h * 0.11 + shift),
      w * 0.032,
      bubblePaint,
    );
    canvas.drawCircle(
      Offset(center.dx - w * 0.11, center.dy + h * 0.13 + shift * 1.2),
      w * 0.024,
      bubblePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ChumingBirdPainter oldDelegate) {
    return oldDelegate.mood != mood ||
        oldDelegate.animProgress != animProgress ||
        oldDelegate.bodyColor != bodyColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.isDark != isDark;
  }
}

/// 连续打卡萌趣火苗胶囊 (Streak Pill Badge)
class CuteStreakBadge extends StatelessWidget {
  const CuteStreakBadge({
    super.key,
    required this.streakDays,
    required this.label,
  });

  final int streakDays;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: palette.accent.withValues(alpha: 0.28),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_fire_department_rounded,
              size: 15,
              color: palette.accent,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: palette.accentInk,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
