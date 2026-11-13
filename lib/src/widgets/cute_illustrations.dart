import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/song.dart';
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

/// 曲谱专属高辨识度矢量徽标（内置 8 款主题图标：星夜、朝阳、萌虎、茉莉、弯月、篝火、海浪、黑胶）
class SongArtworkBadge extends StatelessWidget {
  const SongArtworkBadge({
    super.key,
    required this.iconId,
    this.songId = '',
    this.size = 52,
    this.showEditBadge = false,
    this.selected = false,
    this.onTap,
  });

  final String? iconId;
  final String songId;
  final double size;
  final bool showEditBadge;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final preset = songIconPresetById(iconId, songId: songId);
    final palette = context.colors;
    final radius = size * 0.27;

    Widget badge = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [preset.primaryColor, preset.secondaryColor],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: selected
            ? Border.all(color: palette.ink, width: 2.5)
            : Border.all(
                color: Colors.white.withValues(alpha: 0.18),
                width: 1,
              ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _SongArtworkPainter(iconId: preset.id),
            ),
          ),
          if (showEditBadge)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: palette.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: palette.outline, width: 1),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.palette_outlined,
                  size: 11,
                  color: palette.primary,
                ),
              ),
            ),
        ],
      ),
    );

    if (onTap == null) return badge;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: badge,
    );
  }
}

class _SongArtworkPainter extends CustomPainter {
  const _SongArtworkPainter({required this.iconId});

