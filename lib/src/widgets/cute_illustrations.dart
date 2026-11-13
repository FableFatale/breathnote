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

/// 定制对称无角口琴品牌图标（清晰呈现上下护板与音孔阵列，绝不形似文件夹或带角造型）
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
        accentColor: accentColor ?? const Color(0xFF15B462),
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

    final platePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // 1. 上下对称金属护板（轻微内收阶梯）
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(w * 0.14, h * 0.22, w * 0.86, h * 0.34),
        Radius.circular(w * 0.05),
      ),
      platePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(w * 0.14, h * 0.66, w * 0.86, h * 0.78),
        Radius.circular(w * 0.05),
      ),
      platePaint,
    );

    // 2. 中部宽体琴格轮廓（带边框与 5 个独立音孔）
    final combBorderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, w * 0.075);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(w * 0.06, h * 0.34, w * 0.94, h * 0.66),
        Radius.circular(w * 0.09),
      ),
      combBorderPaint,
    );

    // 3. 琴孔隔断与第 4 孔主音高亮
    final dividerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final highlightPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;

    // 高亮第 2 格（代表口琴第 4 孔初鸣主音）
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(w * 0.25, h * 0.39, w * 0.41, h * 0.61),
        Radius.circular(w * 0.04),
      ),
      highlightPaint,
    );

    // 4 条清晰孔位分隔柱，形成 5 个分明音孔
    for (final xRatio in [0.23, 0.41, 0.59, 0.77]) {
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(w * xRatio, h * 0.50),
          width: math.max(1.3, w * 0.055),
          height: h * 0.30,
        ),
        dividerPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HarmonicaBrandIconPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.accentColor != accentColor;
  }
}

