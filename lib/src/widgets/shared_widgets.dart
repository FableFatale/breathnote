import 'dart:async';

import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../services/haptics.dart';
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
    duration: const Duration(milliseconds: 300),
  );

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
            height: compact ? 76 : 88,
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
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: compact ? 76 : 88,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, _) {
                  final pulse = _pulseController.isAnimating
                      ? (1.0 - _pulseController.value)
                      : 0.0;
                  return Row(
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
                            duration:
                                AppMotion.duration(context, AppMotion.fast),
                            curve: AppMotion.standardCurve,
                            decoration: BoxDecoration(
                              color: resonating
                                  ? holeAccent.withValues(
                                      alpha: 0.16 * pulse + 0.06,
                                    )
                                  : active
                                  ? highlightColor.withValues(alpha: 0.08)
                                  : palette.surface,
                              border: Border(
                                left: BorderSide(
                                  color: active || resonating
                                      ? highlightColor
                                      : palette.outline,
                                  width: active || resonating ? 2 : 1,
                                ),
                                right: index == 9 || active || resonating
                                    ? BorderSide(
                                        color: active || resonating
                                            ? highlightColor
                                            : palette.outline,
                                        width: active || resonating ? 2 : 1,
                                      )
                                    : BorderSide.none,
                                top: BorderSide(
                                  color: active || resonating
                                      ? highlightColor
                                      : palette.outline,
                                  width: active || resonating ? 2 : 1,
                                ),
                                bottom: BorderSide(
                                  color: active || resonating
                                      ? highlightColor
                                      : palette.outline,
                                  width: active || resonating ? 2 : 1,
                                ),
                              ),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  height: active || resonating ? 4.5 : 2.5,
                                  color: holeAccent.withValues(
                                    alpha: active || resonating ? 0.98 : 0.45,
                                  ),
                                ),
                                Expanded(
                                  child: Center(
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
                                Container(height: 1, color: palette.outline),
                                Expanded(
                                  child: active
                                      ? Center(
                                          child: Icon(
                                            isBlow
                                                ? Icons.arrow_upward_rounded
                                                : Icons.arrow_downward_rounded,
                                            color: highlightColor,
                                            size: 14,
                                          ),
                                        )
                                      : resonating
                                      ? Center(
                                          child: Icon(
                                            Icons.graphic_eq_rounded,
                                            color: holeAccent,
                                            size: 13,
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
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
