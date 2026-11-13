import 'dart:async';

import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../services/haptics.dart';
import '../state/app_controller.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';
import 'cute_illustrations.dart';

/// 初鸣小老师 (Chuming Bird Coach) 首次进入功能引导气泡卡片
/// - 首次进入某个功能模块时自动展示简短使用说明
/// - 用户点击「知道了」或关闭按钮后收起并持久化记录
/// - 用户随时点击页面上的初鸣小鸟可再次唤出引导
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
              child: Container(
                key: Key('coach-banner-$featureId'),
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                decoration: BoxDecoration(
                  color: blueTokens.mutedFill,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: blueTokens.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ChumingBird(
                      size: 36,
                      mood: mood,
                      interactive: false,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.auto_awesome_rounded,
                                size: 12,
                                color: blueTokens.base,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  strings.t('coachBadge'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: blueTokens.emphasis,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            strings.t(messageKey),
                            style: TextStyle(
                              color: palette.text,
                              fontSize: 12.5,
                              height: 1.35,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton(
                      key: Key('coach-dismiss-$featureId'),
                      onPressed: () {
                        unawaited(AppHaptics.selection(context));
                        unawaited(controller.dismissCoachTip(featureId));
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: blueTokens.emphasis,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: const Size(40, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: Text(strings.t('coachGotIt')),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
