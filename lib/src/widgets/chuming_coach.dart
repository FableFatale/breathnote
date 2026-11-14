import 'dart:async';

import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../services/haptics.dart';
import '../state/app_controller.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';
import 'cute_illustrations.dart';

/// 初鸣小老师 (Chuming Bird Coach) 品牌化首次进入引导卡片
class ChumingCoachBanner extends StatelessWidget {
  const ChumingCoachBanner({
    required this.featureId,
    required this.messageKey,
    this.mood = ChumingMood.idle,
    this.bottomSpacing = 14,
    super.key,
  });

  final String featureId;
  final String messageKey;
  final ChumingMood mood;
  final double bottomSpacing;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final dismissed = controller.seenCoachTips.contains(featureId);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final blueTokens = PalermoTokens.blue(isDark);
    final palette = context.colors;
    final strings = context.strings;

    return AnimatedSize(
      duration: AppMotion.duration(context, AppMotion.base),
      curve: AppMotion.standardCurve,
      alignment: Alignment.topCenter,
      child: dismissed
          ? const SizedBox.shrink()
          : Padding(
              padding: EdgeInsets.only(bottom: bottomSpacing),
              child: DecoratedBox(
                key: Key('coach-banner-$featureId'),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      blueTokens.mutedFill,
                      palette.surface,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: blueTokens.border),
                  boxShadow: [
                    BoxShadow(
                      color: palette.primary.withValues(
                        alpha: isDark ? 0.12 : 0.06,
                      ),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: CustomPaint(
                    painter: _CoachAcousticWatermarkPainter(
                      color: blueTokens.base.withValues(
                        alpha: isDark ? 0.10 : 0.07,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: palette.surface,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: blueTokens.border,
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: palette.primary.withValues(
                                    alpha: 0.10,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: ChumingBird(
                              size: 32,
                              mood: mood,
                              interactive: false,
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: blueTokens.base.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.auto_awesome_rounded,
                                        size: 11,
                                        color: blueTokens.base,
                                      ),
                                      const SizedBox(width: 3),
                                      Flexible(
                                        child: Text(
                                          strings.t('coachBadge'),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: blueTokens.emphasis,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  strings.t(messageKey),
                                  style: TextStyle(
                                    color: palette.text,
                                    fontSize: 12.5,
                                    height: 1.38,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          TextButton(
                            key: Key('coach-dismiss-$featureId'),
                            onPressed: () {
                              unawaited(AppHaptics.reedResonance(context));
                              unawaited(controller.dismissCoachTip(featureId));
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: blueTokens.emphasis,
                              backgroundColor: palette.surface.withValues(
                                alpha: isDark ? 0.55 : 0.85,
                              ),
                              side: BorderSide(color: blueTokens.border),
                              shape: const StadiumBorder(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 6,
                              ),
                              minimumSize: const Size(40, 32),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              textStyle: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            child: Text(strings.t('coachGotIt')),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _CoachAcousticWatermarkPainter extends CustomPainter {
  const _CoachAcousticWatermarkPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final center = Offset(size.width - 18, -8);
    for (final radius in [28.0, 44.0, 60.0]) {
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CoachAcousticWatermarkPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
