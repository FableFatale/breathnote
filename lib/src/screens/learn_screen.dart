import 'dart:async';

import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../models/practice_note.dart';
import '../models/song.dart';
import '../services/haptics.dart';
import '../state/app_controller.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';
import '../widgets/motion_widgets.dart';
import '../widgets/shared_widgets.dart';
import 'lesson_detail_screen.dart';
import 'practice_screen.dart';
import 'song_practice_screen.dart';

class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  static const _harmonicaKeys = [
    'C',
    'D♭',
    'D',
    'E♭',
    'E',
    'F',
    'F#',
    'G',
    'A♭',
    'A',
    'B♭',
    'B',
  ];

  static const _lessons = [
    _Lesson(
      id: 'lesson_1',
      number: '01',
      minutes: 4,
      kind: _LessonKind.introduction,
    ),
    _Lesson(
      id: 'lesson_2',
      number: '02',
      minutes: 6,
      kind: _LessonKind.firstNote,
    ),
    _Lesson(
      id: 'lesson_3',
      number: '03',
      minutes: 6,
      kind: _LessonKind.clearNote,
    ),
    _Lesson(
      id: 'lesson_4',
      number: '04',
      minutes: 5,
      kind: _LessonKind.drawNote,
    ),
    _Lesson(
      id: 'lesson_5',
      number: '05',
      minutes: 8,
      kind: _LessonKind.firstSong,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final strings = context.strings;
    final progress = controller.lessonProgress;
    final progressPercent = (progress * 100).round();
    final nextLesson = _lessons.firstWhere(
      (lesson) => !controller.completedLessons.contains(lesson.id),
      orElse: () => _lessons.last,
    );

    return CustomScrollView(
      key: const PageStorageKey('learn'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          sliver: SliverToBoxAdapter(
            child: _Header(
              harmonicaKey: controller.harmonicaKey,
              onChooseKey: () => _chooseKey(context),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 34, 20, 0),
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
                        'total': _lessons.length,
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
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          sliver: SliverList.builder(
            itemCount: _lessons.length,
            itemBuilder: (context, index) {
              final lesson = _lessons[index];
              return _TimelineLesson(
                lesson: lesson,
                complete: controller.completedLessons.contains(lesson.id),
                active: lesson.id == nextLesson.id,
                first: index == 0,
                last: index == _lessons.length - 1,
                onTap: () => _openLesson(context, lesson),
              );
            },
          ),
        ),
      ],
    );
  }

  static Future<void> _chooseKey(BuildContext context) async {
    final controller = AppScope.of(context);
    unawaited(AppHaptics.selection(context));
    final selected = await showModalBottomSheet<String>(
      context: context,
      sheetAnimationStyle: AppMotion.animationStyle(
        context,
        duration: AppMotion.slow,
        reverseDuration: AppMotion.base,
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.strings.t('chooseHarmonicaKey'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  context.strings.t('chooseHarmonicaKeyDetail'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _harmonicaKeys.map((key) {
                    return ChoiceChip(
                      label: Text(context.strings.t('keyName', {'key': key})),
                      selected: controller.harmonicaKey == key,
                      onSelected: (_) => Navigator.pop(context, key),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected == null || !context.mounted) return;
    await controller.setHarmonicaKey(selected);
    if (!context.mounted) return;
    await AppHaptics.selection(context);
  }

  static void _openLesson(BuildContext context, _Lesson lesson) {
    final strings = context.strings;
    final reduceMotion = AppMotion.isReduced(context);
    final route = switch (lesson.kind) {
      _LessonKind.introduction => AppPageRoute<void>(
        reduceMotion: reduceMotion,
        builder: (_) => const LessonDetailScreen(),
      ),
      _LessonKind.firstNote => AppPageRoute<void>(
        reduceMotion: reduceMotion,
        builder: (_) => PracticeScreen(
          target: const PracticeNote(note: 'C', octave: 5, tab: '4↑'),
          title: strings.lessonTitle('lesson_2'),
          lessonId: 'lesson_2',
          instruction: strings.lessonGuidance('lesson_2'),
          step: 2,
        ),
      ),
      _LessonKind.clearNote => AppPageRoute<void>(
        reduceMotion: reduceMotion,
        builder: (_) => PracticeScreen(
          target: const PracticeNote(note: 'E', octave: 5, tab: '5↑'),
          title: strings.lessonTitle('lesson_3'),
          lessonId: 'lesson_3',
          instruction: strings.lessonGuidance('lesson_3'),
          step: 3,
        ),
      ),
      _LessonKind.drawNote => AppPageRoute<void>(
        reduceMotion: reduceMotion,
        builder: (_) => PracticeScreen(
          target: const PracticeNote(note: 'D', octave: 5, tab: '4↓'),
          title: strings.lessonTitle('lesson_4'),
          lessonId: 'lesson_4',
          instruction: strings.lessonGuidance('lesson_4'),
          step: 4,
        ),
      ),
      _LessonKind.firstSong => AppPageRoute<void>(
        reduceMotion: reduceMotion,
        builder: (_) =>
            SongPracticeScreen(song: songs.first, lessonId: 'lesson_5'),
      ),
    };
    Navigator.of(context).push(route);
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

  final _Lesson lesson;
  final double progress;
  final int progressPercent;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final strings = context.strings;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onStart,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Pill(
                    label: strings.t('lessonLabel', {'number': lesson.number}),
                    color: palette.primary.withValues(alpha: 0.10),
                    foreground: palette.primary,
                  ),
                  const Spacer(),
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
                          strings.lessonTitle(lesson.id),
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

  final _Lesson lesson;
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
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 104,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (!first)
                      Positioned(
                        left: 23,
                        top: 0,
                        height: 33,
                        child: Container(width: 1, color: palette.outline),
                      ),
                    if (!last)
                      Positioned(
                        left: 23,
                        top: 71,
                        bottom: 0,
                        child: Container(width: 1, color: palette.outline),
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
    );
  }
}

enum _LessonKind { introduction, firstNote, clearNote, drawNote, firstSong }

class _Lesson {
  const _Lesson({
    required this.id,
    required this.number,
    required this.minutes,
    required this.kind,
  });

  final String id;
  final String number;
  final int minutes;
  final _LessonKind kind;
}
