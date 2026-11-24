import 'dart:async';

import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../services/haptics.dart';
import '../services/purchase_service.dart';
import '../state/app_controller.dart';
import '../theme/app_adaptive.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';
import 'cute_illustrations.dart';

/// 一次性永久买断（早鸟特惠 + 恢复购买）权益弹窗。
/// 返回 `true` 表示用户在弹窗内成功完成购买或恢复购买。
Future<bool> showProPaywallSheet(BuildContext context) async {
  unawaited(AppHaptics.selection(context));
  final unlocked = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    sheetAnimationStyle: AppMotion.sheetAnimationStyle(context),
    builder: (sheetContext) => const _ProPaywallSheetBody(),
  );
  return unlocked == true;
}

class _ProPaywallSheetBody extends StatefulWidget {
  const _ProPaywallSheetBody();

  @override
  State<_ProPaywallSheetBody> createState() => _ProPaywallSheetBodyState();
}

class _ProPaywallSheetBodyState extends State<_ProPaywallSheetBody> {
  bool _busy = false;
  String? _feedback;
  bool _feedbackPositive = false;

  Future<void> _buyPro() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _feedback = null;
    });
    final controller = AppScope.read(context);
    final result = await controller.purchasePro();
    if (!mounted) return;
    if (result.unlocked) {
      unawaited(AppHaptics.success(context));
      if (mounted) Navigator.of(context).pop(true);
      return;
    }
    final strings = context.strings;
    setState(() {
      _busy = false;
      _feedbackPositive = false;
      _feedback = switch (result.status) {
        PurchaseStatus.cancelled => null,
        PurchaseStatus.unavailable => strings.t('proStoreUnavailable'),
        _ => result.message ?? strings.t('proStoreUnavailable'),
      };
    });
  }

  Future<void> _restorePro() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _feedback = null;
    });
    final controller = AppScope.read(context);
    final result = await controller.restorePro();
    if (!mounted) return;
    if (result.unlocked) {
      unawaited(AppHaptics.success(context));
      if (mounted) Navigator.of(context).pop(true);
      return;
    }
    final strings = context.strings;
    setState(() {
      _busy = false;
      _feedbackPositive = false;
      _feedback = switch (result.status) {
        PurchaseStatus.notFound => strings.t('proRestoreEmpty'),
        PurchaseStatus.unavailable => strings.t('proStoreUnavailable'),
        _ => result.message ?? strings.t('proRestoreEmpty'),
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final palette = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final pagePadding = AppAdaptive.pagePadding(context);

    final benefits = [
      strings.t('proBenefit1'),
      strings.t('proBenefit2'),
      strings.t('proBenefit3'),
      strings.t('proBenefit4'),
    ];

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(pagePadding, 8, pagePadding, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Early-bird badge + bird mascot
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: palette.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const ChumingBird(
                    size: 40,
                    mood: ChumingMood.celebrating,
                    interactive: false,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: palette.accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          strings.t('proEarlyBirdBadge'),
                          style: textTheme.labelSmall?.copyWith(
                            color: palette.accent,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        strings.t('proTitle'),
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              strings.t('proSubtitle'),
              style: textTheme.bodySmall?.copyWith(
                color: palette.muted,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),

            // Price anchor card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: palette.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: palette.primary.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 6,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.t('proOneTimeLabel'),
                        style: textTheme.titleSmall?.copyWith(
                          color: palette.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        strings.t('proOriginalPrice'),
                        style: textTheme.bodySmall?.copyWith(
                          color: palette.muted,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    strings.t('proEarlyBirdPrice'),
                    style: textTheme.headlineMedium?.copyWith(
                      color: palette.primary,
                      fontWeight: FontWeight.w900,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Benefit bullets
            for (final benefit in benefits)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: palette.success,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        benefit,
                        style: textTheme.bodyMedium?.copyWith(height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),

            if (_feedback != null) ...[
              const SizedBox(height: 4),
              Container(
                key: const Key('paywall-feedback'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: (_feedbackPositive ? palette.success : palette.warning)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _feedback!,
                  style: textTheme.bodySmall?.copyWith(
                    color: palette.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],

            const SizedBox(height: 6),
            FilledButton(
              key: const Key('paywall-buy-pro'),
              onPressed: _busy ? null : _buyPro,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : Text(strings.t('proBuyButton')),
            ),
            const SizedBox(height: 8),
            TextButton(
              key: const Key('paywall-restore'),
              onPressed: _busy ? null : _restorePro,
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
              ),
              child: Text(strings.t('proRestoreButton')),
            ),
            const SizedBox(height: 4),
            Text(
              strings.t('proFooterLegal'),
              textAlign: TextAlign.center,
              style: textTheme.labelSmall?.copyWith(
                color: palette.muted,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
