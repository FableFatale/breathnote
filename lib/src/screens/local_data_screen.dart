import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../localization/app_strings.dart';
import '../services/haptics.dart';
import '../services/score_file_picker.dart';
import '../services/share_service.dart';
import '../state/app_controller.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import 'legal_document_screen.dart';

class LocalDataScreen extends StatelessWidget {
  const LocalDataScreen({
    this.shareService = const ShareService(),
    this.filePickerService = const ScoreFilePickerService(),
    super.key,
  });

  final ShareService shareService;
  final ScoreFilePickerService filePickerService;

  void _showMessage(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _exportBackup(BuildContext context) async {
    final controller = AppScope.read(context);
    final strings = context.strings;
    final jsonText = controller.exportBackupJson();
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final fileName = 'breathnote_backup_$y$m$d.json';

    final shared = await shareService.shareJsonBackup(
      content: jsonText,
      fileName: fileName,
      subject: strings.t('backupShareSubject'),
    );
    if (!context.mounted) return;
    if (shared) {
      unawaited(AppHaptics.success(context));
      _showMessage(context, strings.t('backupExported'));
      return;
    }

    await Clipboard.setData(ClipboardData(text: jsonText));
    if (!context.mounted) return;
    unawaited(AppHaptics.selection(context));
    _showMessage(context, strings.t('backupCopiedToClipboard'));
  }

  Future<void> _importFromFile(BuildContext context) async {
    final strings = context.strings;
    String? rawJson;
    try {
      rawJson = await filePickerService.pickJsonBackupFile();
    } on FormatException {
      if (!context.mounted) return;
      _showMessage(context, strings.t('backupInvalidFormat'));
      return;
    }
    if (!context.mounted) return;
    if (rawJson == null) {
      // On desktop/web test or if no plugin available vs user cancel, prompt paste option gently if empty?
      return;
    }
    await _confirmAndImportBackup(context, rawJson);
  }

  Future<void> _importFromPaste(BuildContext context) async {
    final pasted = await showDialog<String>(
      context: context,
      animationStyle: AppMotion.animationStyle(context),
      builder: (_) => const _PasteBackupDialog(),
    );
    if (pasted == null || pasted.isEmpty || !context.mounted) return;
    await _confirmAndImportBackup(context, pasted);
  }

  Future<void> _confirmAndImportBackup(
    BuildContext context,
    String rawJson,
  ) async {
    final strings = context.strings;
    final BackupPreview preview;
    try {
      preview = AppController.parseBackupPreview(rawJson);
    } on FormatException catch (error) {
      final key = error.message == 'backupUnsupportedVersion'
          ? 'backupUnsupportedVersion'
          : 'backupInvalidFormat';
      _showMessage(context, strings.t(key));
      return;
    }

    final displayName = preview.displayName == AppController.defaultDisplayName
        ? strings.t('profileDefaultName')
        : preview.displayName;
    final summary = strings.t('backupPreviewSummary', {
      'name': displayName,
      'key': preview.harmonicaKey,
      'lessons': preview.completedLessonCount,
      'songs': preview.customSongCount,
      'minutes': preview.practiceMinutes,
    });

    final confirmed = await showDialog<bool>(
      context: context,
      animationStyle: AppMotion.animationStyle(context),
      builder: (dialogContext) => AlertDialog(
        key: const Key('import-backup-confirm-dialog'),
        title: Text(strings.t('backupConfirmTitle')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(summary, style: Theme.of(dialogContext).textTheme.titleSmall),
            const SizedBox(height: 10),
            Text(
              strings.t('backupConfirmWarning'),
              style: Theme.of(dialogContext).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(strings.t('commonCancel')),
          ),
          FilledButton(
            key: const Key('confirm-import-backup'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(strings.t('backupConfirmAction')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await AppScope.read(context).importBackupJson(rawJson);
    if (!context.mounted) return;
    await AppHaptics.success(context);
    if (!context.mounted) return;
    _showMessage(context, strings.t('backupImportSuccess'));
  }

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
    final strings = context.strings;
    return Scaffold(
      appBar: AppBar(title: Text(strings.t('localDataPrivacy'))),
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
                    strings.t('audioAnalyzedOnDevice'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    strings.t('audioPrivacyDetail'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const Key('local-data-privacy-policy-btn'),
                    onPressed: () {
                      unawaited(AppHaptics.selection(context));
                      unawaited(
                        showLegalDocumentScreen(
                          context,
                          initialTab: LegalDocumentType.privacyPolicy,
                        ),
                      );
                    },
                    icon: const Icon(Icons.policy_outlined, size: 18),
                    label: Text(strings.t('viewFullPrivacyTerms')),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SectionLabel(strings.t('locallySavedContent')),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                _DataRow(
                  icon: Icons.calendar_today_rounded,
                  title: strings.t('practiceDates'),
                  value: strings.t('commonDays', {
                    'count': controller.practiceDates.length,
                  }),
                ),
                const Divider(height: 1),
                _DataRow(
                  icon: Icons.timer_outlined,
                  title: strings.t('practiceTime'),
                  value: strings.t('commonMinutes', {
                    'count': controller.practiceMinutes,
                  }),
                ),
                const Divider(height: 1),
                _DataRow(
                  icon: Icons.task_alt_rounded,
                  title: strings.t('courseProgress'),
                  value:
                      '${controller.completedLessons.length}/${AppController.totalLessonCount}',
                ),
                const Divider(height: 1),
                _DataRow(
                  icon: Icons.queue_music_rounded,
                  title: strings.t('customSongs'),
                  value: strings.t('commonSongs', {
                    'count': controller.customSongs.length,
                  }),
                ),
                const Divider(height: 1),
                _DataRow(
                  icon: Icons.leaderboard_rounded,
                  title: strings.t('localDataSongScores'),
                  value:
                      '${controller.songBestScores.length} / ${controller.songScoreHistory.length}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SectionLabel(strings.t('localBackupSection')),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    strings.t('localBackupDescription'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: palette.muted,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    key: const Key('export-backup-button'),
                    onPressed: () => _exportBackup(context),
                    icon: const Icon(Icons.upload_file_rounded, size: 19),
                    label: Text(strings.t('exportBackupButton')),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        key: const Key('import-backup-file-button'),
                        onPressed: () => _importFromFile(context),
                        icon: const Icon(Icons.folder_open_rounded, size: 18),
                        label: Text(strings.t('importBackupFileButton')),
                      ),
                      OutlinedButton.icon(
                        key: const Key('import-backup-paste-button'),
                        onPressed: () => _importFromPaste(context),
                        icon: const Icon(Icons.content_paste_rounded, size: 18),
                        label: Text(strings.t('importBackupPasteButton')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _clearData(context),
              icon: Icon(Icons.delete_outline_rounded, color: palette.muted),
              label: Text(
                strings.t('clearAllLocalData'),
                style: TextStyle(color: palette.muted),
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

class _PasteBackupDialog extends StatefulWidget {
  const _PasteBackupDialog();

  @override
  State<_PasteBackupDialog> createState() => _PasteBackupDialogState();
}

class _PasteBackupDialogState extends State<_PasteBackupDialog> {
  final TextEditingController _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return AlertDialog(
      title: Text(strings.t('backupPasteTitle')),
      content: TextField(
        key: const Key('import-backup-text-field'),
        controller: _textController,
        autofocus: true,
        maxLines: 6,
        minLines: 4,
        decoration: InputDecoration(
          hintText: strings.t('backupPasteHint'),
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(strings.t('commonCancel')),
        ),
        FilledButton(
          key: const Key('import-backup-parse-button'),
          onPressed: () =>
              Navigator.pop(context, _textController.text.trim()),
          child: Text(strings.t('backupParseAction')),
        ),
      ],
    );
  }
}
