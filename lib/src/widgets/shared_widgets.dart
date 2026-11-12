import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';
import '../theme/app_adaptive.dart';

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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: context.colors.accent),
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

class HarmonicaDiagram extends StatelessWidget {
  const HarmonicaDiagram({required this.activeTab, super.key});

  final String? activeTab;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final compact = AppAdaptive.isCompact(context);
    final labelWidth = compact ? 18.0 : 34.0;
    final activeHole = activeTab == null
        ? null
        : int.tryParse(activeTab!.replaceAll(RegExp(r'[^0-9]'), ''));
    final isBlow = activeTab?.contains('↑') ?? true;

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
              child: Row(
                children: List.generate(10, (index) {
                  final hole = index + 1;
                  final active = activeHole == hole;
                  return Expanded(
                    child: AnimatedContainer(
                      duration: AppMotion.duration(context, AppMotion.fast),
                      curve: AppMotion.standardCurve,
                      decoration: BoxDecoration(
                        color: active
                            ? palette.primary.withValues(alpha: 0.08)
                            : palette.surface,
                        border: Border(
                          left: BorderSide(
                            color: active ? palette.primary : palette.outline,
                            width: active ? 2 : 1,
                          ),
                          right: index == 9 || active
                              ? BorderSide(
                                  color: active
                                      ? palette.primary
                                      : palette.outline,
                                  width: active ? 2 : 1,
                                )
                              : BorderSide.none,
                          top: BorderSide(
                            color: active ? palette.primary : palette.outline,
                            width: active ? 2 : 1,
                          ),
                          bottom: BorderSide(
                            color: active ? palette.primary : palette.outline,
                            width: active ? 2 : 1,
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: Center(
                              child: Text(
                                '$hole',
                                style: TextStyle(
                                  color: active && isBlow
                                      ? palette.primary
                                      : palette.muted,
                                  fontSize: compact ? 10 : 11,
                                  fontWeight: active
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          Container(height: 1, color: palette.outline),
                          Expanded(
                            child: active && !isBlow
                                ? Center(
                                    child: Icon(
                                      Icons.arrow_downward_rounded,
                                      color: palette.primary,
                                      size: 14,
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
