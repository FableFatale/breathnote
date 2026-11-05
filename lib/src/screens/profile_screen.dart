import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _soundCues = true;
  bool _highContrast = false;
  bool _reduceMotion = false;

  @override
  Widget build(BuildContext context) {
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
                color: AppColors.primary.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_rounded,
                color: AppColors.primary,
                size: 31,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '口琴练习者',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 3),
                  Text(
                    '本机体验中',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            OutlinedButton(onPressed: null, child: Text('登录')),
          ],
        ),
        const SizedBox(height: 24),
        Card(
          color: const Color(0xFF252538),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('息音会员'),
                const SizedBox(height: 7),
                Text(
                  '首版本免费使用',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  '当前版本不接入付费。完整课程、详细评分与同步将在后续规划。',
                  style: TextStyle(color: AppColors.muted, height: 1.45),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        const Row(
          children: [
            Expanded(
              child: _Metric(value: '3', label: '练习天数'),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _Metric(value: '24', label: '练习分钟'),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _Metric(value: '92', label: '最高得分'),
            ),
          ],
        ),
        const SizedBox(height: 28),
        const SectionLabel('练习设置'),
        const SizedBox(height: 9),
        Card(
          child: Column(
            children: [
              const _SettingTile(
                icon: Icons.piano_rounded,
                title: '我的口琴',
                trailing: 'C 调',
              ),
              const Divider(height: 1, color: AppColors.outline),
              SwitchListTile(
                secondary: const Icon(Icons.volume_up_rounded),
                title: const Text('提示音'),
                value: _soundCues,
                onChanged: (value) => setState(() => _soundCues = value),
              ),
              const Divider(height: 1, color: AppColors.outline),
              const _SettingTile(
                icon: Icons.manage_accounts_rounded,
                title: '账号与安全',
                trailing: '',
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const SectionLabel('无障碍与显示'),
        const SizedBox(height: 9),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.contrast_rounded),
                title: const Text('增强对比度'),
                value: _highContrast,
                onChanged: (value) => setState(() => _highContrast = value),
              ),
              const Divider(height: 1, color: AppColors.outline),
              SwitchListTile(
                secondary: const Icon(Icons.animation_rounded),
                title: const Text('减少动态效果'),
                value: _reduceMotion,
                onChanged: (value) => setState(() => _reduceMotion = value),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 17,
              color: AppColors.success,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '练习声音只在设备本地处理，不会上传或保存。',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
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
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 25,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing.isNotEmpty)
            Text(trailing, style: Theme.of(context).textTheme.bodySmall),
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ],
      ),
    );
  }
}
