import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../state/app_controller.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';
import '../theme/app_adaptive.dart';
import '../widgets/motion_widgets.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/harmonica_guide.dart'
    show showHarmonicaGuide, showHarmonicaKeyPicker;
import 'lesson_routes.dart';

class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final strings = context.strings;
    final pagePadding = AppAdaptive.pagePadding(context);
    final progress = controller.lessonProgress;
    final progressPercent = (progress * 100).round();
    final nextLesson = lessons.firstWhere(
      (lesson) => !controller.completedLessons.contains(lesson.id),
      orElse: () => lessons.last,
    );

    return CustomScrollView(
      key: const PageStorageKey('learn'),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(pagePadding, 18, pagePadding, 0),
          sliver: SliverToBoxAdapter(
            child: _Header(
              harmonicaKey: controller.harmonicaKey,
              onChooseKey: () => showHarmonicaKeyPicker(context),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(pagePadding, 34, pagePadding, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: SectionLabel(strings.t('todayPractice'))),
                    Icon(
                      Icons.local_fire_department_rounded,
                      color: context.colors.success,
                      size: 17,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      controller.currentStreak == 0
                          ? strings.t('startToday')
                          : strings.t('streakDays', {
                              'count': controller.currentStreak,
                            }),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        strings.t('learnHero'),
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                    ),
                    const SizedBox(width: 18),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _HeroMark(color: context.colors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                AnimatedSwitcher(
                  duration: AppMotion.duration(context, AppMotion.base),
                  child: _PracticeCard(
                    key: ValueKey(nextLesson.id),
                    lesson: nextLesson,
                    progress: progress,
                    progressPercent: progressPercent,
                    onStart: () => _openLesson(context, nextLesson),
                  ),
                ),
                if (!controller.sawHarmonicaGuide &&
                    nextLesson.id == 'lesson_1') ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      key: const Key('learn-beginner-guide'),
                      onPressed: () => _showBeginnerGuide(context),
                      icon: const Icon(Icons.front_hand_outlined),
                      label: Text(strings.t('guideStepTitle')),
                    ),
                  ),
                ],
                const SizedBox(height: 40),
                SectionLabel(strings.t('learningPath')),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        strings.t('learningPathTitle'),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    Text(
                      strings.t('pathProgress', {
                        'done': controller.completedLessons.length,
                        'total': lessons.length,
                      }),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(pagePadding, 0, pagePadding, 32),
          sliver: SliverList.builder(
            itemCount: lessons.length,
            itemBuilder: (context, index) {
              final lesson = lessons[index];
              return _TimelineLesson(
                lesson: lesson,
                complete: controller.completedLessons.contains(lesson.id),
                active: lesson.id == nextLesson.id,
                first: index == 0,
                last: index == lessons.length - 1,
                onTap: () => _openLesson(context, lesson),
              );
            },
          ),
        ),
      ],
    );
  }

  static void _showBeginnerGuide(BuildContext context) {
    showHarmonicaGuide(
      context,
      skipIsClose: false,
      onSkip: () {
        if (!context.mounted) return;
        Navigator.of(context)
            .push(lessonRoute(context, lessonById('lesson_1')));
      },
      onComplete: () {
        if (!context.mounted) return;
        Navigator.of(context)
            .push(lessonRoute(context, lessonById('lesson_2')));
      },
    );
  }

  static void _openLesson(BuildContext context, LessonDefinition lesson) {
    if (lesson.id == 'lesson_1' && !AppScope.of(context).sawHarmonicaGuide) {
      _showBeginnerGuide(context);
      return;
    }
    Navigator.of(context).push(lessonRoute(context, lesson));
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.harmonicaKey, required this.onChooseKey});

  final String harmonicaKey;
  final VoidCallback onChooseKey;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: palette.primary,
            borderRadius: BorderRadius.circular(7),
          ),
          child: const Icon(Icons.piano_rounded, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            context.strings.t('appTitle'),
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontSize: 22),
          ),
        ),
        Material(
          color: palette.surfaceHigh,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            key: const Key('learn-key-selector'),
            onTap: onChooseKey,
            borderRadius: BorderRadius.circular(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.strings.t('keyName', {'key': harmonicaKey}),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: palette.muted,
                      size: 19,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroMark extends StatelessWidget {
  const _HeroMark({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(Icons.piano_rounded, color: color, size: 54),
        Positioned(
          right: -6,
          top: -15,
          child: Icon(
            Icons.music_note_rounded,
            color: context.colors.accent,
            size: 25,
          ),
        ),
      ],
    );
  }
}

class _PracticeCard extends StatelessWidget {
  const _PracticeCard({
    required this.lesson,
    required this.progress,
    required this.progressPercent,
    required this.onStart,
    super.key,
  });

  final LessonDefinition lesson;
  final double progress;
  final int progressPercent;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final strings = context.strings;
    final title = strings.lessonTitle(lesson.id);
    return Semantics(
      container: true,
      button: true,
      label: strings.t('openLesson', {'title': title}),
      excludeSemantics: true,
      onTap: onStart,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onStart,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Pill(
                      label: strings.t('lessonLabel', {
                        'number': lesson.number,
                      }),
                      color: palette.primary.withValues(alpha: 0.10),
                      foreground: palette.primary,
                    ),
                    Text(
                      strings.t('aboutMinutes', {'count': lesson.minutes}),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 7),
                          Text(
                            strings.lessonDetail(lesson.id),
                            style: TextStyle(color: palette.muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: onStart,
                      style: FilledButton.styleFrom(
                        fixedSize: const Size(56, 56),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Icon(Icons.play_arrow_rounded, size: 30),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: MotionLinearProgress(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: palette.surfaceHigh,
                    color: palette.accent,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  strings.t('completedPercent', {'percent': progressPercent}),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimelineLesson extends StatelessWidget {
  const _TimelineLesson({
    required this.lesson,
    required this.complete,
    required this.active,
    required this.first,
    required this.last,
    required this.onTap,
  });

  final LessonDefinition lesson;
  final bool complete;
  final bool active;
  final bool first;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final strings = context.strings;
    return Semantics(
      container: true,
      button: true,
      label: strings.lessonTitle(lesson.id),
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 104),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 48,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: Column(
                          children: [
                            Expanded(
                              child: Center(
                                child: SizedBox(
                                  width: 1,
                                  height: double.infinity,
                                  child: ColoredBox(
                                    color: first
                                        ? Colors.transparent
                                        : palette.outline,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 40),
                            Expanded(
                              child: Center(
                                child: SizedBox(
                                  width: 1,
                                  height: double.infinity,
                                  child: ColoredBox(
                                    color: last
                                        ? Colors.transparent
                                        : palette.outline,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      AnimatedContainer(
                        duration: AppMotion.duration(context, AppMotion.base),
                        curve: AppMotion.standardCurve,
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: complete
                              ? palette.success.withValues(alpha: 0.10)
                              : active
                              ? palette.primary.withValues(alpha: 0.06)
                              : palette.background,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: complete
                                ? palette.success
                                : active
                                ? palette.primary
                                : palette.outline,
                          ),
                        ),
                        child: AnimatedSwitcher(
                          duration: AppMotion.duration(context, AppMotion.fast),
                          child: complete
                              ? Icon(
                                  Icons.check_rounded,
                                  key: const ValueKey('complete'),
                                  color: palette.success,
                                  size: 20,
                                )
                              : Text(
                                  lesson.number,
                                  key: ValueKey(active),
                                  style: TextStyle(
                                    color: active
                                        ? palette.primary
                                        : palette.muted,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: last
                          ? null
                          : Border(bottom: BorderSide(color: palette.outline)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                strings.lessonTitle(lesson.id),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                strings.lessonDetail(lesson.id),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          strings.t('commonMinutes', {'count': lesson.minutes}),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: palette.muted,
                          size: 21,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
