import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../services/haptics.dart';
import '../state/app_controller.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class LocalDataScreen extends StatelessWidget {
  const LocalDataScreen({super.key});

  Future<void> _clearData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      animationStyle: AppMotion.animationStyle(context),
      builder: (context) => AlertDialog(
        title: Text(context.strings.t('clearLocalData')),
        content: Text(context.strings.t('clearLocalDataBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.strings.t('commonCancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.strings.t('confirmClear')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await AppScope.of(context).reset();
    if (!context.mounted) return;
    await AppHaptics.warning(context);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.strings.t('localDataCleared'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final palette = context.colors;
    return Scaffold(
      appBar: AppBar(title: Text(context.strings.t('localDataPrivacy'))),
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
                    context.strings.t('audioAnalyzedOnDevice'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.strings.t('audioPrivacyDetail'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SectionLabel(context.strings.t('locallySavedContent')),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                _DataRow(
                  icon: Icons.calendar_today_rounded,
                  title: context.strings.t('practiceDates'),
                  value: context.strings.t('commonDays', {
                    'count': controller.practiceDates.length,
                  }),
                ),
                const Divider(height: 1),
                _DataRow(
                  icon: Icons.timer_outlined,
                  title: context.strings.t('practiceTime'),
                  value: context.strings.t('commonMinutes', {
                    'count': controller.practiceMinutes,
                  }),
                ),
                const Divider(height: 1),
                _DataRow(
                  icon: Icons.task_alt_rounded,
                  title: context.strings.t('courseProgress'),
                  value: '${controller.completedLessons.length}/5',
                ),
                const Divider(height: 1),
                _DataRow(
                  icon: Icons.queue_music_rounded,
                  title: context.strings.t('customSongs'),
                  value: context.strings.t('commonSongs', {
                    'count': controller.customSongs.length,
                  }),
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
              label: Text(
                context.strings.t('clearAllLocalData'),
                style: TextStyle(color: palette.danger),
              ),
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