/// 初鸣吉祥物小鸟（Palermo 清新亮色系圆润蓝白小肥啾，首次自动播放一次动画，点击可多次重播）
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
            bodyColor: widget.primaryColor ?? const Color(0xFF4785FF),
            accentColor: widget.accentColor ?? const Color(0xFFFF8B1A),
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
    final center = Offset(w / 2, h * 0.52 - (animProgress * h * 0.04));
    final bodyRadius = w * 0.36;

    // 1. 底部柔和椭圆投影
    final shadowPaint = Paint()
      ..color = const Color(0xFF376CFF).withValues(alpha: isDark ? 0.22 : 0.10);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, h * 0.90),
        width: w * (0.56 - animProgress * 0.06),
        height: h * 0.10,
      ),
      shadowPaint,
    );

    // 2. 头顶两瓣柔和同色系羽毛呆毛（不再使用异色天线造型）
    final tuftPaint = Paint()
      ..color = const Color(0xFF5E9BFF)
      ..style = PaintingStyle.fill;
    canvas.save();
    canvas.translate(center.dx, center.dy - bodyRadius * 0.88);
    canvas.rotate(-0.18 + animProgress * 0.12);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-w * 0.03, -h * 0.04),
        width: w * 0.11,
        height: h * 0.15,
      ),
      tuftPaint,
    );
    canvas.rotate(0.42);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.03, -h * 0.03),
        width: w * 0.09,
        height: h * 0.12,
      ),
      tuftPaint,
    );
    canvas.restore();

    // 3. 圆润晴空蓝小肥啾身体（清新亮蓝色渐变）
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF68A4FF),
          bodyColor,
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center,
          width: bodyRadius * 2.04,
          height: bodyRadius * 1.92,
        ),
        Radius.circular(bodyRadius * 0.96),
      ),
      bodyPaint,
    );

    // 4. 大面积雪白脸颊与肚皮面罩（类似银喉长尾山雀/企鹅幼崽的萌系比例）
    final faceMaskPaint = Paint()..color = const Color(0xFFFFFFFF);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(center.dx, center.dy + h * 0.05),
          width: bodyRadius * 1.62,
          height: bodyRadius * 1.44,
        ),
        Radius.circular(bodyRadius * 0.72),
      ),
      faceMaskPaint,
    );

    // 5. 两侧灵动小翅膀
    final wingPaint = Paint()..color = const Color(0xFF376CFF);
    final wingFlap = 0.20 + animProgress * 0.25;

    canvas.save();
    canvas.translate(center.dx - bodyRadius * 0.90, center.dy + h * 0.04);
    canvas.rotate(wingFlap);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: w * 0.15, height: h * 0.24),
        Radius.circular(w * 0.08),
      ),
      wingPaint,
    );
    canvas.restore();

    canvas.save();
    canvas.translate(center.dx + bodyRadius * 0.90, center.dy + h * 0.04);
    canvas.rotate(-wingFlap);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: w * 0.15, height: h * 0.24),
        Radius.circular(w * 0.08),
      ),
      wingPaint,
    );
    canvas.restore();

    // 6. 可爱小脚丫
    final feetPaint = Paint()
      ..color = const Color(0xFFFF9F1C)
      ..strokeWidth = w * 0.045
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(center.dx - w * 0.12, center.dy + bodyRadius * 0.88),
      Offset(center.dx - w * 0.15, center.dy + bodyRadius * 0.98),
      feetPaint,
    );
    canvas.drawLine(
      Offset(center.dx + w * 0.12, center.dy + bodyRadius * 0.88),
      Offset(center.dx + w * 0.15, center.dy + bodyRadius * 0.98),
      feetPaint,
    );

    // 7. 面部五官
    _drawFace(canvas, size, center, bodyRadius);

    // 8. 情绪道具
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

    // 蜜桃粉腮红
    final blushPaint = Paint()
      ..color = const Color(0xFFFF7EB6).withValues(alpha: 0.45);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx - w * 0.18, center.dy + h * 0.05),
        width: w * 0.11,
        height: h * 0.065,
      ),
      blushPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx + w * 0.18, center.dy + h * 0.05),
        width: w * 0.11,
        height: h * 0.065,
      ),
      blushPaint,
    );

    final leftEyeCenter = Offset(center.dx - w * 0.13, center.dy - h * 0.01);
    final rightEyeCenter = Offset(center.dx + w * 0.13, center.dy - h * 0.01);
    final eyeRadius = w * 0.052;

    if (mood == ChumingMood.celebrating) {
      final happyEyePaint = Paint()
        ..color = const Color(0xFF18181A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.036
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: leftEyeCenter, radius: eyeRadius),
        math.pi * 1.12,
        math.pi * 0.76,
        false,
        happyEyePaint,
      );
      canvas.drawArc(
        Rect.fromCircle(center: rightEyeCenter, radius: eyeRadius),
        math.pi * 1.12,
        math.pi * 0.76,
        false,
        happyEyePaint,
      );
    } else {
      final eyePaint = Paint()..color = const Color(0xFF18181A);
      final highlightPaint = Paint()..color = Colors.white;
      canvas.drawCircle(leftEyeCenter, eyeRadius, eyePaint);
      canvas.drawCircle(rightEyeCenter, eyeRadius, eyePaint);
      // 双眼神高光点
      canvas.drawCircle(
        Offset(leftEyeCenter.dx - eyeRadius * 0.28, leftEyeCenter.dy - eyeRadius * 0.28),
        eyeRadius * 0.38,
        highlightPaint,
      );
      canvas.drawCircle(
        Offset(rightEyeCenter.dx - eyeRadius * 0.28, rightEyeCenter.dy - eyeRadius * 0.28),
        eyeRadius * 0.38,
        highlightPaint,
      );
    }

    // 圆润暖橘黄小鸟喙
    final beakPaint = Paint()..color = const Color(0xFFFF9F1C);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(center.dx, center.dy + h * 0.035),
          width: w * 0.11,
          height: h * 0.075,
        ),
        Radius.circular(w * 0.04),
      ),
      beakPaint,
    );
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
      ..color = const Color(0xFF18181A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.045
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy - h * 0.04),
        width: bodyRadius * 2.08,
        height: bodyRadius * 1.82,
      ),
      math.pi * 1.12,
      math.pi * 0.76,
      false,
      bandPaint,
    );

    final muffPaint = Paint()..color = accentColor;
    for (final sign in [-1.0, 1.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(center.dx + sign * bodyRadius * 0.98, center.dy),
            width: w * 0.09,
            height: h * 0.16,
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
    final starPaint = Paint()..color = const Color(0xFFF99C00);
    canvas.drawCircle(
      Offset(center.dx + w * 0.32, center.dy - bodyRadius * 0.75 - animProgress * 3),
      w * 0.032,
      starPaint,
    );
    canvas.drawCircle(
      Offset(center.dx - w * 0.32, center.dy - bodyRadius * 0.65 - animProgress * 2),
      w * 0.026,
       Paint()..color = const Color(0xFF15B462),
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
      ..color = (isUp ? const Color(0xFF376CFF) : const Color(0xFFFE6E00))
          .withValues(alpha: 0.70);

    final dir = isUp ? -1.0 : 1.0;
    final shift = animProgress * 6 * dir;
    canvas.drawCircle(
      Offset(center.dx + w * 0.14, center.dy + h * 0.12 + shift),
      w * 0.032,
      bubblePaint,
    );
    canvas.drawCircle(
      Offset(center.dx - w * 0.12, center.dy + h * 0.14 + shift * 1.2),
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

/// 连续打卡萌趣火苗胶囊 (Palermo Semantic Orange Pill Badge)
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PalermoTokens.orangeLight.mutedFill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: PalermoTokens.orangeLight.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.local_fire_department_rounded,
              size: 15,
              color: Color(0xFFFE6E00),
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
                  color: PalermoTokens.orangeLight.emphasis,
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
