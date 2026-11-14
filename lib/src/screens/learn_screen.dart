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
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _ReedPathMeter(
                  total: lessons.length,
                  completedIds: controller.completedLessons,
                  activeId: nextLesson.id,
                ),
                const SizedBox(height: 14),
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

class _ReedPathMeter extends StatelessWidget {
  const _ReedPathMeter({
    required this.total,
    required this.completedIds,
    required this.activeId,
  });

  final int total;
  final Set<String> completedIds;
  final String activeId;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: AnimatedContainer(
              duration: AppMotion.duration(context, AppMotion.base),
              curve: AppMotion.standardCurve,
              height: 5,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: completedIds.contains(lessons[i].id)
                    ? palette.success
                    : lessons[i].id == activeId
                    ? palette.primary
                    : palette.outline,
              ),
            ),
          ),
        ],
      ],
    );
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
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF5B93FF),
                palette.primary,
              ],
            ),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.24),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: palette.primary.withValues(alpha: 0.24),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
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
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontSize: 23,
              letterSpacing: -0.4,
            ),
          ),
        ),
        if (showCoachTrigger) ...[
          GestureDetector(
            onTap: onReopenCoach,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: palette.surface,
                shape: BoxShape.circle,
                border: Border.all(color: palette.outline),
              ),
              alignment: Alignment.center,
              child: const ChumingBird(
                size: 28,
                mood: ChumingMood.idle,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Material(
          color: palette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: palette.outline),
          ),
          child: InkWell(
            key: const Key('learn-key-selector'),
            onTap: onChooseKey,
            borderRadius: BorderRadius.circular(14),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: palette.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      context.strings.t('keyName', {'key': harmonicaKey}),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 3),
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
                          ? palette.primary.withValues(alpha: 0.14)
                          : isImmediateNext
                          ? palette.accent.withValues(alpha: 0.10)
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
                      boxShadow: active
                          ? [
                              BoxShadow(
                                color: palette.primary.withValues(alpha: 0.18),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
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
                                fontFamily: 'monospace',
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.surface,
            palette.primary.withValues(alpha: isDark ? 0.08 : 0.035),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: palette.primary.withValues(alpha: 0.50),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: palette.primary.withValues(alpha: isDark ? 0.16 : 0.10),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: CustomPaint(
          painter: _HarmonicaCombWatermarkPainter(
            color: palette.primary.withValues(alpha: isDark ? 0.07 : 0.045),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: Key('progressive-active-${lesson.id}'),
              onTap: onTap,
              borderRadius: BorderRadius.circular(22),
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
                            horizontal: 10,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: palette.primary.withValues(alpha: 0.13),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: palette.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  strings.t('pathCurrentStage'),
                                  style: TextStyle(
                                    color: palette.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          strings.t('aboutMinutes', {'count': lesson.minutes}),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: palette.muted,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 11),
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
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: palette.muted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        TapGesturePulse(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  const Color(0xFF5B93FF),
                                  palette.primary,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: palette.primary.withValues(
                                    alpha: 0.30,
                                  ),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: Icon(
                                Icons.play_arrow_rounded,
                                color: palette.onPrimary,
                                size: 27,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
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
                                  ? palette.primary.withValues(alpha: 0.11)
                                  : palette.surfaceHigh.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                color: i == 0
                                    ? palette.primary.withValues(alpha: 0.32)
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
      color: palette.surface.withValues(alpha: 0.82),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: palette.success.withValues(alpha: 0.32)),
      ),
      child: InkWell(
        key: Key('progressive-completed-${lesson.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: palette.success.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.replay_rounded,
                  color: palette.success,
                  size: 16,
                ),
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
      color: palette.surface.withValues(alpha: 0.90),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: palette.outline),
      ),
      child: InkWell(
        key: Key('progressive-upcoming-${lesson.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
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
                  horizontal: 9,
                  vertical: 3.5,
                ),
                decoration: BoxDecoration(
                  color: palette.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: palette.accent.withValues(alpha: 0.28),
                  ),
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
      color: palette.surface.withValues(alpha: 0.52),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: palette.outline),
      ),
      child: InkWell(
        key: Key('progressive-upcoming-${lesson.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
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
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: palette.surfaceHigh,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.lock_outline_rounded,
                  color: palette.muted,
                  size: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HarmonicaCombWatermarkPainter extends CustomPainter {
  const _HarmonicaCombWatermarkPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width - 108, -10, 96, 36),
      const Radius.circular(8),
    );
    canvas.drawRRect(rect, paint);
    for (var i = 1; i <= 4; i++) {
      final x = size.width - 108 + i * 19.2;
      canvas.drawLine(Offset(x, -10), Offset(x, 26), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HarmonicaCombWatermarkPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
