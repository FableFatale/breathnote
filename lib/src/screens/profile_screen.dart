import 'dart:async';

import 'package:flutter/material.dart';

import '../services/haptics.dart';
import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import 'local_data_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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

  Future<void> _editName(BuildContext context) async {
    final controller = AppScope.of(context);
    final fieldController = TextEditingController(text: controller.displayName);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑昵称'),
        content: TextField(
          key: const Key('profile-name-field'),
          controller: fieldController,
          autofocus: true,
          maxLength: 20,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(labelText: '本机昵称'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('save-profile-name'),
            onPressed: () => Navigator.pop(context, fieldController.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (value == null || value.trim().isEmpty || !context.mounted) return;
    await controller.setDisplayName(value);
    if (!context.mounted) return;
    await AppHaptics.success(context);
  }

  Future<void> _chooseKey(BuildContext context) async {
    final controller = AppScope.of(context);
    unawaited(AppHaptics.selection(context));
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '选择口琴调性',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '课程音高、调音孔位和示范音会跟随这个设置。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _harmonicaKeys.map((key) {
                    return ChoiceChip(
                      key: Key('harmonica-key-$key'),
                      label: Text('$key 调'),
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

  Future<void> _showAccessibility(BuildContext context) async {
    unawaited(AppHaptics.selection(context));
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final controller = AppScope.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '无障碍与显示',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 18),
                Text('文字大小', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                SegmentedButton<double>(
                  segments: const [
                    ButtonSegment(value: 0.9, label: Text('90%')),
                    ButtonSegment(value: 1, label: Text('100%')),
                    ButtonSegment(value: 1.1, label: Text('110%')),
                    ButtonSegment(value: 1.2, label: Text('120%')),
                  ],
                  selected: {controller.textScale},
                  showSelectedIcon: false,
                  onSelectionChanged: (value) async {
                    await controller.setTextScale(value.first);
                    if (!context.mounted) return;
                    await AppHaptics.selection(context);
                  },
                ),
                const SizedBox(height: 14),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.contrast_rounded),
                  title: const Text('增强对比度'),
                  subtitle: const Text('提高文字和边界的可见度'),
                  value: controller.highContrast,
                  onChanged: (value) async {
                    await controller.setHighContrast(value);
                    if (!context.mounted) return;
                    await AppHaptics.selection(context);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.animation_rounded),
                  title: const Text('减少动态效果'),
                  subtitle: const Text('关闭页面切换和状态动画'),
                  value: controller.reduceMotion,
                  onChanged: (value) async {
                    await controller.setReduceMotion(value);
                    if (!context.mounted) return;
                    await AppHaptics.selection(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final palette = context.colors;
    return ListView(
      key: const PageStorageKey('profile'),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
      children: [
        Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: palette.primary.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_rounded,
                color: palette.primary,
                size: 31,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    controller.displayName,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontSize: 19),
                  ),
                  const SizedBox(height: 3),
                  Text('数据保存在本机', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            IconButton.outlined(
              key: const Key('edit-profile-name'),
              tooltip: '编辑昵称',
              onPressed: () => _editName(context),
              icon: const Icon(Icons.edit_rounded),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _Metric(
                value: '${controller.practiceDates.length}',
                label: '练习天数',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Metric(
                value: '${controller.practiceMinutes}',
                label: '练习分钟',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Metric(value: '${controller.bestScore}', label: '最高得分'),
            ),
          ],
        ),
        const SizedBox(height: 28),
        const SectionLabel('练习设置'),
        const SizedBox(height: 9),
        Card(
          child: Column(
            children: [
              ListTile(
                key: const Key('harmonica-key-setting'),
                leading: const Icon(Icons.piano_rounded),
                title: const Text('我的口琴'),
                subtitle: const Text('影响课程、调音和示范音'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${controller.harmonicaKey} 调',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Icon(Icons.chevron_right_rounded, color: palette.muted),
                  ],
                ),
                onTap: () => _chooseKey(context),
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const Icon(Icons.vibration_rounded),
                title: const Text('触感反馈'),
                subtitle: const Text('切换选项和完成练习时振动'),
                value: controller.hapticsEnabled,
                onChanged: (value) async {
                  await AppHaptics.selection(context);
                  await controller.setHapticsEnabled(value);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const SectionLabel('显示与隐私'),
        const SizedBox(height: 9),
        Card(
          child: Column(
            children: [
              ListTile(
                key: const Key('accessibility-setting'),
                leading: const Icon(Icons.accessibility_new_rounded),
                title: const Text('无障碍与显示'),
                subtitle: Text(
                  '${(controller.textScale * 100).round()}% 文字'
                  '${controller.highContrast ? ' · 高对比度' : ''}'
                  '${controller.reduceMotion ? ' · 减少动态' : ''}',
                ),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: palette.muted,
                ),
                onTap: () => _showAccessibility(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.lock_outline_rounded),
                title: const Text('本机数据与隐私'),
                subtitle: const Text('查看或清除练习数据'),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: palette.muted,
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const LocalDataScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const PrivacyNote(),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: context.colors.primary,
                fontSize: 25,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
