import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../localization/app_strings.dart';
import '../services/haptics.dart';
import '../services/share_service.dart';
import '../state/app_controller.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';
import '../theme/app_adaptive.dart';
import 'cute_illustrations.dart';

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: context.colors.accentInk,
        fontSize: 11,
        height: 1.8,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill({
    required this.label,
    super.key,
    this.icon,
    this.color,
    this.foreground,
  });

  final String label;
  final IconData? icon;
  final Color? color;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final resolvedForeground = foreground ?? palette.text;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? palette.surfaceHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: resolvedForeground),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: resolvedForeground,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.detail,
    super.key,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String detail;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                const ChumingBird(
                  size: 68,
                  mood: ChumingMood.listening,
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: palette.surfaceHigh,
                    shape: BoxShape.circle,
                    border: Border.all(color: palette.outline),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: Icon(icon, size: 16, color: palette.accent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class PrivacyNote extends StatelessWidget {
  const PrivacyNote({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.lock_outline_rounded,
          size: 17,
          color: context.colors.success,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            context.strings.t('privacyNote'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class HarmonicaDiagram extends StatefulWidget {
  const HarmonicaDiagram({
    required this.activeTab,
    this.onHoleTap,
    super.key,
  });

  final String? activeTab;
  final ValueChanged<int>? onHoleTap;

  @override
  State<HarmonicaDiagram> createState() => _HarmonicaDiagramState();
}

class _HarmonicaDiagramState extends State<HarmonicaDiagram>
    with SingleTickerProviderStateMixin {
  int? _resonatingHole;
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  );

  @override
  void didUpdateWidget(covariant HarmonicaDiagram oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeTab != widget.activeTab && widget.activeTab != null) {
      final nextHole = int.tryParse(
        widget.activeTab!.replaceAll(RegExp(r'[^0-9]'), ''),
      );
      if (nextHole != null) {
        _resonatingHole = nextHole;
        if (!AppMotion.isReduced(context)) {
          _pulseController.forward(from: 0);
        }
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _triggerHoleResonance(int hole) {
    unawaited(AppHaptics.reedResonance(context));
    widget.onHoleTap?.call(hole);
    if (!mounted) return;
    setState(() => _resonatingHole = hole);
    if (!AppMotion.isReduced(context)) {
      _pulseController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final compact = AppAdaptive.isCompact(context);
    final labelWidth = compact ? 18.0 : 34.0;
    final activeHole = widget.activeTab == null
        ? null
        : int.tryParse(widget.activeTab!.replaceAll(RegExp(r'[^0-9]'), ''));
    final isBlow = widget.activeTab?.contains('↑') ?? true;

    Widget directionLabel(String text) {
      if (!compact) {
        return Text(
          text,
          maxLines: 1,
          softWrap: false,
          style: Theme.of(context).textTheme.bodySmall,
        );
      }
      return Text(
        text.split(' ').first,
        maxLines: 1,
        softWrap: false,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    return Row(
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(minWidth: labelWidth),
          child: SizedBox(
            height: compact ? 74 : 84,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  directionLabel(context.strings.t('blow')),
                  directionLabel(context.strings.t('draw')),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: compact ? 74 : 84,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, _) {
                  final pulse = _pulseController.isAnimating
                      ? (1.0 - _pulseController.value)
                      : 0.0;
                  final activeHighlight = activeHole != null
                      ? (isBlow ? palette.primary : palette.accentInk)
                      : palette.primary;
                  final activeAccent = activeHole != null
                      ? AppPalette.holeColor(activeHole)
                      : palette.primary;
                  final sliderAlignmentX = activeHole != null
                      ? -1.0 + ((activeHole.clamp(1, 10) - 1) * (2.0 / 9.0))
                      : 0.0;

                  return Stack(
                    children: [
                      Row(
                        children: List.generate(10, (index) {
                          final hole = index + 1;
                          final active = activeHole == hole;
                          final resonating =
                              _resonatingHole == hole && pulse > 0.01;
                          final holeAccent = AppPalette.holeColor(hole);
                          final highlightColor = active
                              ? (isBlow ? palette.primary : palette.accentInk)
                              : holeAccent;
                          return Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _triggerHoleResonance(hole),
                              child: AnimatedContainer(
                                duration: AppMotion.duration(
                                  context,
                                  AppMotion.fast,
                                ),
                                curve: AppMotion.standardCurve,
                                decoration: BoxDecoration(
                                  color: resonating
                                      ? holeAccent.withValues(
                                          alpha: 0.18 * pulse + 0.06,
                                        )
                                      : active
                                      ? highlightColor.withValues(alpha: 0.09)
                                      : palette.surface,
                                  border: Border(
                                    left: BorderSide(
                                      color: palette.outline,
                                      width: 1,
                                    ),
                                    right: index == 9
                                        ? BorderSide(
                                            color: palette.outline,
                                            width: 1,
                                          )
                                        : BorderSide.none,
                                    top: BorderSide(
                                      color: palette.outline,
                                      width: 1,
                                    ),
                                    bottom: BorderSide(
                                      color: palette.outline,
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    AnimatedContainer(
                                      duration: AppMotion.duration(
                                        context,
                                        AppMotion.fast,
                                      ),
                                      height: active || resonating ? 4.5 : 2.5,
                                      color: holeAccent.withValues(
                                        alpha:
                                            active || resonating ? 0.98 : 0.45,
                                      ),
                                    ),
                                    Expanded(
                                      child: Center(
                                        child: AnimatedScale(
                                          scale: active
                                              ? 1.12 + pulse * 0.08
                                              : 1.0,
                                          duration: AppMotion.duration(
                                            context,
                                            AppMotion.fast,
                                          ),
                                          child: Text(
                                            '$hole',
                                            style: TextStyle(
                                              color: active || resonating
                                                  ? highlightColor
                                                  : palette.muted,
                                              fontSize: compact ? 10 : 11,
                                              fontWeight: active || resonating
                                                  ? FontWeight.w800
                                                  : FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Container(height: 1, color: palette.outline),
                                    Expanded(
                                      child: AnimatedSwitcher(
                                        duration: AppMotion.duration(
                                          context,
                                          AppMotion.fast,
                                        ),
                                        transitionBuilder: (child, animation) {
                                          return ScaleTransition(
                                            scale: animation,
                                            child: FadeTransition(
                                              opacity: animation,
                                              child: child,
                                            ),
                                          );
                                        },
                                        child: active
                                            ? Center(
                                                key: ValueKey(
                                                  'arrow_${hole}_$isBlow',
                                                ),
                                                child: Icon(
                                                  isBlow
                                                      ? Icons
                                                            .arrow_upward_rounded
                                                      : Icons
                                                            .arrow_downward_rounded,
                                                  color: highlightColor,
                                                  size: 15,
                                                ),
                                              )
                                            : resonating
                                            ? Center(
                                                key: ValueKey('res_$hole'),
                                                child: Icon(
                                                  Icons.graphic_eq_rounded,
                                                  color: holeAccent,
                                                  size: 13,
                                                ),
                                              )
                                            : const SizedBox.shrink(
                                                key: ValueKey('idle'),
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      if (activeHole != null)
                        IgnorePointer(
                          child: AnimatedAlign(
                            alignment: Alignment(sliderAlignmentX, 0),
                            duration: AppMotion.duration(
                              context,
                              AppMotion.base,
                            ),
                            curve: AppMotion.sheetCurve,
                            child: FractionallySizedBox(
                              widthFactor: 0.1,
                              heightFactor: 1.0,
                              child: AnimatedContainer(
                                duration: AppMotion.duration(
                                  context,
                                  AppMotion.fast,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: activeHighlight,
                                    width: 2.2,
                                  ),
                                  color: activeAccent.withValues(
                                    alpha: 0.10 * pulse,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class BeatPulseBadge extends StatelessWidget {
  const BeatPulseBadge({
    required this.speed,
    required this.listening,
    this.beatStep = 0,
    super.key,
  });

  final double speed;
  final bool listening;
  final int beatStep;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final bpm = (speed * 76).round();
    final isDownbeat = beatStep.isEven;
    final activeColor = listening ? palette.success : palette.primary;

    return Container(
      key: const Key('bpm-pulse-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: activeColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: activeColor.withValues(alpha: isDownbeat ? 0.36 : 0.20),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: AppMotion.duration(context, AppMotion.fast),
            width: isDownbeat ? 8 : 6,
            height: isDownbeat ? 8 : 6,
            decoration: BoxDecoration(
              color: activeColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              context.strings.t('bpmPulseLabel', {'bpm': bpm}),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: activeColor,
                fontSize: 11,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showAchievementCardSheet(
  BuildContext context, {
  required String title,
  required int score,
  String? iconId,
  String? songId,
  String? tabPreview,
  String? grade,
  int? stars,
}) async {
  final controller = AppScope.read(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final posterKey = GlobalKey();
  unawaited(AppHaptics.reedResonance(context));
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    sheetAnimationStyle: AppMotion.sheetAnimationStyle(context),
    builder: (sheetContext) {
      final palette = sheetContext.colors;
      final strings = sheetContext.strings;
      final days = controller.streakDays == 0 ? 1 : controller.streakDays;
      final shareText = strings.t('achievementShareTemplate', {
        'title': title,
        'score': score,
        'key': controller.harmonicaKey,
        'days': days,
      });

      Future<void> sharePosterImage() async {
        Uint8List? pngBytes;
        try {
          final boundary =
              posterKey.currentContext?.findRenderObject()
                  as RenderRepaintBoundary?;
          if (boundary != null) {
            final image = await boundary.toImage(pixelRatio: 3.0);
            try {
              final byteData = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              pngBytes = byteData?.buffer.asUint8List();
            } finally {
              image.dispose();
            }
          }
        } catch (_) {
          pngBytes = null;
        }

        final shared = pngBytes != null && pngBytes.isNotEmpty
            ? await const ShareService().sharePngImage(
                bytes: pngBytes,
                fileName: 'breathnote_${songId ?? 'achievement'}.png',
                text: shareText,
                subject: strings.t('achievementShareSubject'),
              )
            : false;

        if (shared) {
          if (!sheetContext.mounted) return;
          unawaited(AppHaptics.success(sheetContext));
          Navigator.of(sheetContext).pop();
          return;
        }

        await Clipboard.setData(ClipboardData(text: shareText));
        if (!sheetContext.mounted) return;
        unawaited(AppHaptics.selection(sheetContext));
        Navigator.of(sheetContext).pop();
        messenger?.showSnackBar(
          SnackBar(
            content: Text(strings.t('achievementImageShareUnavailable')),
          ),
        );
      }

      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RepaintBoundary(
                key: posterKey,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: palette.background,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Container(
                    key: const Key('achievement-poster-card'),
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: palette.background,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          palette.primary.withValues(alpha: 0.14),
                          palette.surface,
                          palette.accent.withValues(alpha: 0.10),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: palette.primary.withValues(alpha: 0.30),
                        width: 1.4,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const HarmonicaBrandIcon(size: 22),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    strings.t('achievementCardTitle'),
                                    style: Theme.of(sheetContext)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  Text(
                                    strings.t('achievementCardSubtitle'),
                                    style: Theme.of(sheetContext)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: palette.primary.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                strings.t('keyName', {
                                  'key': controller.harmonicaKey,
                                }),
                                style: TextStyle(
                                  color: palette.primary,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const ChumingBird(
                              size: 68,
                              mood: ChumingMood.celebrating,
                            ),
                            if (iconId != null) ...[
                              const SizedBox(width: 14),
                              SongArtworkBadge(
                                iconId: iconId,
                                songId: songId ?? '',
                                size: 56,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: Theme.of(sheetContext).textTheme.headlineSmall,
                        ),
                        if (stars != null ||
                            (grade != null && grade.isNotEmpty)) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              if (stars != null)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: List.generate(3, (index) {
                                    final earned = index < stars;
                                    return Icon(
                                      earned
                                          ? Icons.star_rounded
                                          : Icons.star_outline_rounded,
                                      size: 18,
                                      color: earned
                                          ? const Color(0xFFF59E0B)
                                          : palette.outline,
                                    );
                                  }),
                                ),
                              if (grade != null && grade.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: palette.primary.withValues(
                                      alpha: 0.14,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    strings.t('scoreGradeLabel', {
                                      'grade': grade,
                                    }),
                                    style: TextStyle(
                                      color: palette.primary,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                        if (tabPreview != null && tabPreview.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: palette.surfaceHigh,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              tabPreview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.primary,
                                fontFamily: 'monospace',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: palette.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: palette.outline),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Flexible(
                                child: Column(
                                  children: [
                                    Text(
                                      '$score',
                                      style: TextStyle(
                                        color: palette.primary,
                                        fontFamily: 'monospace',
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      strings.t('runScoreLabel'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(sheetContext)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 28,
                                color: palette.outline,
                              ),
                              Flexible(
                                child: Column(
                                  children: [
                                    Text(
                                      strings.t('commonDays', {'count': days}),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: palette.text,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      strings.t('practiceDays'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(sheetContext)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('copy-achievement-text'),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: shareText));
                        if (!sheetContext.mounted) return;
                        unawaited(AppHaptics.success(sheetContext));
                        Navigator.of(sheetContext).pop();
                        messenger?.showSnackBar(
                          SnackBar(
                            content: Text(strings.t('achievementCopied')),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 17),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(strings.t('copyAchievementTextShort')),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('share-achievement-image'),
                      onPressed: sharePosterImage,
                      icon: const Icon(Icons.image_outlined, size: 17),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(strings.t('shareAchievementImage')),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
