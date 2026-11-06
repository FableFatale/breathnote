import 'package:flutter/material.dart';

import '../models/practice_note.dart';
import '../models/song.dart';
import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import 'lesson_detail_screen.dart';
import 'practice_screen.dart';
import 'song_practice_screen.dart';

class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  static const _lessons = [
    _Lesson(
      id: 'lesson_1',
      number: '01',
      title: '认识你的口琴',
      detail: '口琴结构与正确握法',
      duration: '4 分钟',
      kind: _LessonKind.introduction,
    ),
    _Lesson(
      id: 'lesson_2',
      number: '02',
      title: '吹响第一个音',
      detail: '4 孔吹气 · 清晰起音',
      duration: '6 分钟',
      kind: _LessonKind.firstNote,
    ),
    _Lesson(
      id: 'lesson_3',
      number: '03',
      title: '清晰的单音',
      detail: '5 孔吹气 · 嘴型与气息',
      duration: '6 分钟',
      kind: _LessonKind.clearNote,
    ),
    _Lesson(
      id: 'lesson_4',
      number: '04',
      title: '吸气音练习',
      detail: '4 孔吸气 · 平稳气息',
      duration: '5 分钟',
      kind: _LessonKind.drawNote,
    ),
    _Lesson(
      id: 'lesson_5',
      number: '05',
      title: '第一首旋律',
      detail: '小星星 · 完整乐句',
      duration: '8 分钟',
      kind: _LessonKind.firstSong,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
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
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          sliver: SliverToBoxAdapter(
            child: _Header(
              streak: controller.currentStreak,
              harmonicaKey: controller.harmonicaKey,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('今日练习'),
                const SizedBox(height: 7),
                Text(
                  '慢一点，\n让每个音都清晰。',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 18),
                _PracticeCard(
                  lesson: nextLesson,
                  progress: progress,
                  progressPercent: progressPercent,
                  onStart: () => _openLesson(context, nextLesson),
                ),
                const SizedBox(height: 30),
                const SectionLabel('学习路径'),
                const SizedBox(height: 5),
                Text(
                  '从一次呼吸开始',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          sliver: SliverList.separated(
            itemCount: _lessons.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final lesson = _lessons[index];
              return _LessonTile(
                lesson: lesson,
                complete: controller.completedLessons.contains(lesson.id),
                active:
                    index == 0 ||
                    controller.completedLessons.contains(
                      _lessons[index - 1].id,
                    ),
                onTap: () => _openLesson(context, lesson),
              );
            },
          ),
        ),
      ],
    );
  }

  static void _openLesson(BuildContext context, _Lesson lesson) {
    final route = switch (lesson.kind) {
      _LessonKind.introduction => MaterialPageRoute<void>(
        builder: (_) => const LessonDetailScreen(),
      ),
      _LessonKind.firstNote => MaterialPageRoute<void>(
        builder: (_) => const PracticeScreen(
          target: PracticeNote(note: 'C', octave: 5, tab: '4↑'),
          title: '吹响第一个音',
          lessonId: 'lesson_2',
          instruction: '轻轻吹 4 孔，保持气息平稳。',
          step: 2,
        ),
      ),
      _LessonKind.clearNote => MaterialPageRoute<void>(
        builder: (_) => const PracticeScreen(
          target: PracticeNote(note: 'E', octave: 5, tab: '5↑'),
          title: '清晰的单音',
          lessonId: 'lesson_3',
          instruction: '缩小嘴型，只让一个孔发声。',
          step: 3,
        ),
      ),
      _LessonKind.drawNote => MaterialPageRoute<void>(
        builder: (_) => const PracticeScreen(
          target: PracticeNote(note: 'D', octave: 5, tab: '4↓'),
          title: '吸气音练习',
          lessonId: 'lesson_4',
          instruction: '放松下巴，平稳地从 4 孔吸气。',
          step: 4,
        ),
      ),
      _LessonKind.firstSong => MaterialPageRoute<void>(
        builder: (_) =>
            SongPracticeScreen(song: songs.first, lessonId: 'lesson_5'),
      ),
    };
    Navigator.of(context).push(route);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.streak, required this.harmonicaKey});

  final int streak;
  final String harmonicaKey;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Row(
      children: [
        Expanded(
          child: Text(
            '息音',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontSize: 22),
          ),
        ),
        Pill(
          label: streak == 0 ? '今天开始' : '连续 $streak 天',
          icon: Icons.local_fire_department_rounded,
          color: palette.surfaceHigh,
          foreground: palette.accentInk,
        ),
        const SizedBox(width: 8),
        Pill(label: '$harmonicaKey 调'),
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
  });

  final _Lesson lesson;
  final double progress;
  final int progressPercent;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
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
                    label: '第 ${lesson.number} 课',
                    color: palette.primary.withValues(alpha: 0.12),
                    foreground: palette.primary,
                  ),
                  const Spacer(),
                  Text('约 6 分钟', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lesson.title,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 7),
                        Text(
                          lesson.detail,
                          style: TextStyle(color: palette.muted),
                        ),
                      ],
                    ),
                  ),
                  FilledButton(
                    onPressed: onStart,
                    style: FilledButton.styleFrom(
                      fixedSize: const Size(52, 52),
                      padding: EdgeInsets.zero,
                      shape: const CircleBorder(),
                    ),
                    child: const Icon(Icons.play_arrow_rounded, size: 30),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: palette.surfaceHigh,
                  color: palette.accent,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '已完成 $progressPercent%',
                style: TextStyle(
                  color: palette.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({
    required this.lesson,
    required this.complete,
    required this.active,
    required this.onTap,
  });

  final _Lesson lesson;
  final bool complete;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: complete
                      ? palette.success.withValues(alpha: 0.16)
                      : active
                      ? palette.primary.withValues(alpha: 0.14)
                      : palette.surfaceHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: complete
                    ? Icon(Icons.check_rounded, color: palette.success)
                    : Text(
                        lesson.number,
                        style: TextStyle(
                          color: active ? palette.primary : palette.muted,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      lesson.detail,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                lesson.duration,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Icon(Icons.chevron_right_rounded, color: palette.muted),
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
    required this.title,
    required this.detail,
    required this.duration,
    required this.kind,
  });

  final String id;
  final String number;
  final String title;
  final String detail;
  final String duration;
  final _LessonKind kind;
}
