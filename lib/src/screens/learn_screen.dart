import 'dart:async';

import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../services/haptics.dart';
import '../state/app_controller.dart';
import '../theme/app_adaptive.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';
import '../widgets/chuming_coach.dart';
import '../widgets/cute_illustrations.dart';
import '../widgets/gesture_guide.dart';
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
    final nextLesson = lessons.firstWhere(
      (lesson) => !controller.completedLessons.contains(lesson.id),
      orElse: () => lessons.last,
    );
    final coachDismissed = controller.seenCoachTips.contains('learn');

    return CustomScrollView(
      key: const PageStorageKey('learn'),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(pagePadding, 20, pagePadding, 0),
          sliver: SliverToBoxAdapter(
            child: _Header(
              harmonicaKey: controller.harmonicaKey,
              showCoachTrigger: coachDismissed,
              onReopenCoach: () {
                unawaited(AppHaptics.reedResonance(context));
                unawaited(controller.reopenCoachTip('learn'));
              },
              onChooseKey: () => showHarmonicaKeyPicker(context),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(pagePadding, 16, pagePadding, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ChumingCoachBanner(
                  featureId: 'learn',
                  messageKey: 'coachLearn',
                  mood: ChumingMood.idle,
                ),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    Text(
                      strings.t('learningPath'),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (controller.streakDays > 0)
                          CuteStreakBadge(
                            streakDays: controller.streakDays,
                            label: strings.t('commonDays', {
                              'count': controller.streakDays,
                            }),
                          ),
                        Text(
                          strings.t('pathProgress', {
                            'done': controller.completedLessons.length,
                            'total': lessons.length,
                          }),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: context.colors.muted,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
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
              final nextIndex = lessons.indexWhere(
                (item) => item.id == nextLesson.id,
              );
              return _TimelineLesson(
                lesson: lesson,
                lessonIndex: index,
                nextLessonIndex: nextIndex,
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
            .push(lessonRoute(context, lessonById('lesson_1')));
      },
    );
  }

  static void _openLesson(BuildContext context, LessonDefinition lesson) {
    unawaited(AppHaptics.selection(context));
    if (lesson.id == 'lesson_1' && !AppScope.read(context).sawHarmonicaGuide) {
      _showBeginnerGuide(context);
      return;
    }
    Navigator.of(context).push(lessonRoute(context, lesson));
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.harmonicaKey,
    required this.showCoachTrigger,
    required this.onReopenCoach,
    required this.onChooseKey,
  });

  final String harmonicaKey;
  final bool showCoachTrigger;
  final VoidCallback onReopenCoach;
  final VoidCallback onChooseKey;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: palette.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: const HarmonicaBrandIcon(
            size: 24,
            color: Colors.white,
            accentColor: Color(0xFF60F178),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            context.strings.t('appTitle'),
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontSize: 22),
          ),
        ),
        if (showCoachTrigger) ...[
          GestureDetector(
            onTap: onReopenCoach,
            child: const ChumingBird(
              size: 34,
              mood: ChumingMood.idle,
            ),
          ),
          const SizedBox(width: 8),
        ],
        Material(
          color: palette.surfaceHigh,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            key: const Key('learn-key-selector'),
            onTap: onChooseKey,
            borderRadius: BorderRadius.circular(14),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.strings.t('keyName', {'key': harmonicaKey}),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: palette.muted,
                      size: 18,
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

class _TimelineLesson extends StatelessWidget {
  const _TimelineLesson({
    required this.lesson,
    required this.lessonIndex,
    required this.nextLessonIndex,
    required this.complete,
    required this.active,
    required this.first,
    required this.last,
    required this.onTap,
  });

  final LessonDefinition lesson;
  final int lessonIndex;
  final int nextLessonIndex;
  final bool complete;
  final bool active;
  final bool first;
  final bool last;
  final VoidCallback onTap;

  List<String> _microSteps(AppStrings strings) {
    final index = lessonIndex + 1;
    return [
      strings.t('pathStep${index}_1'),
      strings.t('pathStep${index}_2'),
      strings.t('pathStep${index}_3'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final strings = context.strings;
    final isImmediateNext =
        !complete && !active && lessonIndex == nextLessonIndex + 1;
    final title = strings.lessonTitle(lesson.id);
    final detail = strings.lessonDetail(lesson.id);
    final steps = _microSteps(strings);

    final topLineColor = first
        ? Colors.transparent
        : (complete || active)
        ? palette.success.withValues(alpha: 0.55)
        : palette.outline;
    final bottomLineColor = last
        ? Colors.transparent
        : complete
        ? palette.success.withValues(alpha: 0.55)
        : active
        ? palette.primary.withValues(alpha: 0.45)
        : palette.outline;

    return Semantics(
      key: active ? const Key('featured-lesson') : null,
      container: true,
      button: true,
      label: active ? strings.t('openLesson', {'title': title}) : title,
      excludeSemantics: true,
      onTap: onTap,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 42,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: Column(
                      children: [
                        Expanded(
                          child: Center(
                            child: SizedBox(
                              width: 2,
                              height: double.infinity,
                              child: ColoredBox(color: topLineColor),
                            ),
                          ),
                        ),
                        const SizedBox(height: 38),
                        Expanded(
                          child: Center(
                            child: SizedBox(
                              width: 2,
                              height: double.infinity,
                              child: ColoredBox(color: bottomLineColor),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedContainer(
                    duration: AppMotion.duration(context, AppMotion.base),
                    curve: AppMotion.standardCurve,
                    width: active ? 40 : 36,
                    height: active ? 40 : 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: complete
                          ? palette.success.withValues(alpha: 0.14)
                          : active
                          ? palette.primary.withValues(alpha: 0.16)
                          : isImmediateNext
                          ? palette.accent.withValues(alpha: 0.12)
                          : palette.surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        width: active ? 2 : 1.2,
                        color: complete
                            ? palette.success
                            : active
                            ? palette.primary
                            : isImmediateNext
                            ? palette.accent.withValues(alpha: 0.65)
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
                              key: ValueKey('num-${lesson.number}-$active'),
                              style: TextStyle(
                                color: active
                                    ? palette.primary
                                    : isImmediateNext
                                    ? palette.accent
                                    : palette.muted,
                                fontWeight: active
                                    ? FontWeight.w800
                                    : FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: active
                    ? _buildActiveStageCard(
                        context,
                        palette,
                        strings,
                        title,
                        detail,
                        steps,
                      )
                    : complete
                    ? _buildCompletedStageCard(context, palette, title)
                    : isImmediateNext
                    ? _buildImmediateNextCard(
                        context,
                        palette,
                        strings,
                        title,
                        detail,
                      )
                    : _buildLockedCard(context, palette, title),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveStageCard(
    BuildContext context,
    AppPalette palette,
    AppStrings strings,
    String title,
    String detail,
    List<String> steps,
  ) {
    return Material(
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: palette.primary.withValues(alpha: 0.55),
          width: 1.5,
        ),
      ),
      child: InkWell(
        key: Key('progressive-active-${lesson.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: palette.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      strings.t('pathCurrentStage'),
                      style: TextStyle(
                        color: palette.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Text(
                    strings.t('aboutMinutes', {'count': lesson.minutes}),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: palette.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
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
                        const SizedBox(height: 4),
                        Text(
                          detail,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: palette.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  TapGesturePulse(
                    child: FilledButton(
                      onPressed: onTap,
                      style: FilledButton.styleFrom(
                        fixedSize: const Size(48, 48),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: const Icon(Icons.play_arrow_rounded, size: 26),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < steps.length; i++)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: i == 0
                            ? palette.primary.withValues(alpha: 0.12)
                            : palette.surfaceHigh,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: i == 0
                              ? palette.primary.withValues(alpha: 0.35)
                              : palette.outline,
                        ),
                      ),
                      child: Text(
                        steps[i],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: i == 0
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: i == 0 ? palette.primary : palette.muted,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompletedStageCard(
    BuildContext context,
    AppPalette palette,
    String title,
  ) {
    return Material(
      color: palette.surface.withValues(alpha: 0.72),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: palette.success.withValues(alpha: 0.32)),
      ),
      child: InkWell(
        key: Key('progressive-completed-${lesson.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Icon(
                Icons.replay_rounded,
                color: palette.success,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImmediateNextCard(
    BuildContext context,
    AppPalette palette,
    AppStrings strings,
    String title,
    String detail,
  ) {
    return Material(
      color: palette.surface.withValues(alpha: 0.88),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: palette.outline),
      ),
      child: InkWell(
        key: Key('progressive-upcoming-${lesson.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      detail,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: palette.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
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
                  strings.t('pathUpcomingStage'),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: palette.accent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLockedCard(
    BuildContext context,
    AppPalette palette,
    String title,
  ) {
    return Material(
      color: palette.surface.withValues(alpha: 0.50),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: palette.outline),
      ),
      child: InkWell(
        key: Key('progressive-upcoming-${lesson.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: palette.muted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.lock_outline_rounded,
                color: palette.muted,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