  final String iconId;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    switch (iconId) {
      case 'star':
        _paintStar(canvas, w, h);
      case 'sunburst':
        _paintSunburst(canvas, w, h);
      case 'tiger':
        _paintTiger(canvas, w, h);
      case 'flower':
        _paintFlower(canvas, w, h);
      case 'moon':
        _paintMoon(canvas, w, h);
      case 'campfire':
        _paintCampfire(canvas, w, h);
      case 'wave':
        _paintWave(canvas, w, h);
      case 'vinyl':
      default:
        _paintVinyl(canvas, w, h);
    }
  }

  /// 1. 星夜闪烁（小星星默认）：饱满四角主星 + 双伴星 + 星轨弧线
  void _paintStar(Canvas canvas, double w, double h) {
    // 底部柔和星轨弧
    final orbitPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.045
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromLTWH(w * 0.14, h * 0.42, w * 0.72, h * 0.42),
      0.15,
      math.pi - 0.30,
      false,
      orbitPaint,
    );

    // 主星（暖金黄四角星芒）
    _drawFourPointStar(
      canvas,
      center: Offset(w * 0.46, h * 0.48),
      outerRadius: w * 0.28,
      innerRadius: w * 0.10,
      color: const Color(0xFFFFD43B),
    );
    // 主星高光内核
    canvas.drawCircle(
      Offset(w * 0.46, h * 0.48),
      w * 0.06,
      Paint()..color = const Color(0xFFFFF9DB),
    );

    // 右上白亮伴星
    _drawFourPointStar(
      canvas,
      center: Offset(w * 0.74, h * 0.27),
      outerRadius: w * 0.11,
      innerRadius: w * 0.04,
      color: Colors.white,
    );
    // 左下薄荷星点
    canvas.drawCircle(
      Offset(w * 0.24, h * 0.30),
      w * 0.038,
      Paint()..color = const Color(0xFF8CE99A),
    );
  }

  /// 2. 朝阳礼赞（欢乐颂默认）：光芒日轮 + 双层圣歌音律波纹
  void _paintSunburst(Canvas canvas, double w, double h) {
    final center = Offset(w * 0.50, h * 0.54);

    // 放射光芒射线
    final rayPaint = Paint()
      ..color = const Color(0xFFFFE066)
      ..strokeWidth = w * 0.055
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 7; i++) {
      final angle = -math.pi + (i * math.pi / 6);
      final p1 = Offset(
        center.dx + math.cos(angle) * w * 0.22,
        center.dy + math.sin(angle) * h * 0.22,
      );
      final p2 = Offset(
        center.dx + math.cos(angle) * w * 0.33,
        center.dy + math.sin(angle) * h * 0.33,
      );
      canvas.drawLine(p1, p2, rayPaint);
    }

    // 暖白朝阳核心
    canvas.drawCircle(
      center,
      w * 0.16,
      Paint()..color = const Color(0xFFFFF4E6),
    );

    // 底部欢庆礼赞双弧线
    final wavePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.055
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(w * 0.20, h * 0.74),
      Offset(w * 0.80, h * 0.74),
      wavePaint,
    );
    canvas.drawLine(
      Offset(w * 0.30, h * 0.84),
      Offset(w * 0.70, h * 0.84),
      wavePaint..color = Colors.white.withValues(alpha: 0.75),
    );
  }

  /// 3. 萌虎童谣（两只老虎默认）：圆润小虎头 + 圆耳朵 + 额头「王」字纹
  void _paintTiger(Canvas canvas, double w, double h) {
    final earPaint = Paint()..color = const Color(0xFFFFAA2B);
    final innerEarPaint = Paint()..color = const Color(0xFFFFF0D6);

    // 左右圆耳朵
    canvas.drawCircle(Offset(w * 0.28, h * 0.30), w * 0.11, earPaint);
    canvas.drawCircle(Offset(w * 0.72, h * 0.30), w * 0.11, earPaint);
    canvas.drawCircle(Offset(w * 0.28, h * 0.30), w * 0.055, innerEarPaint);
    canvas.drawCircle(Offset(w * 0.72, h * 0.30), w * 0.055, innerEarPaint);

    // 虎头圆脸
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w * 0.50, h * 0.54),
          width: w * 0.56,
          height: h * 0.50,
        ),
        Radius.circular(w * 0.24),
      ),
      earPaint,
    );

    // 白色嘴周软萌下巴
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.50, h * 0.63),
        width: w * 0.34,
        height: h * 0.22,
      ),
      Paint()..color = Colors.white,
    );

    // 额头标志性「王」字虎纹
    final stripePaint = Paint()
      ..color = const Color(0xFF3B2314)
      ..strokeWidth = w * 0.042
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(w * 0.42, h * 0.36),
      Offset(w * 0.58, h * 0.36),
      stripePaint,
    );
    canvas.drawLine(
      Offset(w * 0.44, h * 0.43),
      Offset(w * 0.56, h * 0.43),
      stripePaint,
    );
    canvas.drawLine(
      Offset(w * 0.50, h * 0.34),
      Offset(w * 0.50, h * 0.45),
      stripePaint,
    );

    // 双眼与小粉鼻
    final eyePaint = Paint()..color = const Color(0xFF18181A);
    canvas.drawCircle(Offset(w * 0.39, h * 0.53), w * 0.038, eyePaint);
    canvas.drawCircle(Offset(w * 0.61, h * 0.53), w * 0.038, eyePaint);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.50, h * 0.59),
        width: w * 0.09,
        height: h * 0.06,
      ),
      Paint()..color = const Color(0xFFFF6B8B),
    );
  }

  /// 4. 清雅茉莉（茉莉花默认）：五瓣雪白花朵 + 暖金花蕊 + 翠绿叶片
  void _paintFlower(Canvas canvas, double w, double h) {
    final center = Offset(w * 0.48, h * 0.48);

    // 右下翠绿嫩叶
    canvas.save();
    canvas.translate(w * 0.66, h * 0.66);
    canvas.rotate(0.6);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: w * 0.22,
        height: h * 0.12,
      ),
      Paint()..color = const Color(0xFF63E6BE),
    );
    canvas.restore();

    // 五片饱满白色花瓣
    final petalPaint = Paint()..color = Colors.white;
    for (var i = 0; i < 5; i++) {
      final angle = -math.pi / 2 + (i * 2 * math.pi / 5);
      final petalCenter = Offset(
        center.dx + math.cos(angle) * w * 0.16,
        center.dy + math.sin(angle) * h * 0.16,
      );
      canvas.drawCircle(petalCenter, w * 0.125, petalPaint);
    }

    // 暖黄花蕊中心
    canvas.drawCircle(
      center,
      w * 0.095,
      Paint()..color = const Color(0xFFFCC419),
    );
  }

  /// 5. 弯月夜曲（内置可选）：金色弯月 + 柔云 + 伴星
  void _paintMoon(Canvas canvas, double w, double h) {
    final moonPath = Path()
      ..addOval(
        Rect.fromCircle(center: Offset(w * 0.48, h * 0.46), radius: w * 0.25),
      );
    final cutoutPath = Path()
      ..addOval(
        Rect.fromCircle(center: Offset(w * 0.58, h * 0.38), radius: w * 0.21),
      );
    final crescent = Path.combine(
      PathOperation.difference,
      moonPath,
      cutoutPath,
    );
    canvas.drawPath(crescent, Paint()..color = const Color(0xFFFFE066));

    // 右上伴星
    _drawFourPointStar(
      canvas,
      center: Offset(w * 0.68, h * 0.30),
      outerRadius: w * 0.08,
      innerRadius: w * 0.03,
      color: Colors.white,
    );

    // 底部轻柔云朵
    final cloudPaint = Paint()..color = Colors.white.withValues(alpha: 0.90);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.36, h * 0.64, w * 0.42, h * 0.14),
        Radius.circular(w * 0.07),
      ),
      cloudPaint,
    );
    canvas.drawCircle(Offset(w * 0.50, h * 0.63), w * 0.09, cloudPaint);
    canvas.drawCircle(Offset(w * 0.63, h * 0.65), w * 0.07, cloudPaint);
  }

  /// 6. 篝火民谣（内置可选）：跃动双色火苗 + 交叉木柴
  void _paintCampfire(Canvas canvas, double w, double h) {
    // 底部交叉木柴
    final logPaint = Paint()
      ..color = const Color(0xFFFFD8A8)
      ..strokeWidth = w * 0.075
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(w * 0.26, h * 0.76),
      Offset(w * 0.74, h * 0.68),
      logPaint,
    );
    canvas.drawLine(
      Offset(w * 0.26, h * 0.68),
      Offset(w * 0.74, h * 0.76),
      logPaint,
    );

    // 外焰（亮琥珀橘）
    final outerFlame = Path()
      ..moveTo(w * 0.50, h * 0.18)
      ..quadraticBezierTo(w * 0.76, h * 0.38, w * 0.66, h * 0.62)
      ..quadraticBezierTo(w * 0.50, h * 0.70, w * 0.34, h * 0.62)
      ..quadraticBezierTo(w * 0.24, h * 0.38, w * 0.50, h * 0.18)
      ..close();
    canvas.drawPath(outerFlame, Paint()..color = const Color(0xFFFFA94D));

    // 内焰（暖白金黄）
    final innerFlame = Path()
      ..moveTo(w * 0.50, h * 0.34)
      ..quadraticBezierTo(w * 0.64, h * 0.46, w * 0.58, h * 0.61)
      ..quadraticBezierTo(w * 0.50, h * 0.66, w * 0.42, h * 0.61)
      ..quadraticBezierTo(w * 0.36, h * 0.46, w * 0.50, h * 0.34)
      ..close();
    canvas.drawPath(innerFlame, Paint()..color = const Color(0xFFFFF3BF));
  }

  /// 7. 海风波浪（内置可选）：双层律动海浪 + 浪花泡沫
  void _paintWave(Canvas canvas, double w, double h) {
    final wave1 = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.075
      ..strokeCap = StrokeCap.round;
    final path1 = Path()
      ..moveTo(w * 0.18, h * 0.50)
      ..cubicTo(w * 0.34, h * 0.34, w * 0.46, h * 0.64, w * 0.62, h * 0.48)
      ..quadraticBezierTo(w * 0.72, h * 0.38, w * 0.82, h * 0.48);
    canvas.drawPath(path1, wave1);

    final wave2 = Paint()
      ..color = const Color(0xFF99E9F2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.065
      ..strokeCap = StrokeCap.round;
    final path2 = Path()
      ..moveTo(w * 0.22, h * 0.68)
      ..cubicTo(w * 0.38, h * 0.54, w * 0.50, h * 0.80, w * 0.66, h * 0.66)
      ..quadraticBezierTo(w * 0.74, h * 0.58, w * 0.80, h * 0.66);
    canvas.drawPath(path2, wave2);

    // 顶部跳跃水珠音符点
    canvas.drawCircle(
      Offset(w * 0.36, h * 0.28),
      w * 0.045,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(w * 0.62, h * 0.25),
      w * 0.032,
      Paint()..color = const Color(0xFF99E9F2),
    );
  }

  /// 8. 黑胶旋律（自定义默认 / 内置可选）：黑胶纹路 + 宝蓝盘心 + 亮白音符
  void _paintVinyl(Canvas canvas, double w, double h) {
    final center = Offset(w * 0.50, h * 0.50);

    // 唱片外圈反光沟槽弧
    final groovePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.035
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: w * 0.32),
      -math.pi * 0.75,
      math.pi * 0.45,
      false,
      groovePaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: w * 0.32),
      math.pi * 0.25,
      math.pi * 0.45,
      false,
      groovePaint,
    );

    // 宝蓝中心盘标
    canvas.drawCircle(
      center,
      w * 0.19,
      Paint()..color = const Color(0xFF376CFF),
    );

    // 中心八分音符
    final notePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = w * 0.05
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(w * 0.52, h * 0.38),
      Offset(w * 0.52, h * 0.56),
      notePaint,
    );
    canvas.drawLine(
      Offset(w * 0.52, h * 0.38),
      Offset(w * 0.61, h * 0.42),
      notePaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.47, h * 0.57),
        width: w * 0.12,
        height: h * 0.09,
      ),
      Paint()..color = Colors.white,
    );
  }

  void _drawFourPointStar(
    Canvas canvas, {
    required Offset center,
    required double outerRadius,
    required double innerRadius,
    required Color color,
  }) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final radius = i.isEven ? outerRadius : innerRadius;
      final angle = -math.pi / 2 + i * math.pi / 4;
      final pt = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SongArtworkPainter oldDelegate) {
    return oldDelegate.iconId != iconId;
  }
}
