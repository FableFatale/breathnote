import 'dart:async';

import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../services/haptics.dart';
import '../state/app_controller.dart';
import '../theme/app_motion.dart';
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
    final strings = context.strings;
    final fieldController = TextEditingController(
      text: controller.displayName == AppController.defaultDisplayName
          ? strings.t('profileDefaultName')
          : controller.displayName,
    );
    final value = await showDialog<String>(
      context: context,
      animationStyle: AppMotion.animationStyle(context),
      builder: (context) => AlertDialog(
        title: Text(strings.t('editNickname')),
        content: TextField(
          key: const Key('profile-name-field'),
          controller: fieldController,
          autofocus: true,
          maxLength: 20,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(labelText: strings.t('localNickname')),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(strings.t('commonCancel')),
          ),
          FilledButton(
            key: const Key('save-profile-name'),
            onPressed: () => Navigator.pop(context, fieldController.text),
            child: Text(strings.t('commonSave')),
          ),
        ],
      ),
    );
    if (value == null || value.trim().isEmpty || !context.mounted) return;
    if (controller.displayName == AppController.defaultDisplayName &&
        value.trim() == strings.t('profileDefaultName')) {
      return;
    }
    await controller.setDisplayName(value);
    if (!context.mounted) return;
    await AppHaptics.success(context);
  }

  Future<void> _chooseKey(BuildContext context) async {
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
                      key: Key('harmonica-key-$key'),
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

  Future<void> _showAccessibility(BuildContext context) async {
    unawaited(AppHaptics.selection(context));
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      sheetAnimationStyle: AppMotion.animationStyle(
        context,
        duration: AppMotion.slow,
        reverseDuration: AppMotion.base,
      ),
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
                  context.strings.t('accessibilityDisplay'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 18),
                Text(
                  context.strings.t('textSize'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
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
                  title: Text(context.strings.t('highContrast')),
                  subtitle: Text(context.strings.t('highContrastDetail')),
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
                  title: Text(context.strings.t('reduceMotion')),
                  subtitle: Text(context.strings.t('reduceMotionDetail')),
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

  Future<void> _showAppearanceLanguage(BuildContext context) async {
    unawaited(AppHaptics.selection(context));
    await showModalBottomSheet<void>(
      context: context,
      sheetAnimationStyle: AppMotion.animationStyle(
        context,
        duration: AppMotion.slow,
        reverseDuration: AppMotion.base,
      ),
      builder: (context) {
        final controller = AppScope.of(context);
        final strings = context.strings;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.t('appearanceLanguage'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 20),
                Text(
                  strings.t('theme'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    segments: [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text(strings.t('themeSystem')),
                        icon: const Icon(Icons.brightness_auto_rounded),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text(strings.t('themeLight')),
                        icon: const Icon(Icons.light_mode_rounded),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text(strings.t('themeDark')),
                        icon: const Icon(Icons.dark_mode_rounded),
                      ),
                    ],
                    selected: {controller.themeMode},
                    showSelectedIcon: false,
                    onSelectionChanged: (value) async {
                      await controller.setThemeMode(value.first);
                      if (!context.mounted) return;
                      await AppHaptics.selection(context);
                    },
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  strings.t('language'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    key: const Key('language-selector'),
                    segments: [
                      ButtonSegment(
                        value: 'zh',
                        label: Text(strings.t('languageChinese')),
                      ),
                      ButtonSegment(
                        value: 'en',
                        label: Text(strings.t('languageEnglish')),
                      ),
                      ButtonSegment(
                        value: 'ja',
                        label: Text(strings.t('languageJapanese')),
                      ),
                    ],
                    selected: {controller.languageCode},
                    showSelectedIcon: false,
                    onSelectionChanged: (value) async {
                      await controller.setLanguageCode(value.first);
                      if (!context.mounted) return;
                      await AppHaptics.selection(context);
                    },
                  ),
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
    final strings = context.strings;
    final displayName =
        controller.displayName == AppController.defaultDisplayName
        ? strings.t('profileDefaultName')
        : controller.displayName;
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
                    displayName,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontSize: 19),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    strings.t('localOnly'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton.outlined(
              key: const Key('edit-profile-name'),
              tooltip: strings.t('editNickname'),
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
                label: strings.t('practiceDays'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Metric(
                value: '${controller.practiceMinutes}',
                label: strings.t('practiceMinutes'),
                suffix: strings.t('minuteUnit'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Metric(
                value: '${controller.bestScore}',
                label: strings.t('bestScore'),
                suffix: '/ 100',
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        SectionLabel(strings.t('practiceSettings')),
        const SizedBox(height: 9),
        Card(
          child: Column(
            children: [
              ListTile(
                key: const Key('harmonica-key-setting'),
                leading: const Icon(Icons.piano_rounded),
                title: Text(strings.t('myHarmonica')),
                subtitle: Text(strings.t('harmonicaSettingDetail')),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      strings.t('keyName', {'key': controller.harmonicaKey}),
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
                title: Text(strings.t('haptics')),
                subtitle: Text(strings.t('hapticsDetail')),
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
        SectionLabel(strings.t('appearanceLanguage')),
        const SizedBox(height: 9),
        Card(
          child: Column(
            children: [
              ListTile(
                key: const Key('appearance-language-setting'),
                leading: const Icon(Icons.palette_outlined),
                title: Text(strings.t('theme')),
                subtitle: Text(
                  strings.t('themeLanguageSummary', {
                    'theme': _themeName(strings, controller.themeMode),
                    'language': _languageName(strings, controller.languageCode),
                  }),
                ),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: palette.muted,
                ),
                onTap: () => _showAppearanceLanguage(context),
              ),
              const Divider(height: 1),
              ListTile(
                key: const Key('accessibility-setting'),
                leading: const Icon(Icons.accessibility_new_rounded),
                title: Text(strings.t('accessibilityDisplay')),
                subtitle: Text(
                  [
                    '${(controller.textScale * 100).round()}%',
                    if (controller.highContrast) strings.t('highContrast'),
                    if (controller.reduceMotion) strings.t('reduceMotion'),
                  ].join(strings.t('summarySeparator')),
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
                title: Text(strings.t('localDataPrivacy')),
                subtitle: Text(strings.t('localDataDetail')),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: palette.muted,
                ),
                onTap: () {
                  Navigator.of(context).push(
                    AppPageRoute<void>(
                      reduceMotion: AppMotion.isReduced(context),
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

  String _themeName(AppStrings strings, ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => strings.t('themeSystem'),
      ThemeMode.light => strings.t('themeLight'),
      ThemeMode.dark => strings.t('themeDark'),
    };
  }

  String _languageName(AppStrings strings, String code) {
    return switch (code) {
      'en' => strings.t('languageEnglish'),
      'ja' => strings.t('languageJapanese'),
      _ => strings.t('languageChinese'),
    };
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label, this.suffix});

  final String value;
  final String label;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
        child: Column(
          children: [
            Text.rich(
              TextSpan(
                text: value,
                style: TextStyle(
                  color: context.colors.primary,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace',
                ),
                children: [
                  if (suffix != null)
                    TextSpan(
                      text: ' ${suffix!}',
                      style: TextStyle(
                        color: context.colors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 34,
              child: Text(
                label,
                maxLines: 2,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
