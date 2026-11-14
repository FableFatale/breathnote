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

class _TimelineLesson extends StatefulWidget {
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

  @override
  State<_TimelineLesson> createState() => _TimelineLessonState();
}

class _TimelineLessonState extends State<_TimelineLesson> {
  bool _previewExpanded = false;

  List<String> _microSteps(AppStrings strings) {
    final index = widget.lessonIndex + 1;
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
    final complete = widget.complete;
    final active = widget.active;
    final isImmediateNext =
        !complete && !active && widget.lessonIndex == widget.nextLessonIndex + 1;
    final title = strings.lessonTitle(widget.lesson.id);
    final detail = strings.lessonDetail(widget.lesson.id);
    final steps = _microSteps(strings);

    final topLineColor = widget.first
        ? Colors.transparent
        : (complete || active)
        ? palette.success.withValues(alpha: 0.55)
        : palette.outline;
    final bottomLineColor = widget.last
        ? Colors.transparent
        : complete
        ? palette.success.withValues(alpha: 0.55)
        : active
        ? palette.primary.withValues(alpha: 0.45)
        : palette.outline;

    return Semantics(
      container: true,
      button: true,
      label: title,
      excludeSemantics: true,
      onTap: widget.onTap,
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
                          : palette.surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        width: active ? 2 : 1.2,
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
                          : active
                          ? Text(
                              widget.lesson.number,
                              key: const ValueKey('active'),
                              style: TextStyle(
                                color: palette.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            )
                          : Icon(
                              isImmediateNext
                                  ? Icons.timelapse_rounded
                                  : Icons.lock_outline_rounded,
                              key: ValueKey('locked-$isImmediateNext'),
                              color: isImmediateNext
                                  ? palette.accent
                                  : palette.muted,
                              size: 16,
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
                    ? _buildCompletedStageCard(context, palette, strings, title)
                    : _buildProgressiveUpcomingCard(
                        context,
                        palette,
                        strings,
                        title,
                        detail,
                        steps,
                        isImmediateNext,
                      ),
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
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: palette.primary.withValues(alpha: 0.55),
          width: 1.4,
        ),
      ),
      child: InkWell(
        key: Key('progressive-active-${widget.lesson.id}'),
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
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
                    strings.t('aboutMinutes', {'count': widget.lesson.minutes}),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: palette.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          detail,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: palette.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: palette.primary,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: Theme.of(context).colorScheme.onPrimary,
                      size: 20,
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
    AppStrings strings,
    String title,
  ) {
    return Material(
      color: palette.surface.withValues(alpha: 0.72),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: palette.success.withValues(alpha: 0.32)),
      ),
      child: InkWell(
        key: Key('progressive-completed-${widget.lesson.id}'),
        onTap: widget.onTap,
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
                    const SizedBox(height: 2),
                    Text(
                      strings.t('pathCompletedStage'),
                      style: TextStyle(
                        color: palette.success,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
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

  Widget _buildProgressiveUpcomingCard(
    BuildContext context,
    AppPalette palette,
    AppStrings strings,
    String title,
    String detail,
    List<String> steps,
    bool isImmediateNext,
  ) {
    return Material(
      color: palette.surface.withValues(alpha: isImmediateNext ? 0.85 : 0.50),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: palette.outline),
      ),
      child: InkWell(
        key: Key('progressive-upcoming-${widget.lesson.id}'),
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isImmediateNext
                                    ? palette.accent.withValues(alpha: 0.14)
                                    : palette.surfaceHigh,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                isImmediateNext
                                    ? strings.t('pathUpcomingStage')
                                    : strings.t('pathLockedStage'),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isImmediateNext
                                      ? palette.accent
                                      : palette.muted,
                                ),
                              ),
                            ),
                            Text(
                              strings.t('lessonLabel', {
                                'number': widget.lesson.number,
                              }),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: palette.muted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: isImmediateNext
                                    ? palette.text
                                    : palette.muted,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: _previewExpanded
                        ? strings.t('pathCollapsePreview')
                        : strings.t('pathExpandPreview'),
                    onPressed: () {
                      setState(() {
                        _previewExpanded = !_previewExpanded;
                      });
                    },
                    icon: Icon(
                      _previewExpanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: palette.muted,
                      size: 20,
                    ),
                  ),
                ],
              ),
              AnimatedCrossFade(
                duration: AppMotion.duration(context, AppMotion.fast),
                crossFadeState: _previewExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detail,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: palette.muted),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final step in steps)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: palette.surfaceHigh,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                step,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: palette.muted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
