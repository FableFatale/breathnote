import 'package:flutter/material.dart';

import '../services/haptics.dart';
import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class LocalDataScreen extends StatelessWidget {
  const LocalDataScreen({super.key});

  Future<void> _clearData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除本机数据'),
        content: const Text('练习记录、课程进度、自定义曲谱和显示设置都会被删除。此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认清除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await AppScope.of(context).reset();
    if (!context.mounted) return;
    await AppHaptics.warning(context);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('本机数据已清除')));
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final palette = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('本机数据与隐私')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, color: palette.success, size: 34),
                  const SizedBox(height: 12),
                  Text(
                    '音频只在设备上分析',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '麦克风数据用于实时音高检测。原始音频不会保存，也不会上传。关闭练习或调音页面后，麦克风会停止。',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const SectionLabel('本机保存的内容'),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                _DataRow(
                  icon: Icons.calendar_today_rounded,
                  title: '练习日期',
                  value: '${controller.practiceDates.length} 天',
                ),
                const Divider(height: 1),
                _DataRow(
                  icon: Icons.timer_outlined,
                  title: '练习时长',
                  value: '${controller.practiceMinutes} 分钟',
                ),
                const Divider(height: 1),
                _DataRow(
                  icon: Icons.task_alt_rounded,
                  title: '课程进度',
                  value: '${controller.completedLessons.length}/5',
                ),
                const Divider(height: 1),
                _DataRow(
                  icon: Icons.queue_music_rounded,
                  title: '自定义曲谱',
                  value: '${controller.customSongs.length} 首',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _clearData(context),
              icon: Icon(Icons.delete_outline_rounded, color: palette.danger),
              label: Text('清除全部本机数据', style: TextStyle(color: palette.danger)),
            ),
          ),
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: Text(
        value,
        style: TextStyle(
          color: context.colors.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
