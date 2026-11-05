import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import 'practice_screen.dart';

class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  static const _lessons = [
    _Lesson(
      number: '01',
      title: '认识你的口琴',
      detail: '口琴结构与正确握法',
      duration: '4 分钟',
      complete: true,
    ),
    _Lesson(
      number: '02',
      title: '清晰的单音',
      detail: '嘴型与气息控制',
      duration: '6 分钟',
      active: true,
    ),
    _Lesson(
      number: '03',
      title: '吸气音练习',
      detail: '4 孔吸气 · G',
      duration: '5 分钟',
    ),
    _Lesson(
      number: '04',
      title: '第一首旋律',
      detail: '小星星 · 上半段',
      duration: '8 分钟',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      key: const PageStorageKey('learn'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          sliver: const SliverToBoxAdapter(child: _Header()),
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
                  onStart: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const PracticeScreen(),
                      ),
                    );
                  },
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
            itemBuilder: (context, index) => _LessonTile(
              lesson: _lessons[index],
              onTap: _lessons[index].active
                  ? () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const PracticeScreen(),
                        ),
                      );
                    }
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            '息音',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const Pill(
          label: '连续 3 天',
          icon: Icons.local_fire_department_rounded,
          color: Color(0xFF3A2D25),
          foreground: AppColors.accent,
        ),
        const SizedBox(width: 8),
        const Pill(label: 'C 调'),
      ],
    );
  }
}

class _PracticeCard extends StatelessWidget {
  const _PracticeCard({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onStart,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Pill(
                    label: '第 2 课',
                    color: Color(0xFF26304D),
                    foreground: AppColors.primary,
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
                          '吹响第一个音',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 7),
                        const Text(
                          '4 孔吹气 · C',
                          style: TextStyle(color: AppColors.muted),
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
                child: const LinearProgressIndicator(
                  value: 0.36,
                  minHeight: 6,
                  backgroundColor: AppColors.surfaceHigh,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '已完成 36%',
                style: TextStyle(
                  color: AppColors.muted,
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
  const _LessonTile({required this.lesson, this.onTap});

  final _Lesson lesson;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
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
                  color: lesson.complete
                      ? AppColors.success.withValues(alpha: 0.16)
                      : lesson.active
                      ? AppColors.primary.withValues(alpha: 0.18)
                      : AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: lesson.complete
                    ? const Icon(Icons.check_rounded, color: AppColors.success)
                    : Text(
                        lesson.number,
                        style: TextStyle(
                          color: lesson.active
                              ? AppColors.primary
                              : AppColors.muted,
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
              Text(
                lesson.duration,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(width: 3),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _Lesson {
  const _Lesson({
    required this.number,
    required this.title,
    required this.detail,
    required this.duration,
    this.complete = false,
    this.active = false,
  });

  final String number;
  final String title;
  final String detail;
  final String duration;
  final bool complete;
  final bool active;
}
