import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

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
            '练习声音只在设备本地处理，不会上传或保存。',
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
    final activeHole = activeTab == null
        ? null
        : int.tryParse(activeTab!.replaceAll(RegExp(r'[^0-9]'), ''));
    final isBlow = activeTab?.contains('↑') ?? true;

    return Column(
      children: [
        Row(
          children: [
            SizedBox(
              width: 30,
              child: Text('吹 ↑', style: Theme.of(context).textTheme.bodySmall),
            ),
            Expanded(
              child: Row(
                children: List.generate(10, (index) {
                  final hole = index + 1;
                  final active = activeHole == hole && isBlow;
                  return Expanded(
                    child: Container(
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: active
                            ? palette.primary.withValues(alpha: 0.12)
                            : palette.surface,
                        border: Border.all(
                          color: active ? palette.primary : palette.outline,
                          width: active ? 2 : 1,
                        ),
                      ),
                      child: Text(
                        '$hole',
                        style: TextStyle(
                          color: active ? palette.primary : palette.muted,
                          fontSize: 11,
                          fontWeight: active
                              ? FontWeight.w800
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
        Row(
          children: [
            SizedBox(
              width: 30,
              child: Text('吸 ↓', style: Theme.of(context).textTheme.bodySmall),
            ),
            Expanded(
              child: Row(
                children: List.generate(10, (index) {
                  final hole = index + 1;
                  final active = activeHole == hole && !isBlow;
                  return Expanded(
                    child: Container(
                      height: 18,
                      decoration: BoxDecoration(
                        color: active
                            ? palette.primary.withValues(alpha: 0.12)
                            : palette.surface,
                        border: Border(
                          left: BorderSide(
                            color: active ? palette.primary : palette.outline,
                            width: active ? 2 : 1,
                          ),
                          right: index == 9
                              ? BorderSide(
                                  color: active
                                      ? palette.primary
                                      : palette.outline,
                                  width: active ? 2 : 1,
                                )
                              : BorderSide.none,
                          bottom: BorderSide(
                            color: active ? palette.primary : palette.outline,
                            width: active ? 2 : 1,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
