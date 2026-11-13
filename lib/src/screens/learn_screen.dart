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
import '../widgets/shared_widgets.dart';
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

    return CustomScrollView(
      key: const PageStorageKey('learn'),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(pagePadding, 20, pagePadding, 0),
          sliver: SliverToBoxAdapter(
            child: _Header(
              harmonicaKey: controller.harmonicaKey,
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
                AnimatedSwitcher(
                  duration: AppMotion.duration(context, AppMotion.base),
                  child: _PracticeCard(
                    key: ValueKey(nextLesson.id),
                    lesson: nextLesson,
                    onStart: () => _openLesson(context, nextLesson),
                  ),
                ),
                const SizedBox(height: 24),
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
                    Text(
                      strings.t('pathProgress', {
                        'done': controller.completedLessons.length,
                        'total': lessons.length,
                      }),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.colors.muted,
                        fontWeight: FontWeight.w600,
                      ),
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
            .push(lessonRoute(context, lessonById('lesson_1')));
      },
    );
  }

  static void _openLesson(BuildContext context, LessonDefinition lesson) {
    unawaited(AppHaptics.selection(context));
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

class _PracticeCard extends StatelessWidget {
  const _PracticeCard({required this.lesson, required this.onStart, super.key});

  final LessonDefinition lesson;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final palette = context.colors;
    final strings = context.strings;
    final title = strings.lessonTitle(lesson.id);
    final compact = AppAdaptive.isCompact(context);
    final cardPadding = AppAdaptive.cardPadding(context);

    return Semantics(
      key: const Key('featured-lesson'),
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
            padding: EdgeInsets.all(cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    if (controller.streakDays > 0)
                      CuteStreakBadge(
                        streakDays: controller.streakDays,
                        label: strings.t('commonDays', {
                          'count': controller.streakDays,
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (!compact) ...[
                      const ChumingBird(
                        size: 46,
                        mood: ChumingMood.idle,
                        interactive: false,
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    const SizedBox(width: 12),
                    TapGesturePulse(
                      child: FilledButton(
                        onPressed: onStart,
                        style: FilledButton.styleFrom(
                          fixedSize: const Size(52, 52),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Icon(Icons.play_arrow_rounded, size: 28),
                      ),
                    ),
                  ],
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
          constraints: const BoxConstraints(minHeight: 72),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 40,
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
                            const SizedBox(height: 38),
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
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: complete
                              ? palette.success.withValues(alpha: 0.10)
                              : active
                              ? palette.primary.withValues(alpha: 0.08)
                              : palette.surface,
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
                const SizedBox(width: 14),
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
                          child: Text(
                            strings.lessonTitle(lesson.id),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: palette.muted,
                          size: 20,
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
