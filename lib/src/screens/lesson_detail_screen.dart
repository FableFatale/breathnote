import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../services/haptics.dart';
import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class LessonDetailScreen extends StatelessWidget {
  const LessonDetailScreen({super.key});

  Future<void> _complete(BuildContext context) async {
    await AppScope.of(context).markLessonComplete('lesson_1');
    if (!context.mounted) return;
    await AppHaptics.success(context);
    if (!context.mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Scaffold(
      appBar: AppBar(title: Text(context.strings.lessonTitle('lesson_1'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          SectionLabel(context.strings.t('lessonOneLabel')),
          const SizedBox(height: 8),
          Text(
            context.strings.t('lessonOneHero'),
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.strings.t('tenHoleHarmonica'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  const HarmonicaDiagram(activeTab: null),
                  const SizedBox(height: 14),
                  Text(
                    context.strings.t('harmonicaIntro'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _Instruction(
            number: '1',
            title: context.strings.t('holdNaturally'),
            detail: context.strings.t('holdNaturallyDetail'),
            color: palette.primary,
          ),
          Divider(height: 1, color: palette.outline),
          _Instruction(
            number: '2',
            title: context.strings.t('relaxLips'),
            detail: context.strings.t('relaxLipsDetail'),
            color: palette.primary,
          ),
          Divider(height: 1, color: palette.outline),
          _Instruction(
            number: '3',
            title: context.strings.t('bellyBreathing'),
            detail: context.strings.t('bellyBreathingDetail'),
            color: palette.primary,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _complete(context),
              icon: const Icon(Icons.check_rounded),
              label: Text(context.strings.t('completeLesson')),
            ),
          ),
        ],
      ),
    );
  }
}

class _Instruction extends StatelessWidget {
  const _Instruction({
    required this.number,
    required this.title,
    required this.detail,
    required this.color,
  });

  final String number;
  final String title;
  final String detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              number,
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(detail, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
