import 'package:flutter/material.dart';

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
      appBar: AppBar(title: const Text('认识你的口琴')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const SectionLabel('第 1 课 · 基础'),
          const SizedBox(height: 8),
          Text(
            '先认识 10 个孔，\n再吹出第一个音。',
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
                    '10 孔布鲁斯口琴',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  const HarmonicaDiagram(activeTab: null),
                  const SizedBox(height: 14),
                  Text(
                    '左侧是低音区，右侧是高音区。数字表示孔位，↑ 表示吹气，↓ 表示吸气。',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _Instruction(
            number: '1',
            title: '自然握住',
            detail: '用双手托住口琴，不要遮住背面的出音口。',
            color: palette.primary,
          ),
          const SizedBox(height: 10),
          _Instruction(
            number: '2',
            title: '放松嘴唇',
            detail: '把口琴轻轻含入口中，让嘴唇自然包住孔位。',
            color: palette.accentInk,
          ),
          const SizedBox(height: 10),
          _Instruction(
            number: '3',
            title: '使用腹部呼吸',
            detail: '保持肩膀放松，用稳定、轻柔的气流发声。',
            color: palette.success,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _complete(context),
              icon: const Icon(Icons.check_rounded),
              label: const Text('完成本课'),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
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
      ),
    );
  }
}
