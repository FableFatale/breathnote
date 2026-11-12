import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../services/haptics.dart';
import '../state/app_controller.dart';
import '../theme/app_motion.dart';
import '../theme/app_adaptive.dart';
import '../theme/app_theme.dart';
import '../widgets/harmonica_guide.dart' show showHarmonicaGuide;
import '../widgets/shared_widgets.dart';
import 'lesson_routes.dart';

class LessonDetailScreen extends StatefulWidget {
  const LessonDetailScreen({super.key});

  @override
  State<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen> {
  bool _completing = false;

  Future<void> _complete(BuildContext context) async {
    if (_completing) return;
    setState(() => _completing = true);
    await AppScope.of(context).markLessonComplete('lesson_1');
    if (!context.mounted) return;
    await AppHaptics.success(context);
    if (!context.mounted) return;
    setState(() => _completing = false);
  }

  void _openGuide(BuildContext context) {
    showHarmonicaGuide(
      context,
      skipIsClose: true,
      onSkip: () {},
      onComplete: () {
        if (!context.mounted) return;
        Navigator.of(context)
            .pushReplacement(lessonRoute(context, lessonById('lesson_2')));
      },
    );
  }

  void _openNextLesson(BuildContext context) {
    Navigator.of(context)
        .pushReplacement(lessonRoute(context, lessonById('lesson_2')));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final controller = AppScope.of(context);
    final completed = controller.completedLessons.contains('lesson_1');
    return Scaffold(
      appBar: AppBar(title: Text(context.strings.lessonTitle('lesson_1'))),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppAdaptive.pagePadding(context),
          8,
          AppAdaptive.pagePadding(context),
          32,
        ),
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
          OutlinedButton.icon(
            key: const Key('lesson-1-guide'),
            onPressed: () => _openGuide(context),
            icon: const Icon(Icons.front_hand_outlined),
            label: Text(context.strings.t('guideReopen')),
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
          AnimatedSwitcher(
            duration: AppMotion.duration(context, AppMotion.base),
            child: completed
                ? _CompletedAction(
                    key: const ValueKey('lesson-1-complete'),
                    onNext: () => _openNextLesson(context),
                  )
                : SizedBox(
                    key: const ValueKey('lesson-1-action'),
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _completing ? null : () => _complete(context),
                      icon: const Icon(Icons.check_rounded),
                      label: Text(context.strings.t('completeLesson')),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CompletedAction extends StatelessWidget {
  const _CompletedAction({required this.onNext, super.key});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle_rounded, color: context.colors.success),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.strings.t('lessonComplete'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('lesson-1-next'),
          onPressed: onNext,
          child: Text(context.strings.t('nextLesson')),
        ),
      ],
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
