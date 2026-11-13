import 'dart:async';

import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../services/haptics.dart';
import '../state/app_controller.dart';
import '../theme/app_adaptive.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';
import 'cute_illustrations.dart';
import 'shared_widgets.dart';

const _harmonicaKeys = [
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

Future<void> showHarmonicaKeyPicker(BuildContext context) async {
  final controller = AppScope.of(context);
  unawaited(AppHaptics.selection(context));
  final selected = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    sheetAnimationStyle: AppMotion.sheetAnimationStyle(context),
    builder: (pickerContext) {
      return SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppAdaptive.pagePadding(pickerContext),
            8,
            AppAdaptive.pagePadding(pickerContext),
            24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pickerContext.strings.t('chooseHarmonicaKey'),
                style: Theme.of(pickerContext).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                pickerContext.strings.t('chooseHarmonicaKeyDetail'),
                style: Theme.of(pickerContext).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _harmonicaKeys.map((key) {
                  return ChoiceChip(
                    key: Key('harmonica-key-$key'),
                    label: Text(
                      pickerContext.strings.t('keyName', {'key': key}),
                    ),
                    selected: controller.harmonicaKey == key,
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    onSelected: (_) => Navigator.pop(pickerContext, key),
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

Future<void> showHarmonicaGuide(
  BuildContext context, {
  required VoidCallback onSkip,
  required bool skipIsClose,
  required VoidCallback onComplete,
}) async {
  unawaited(AppScope.of(context).markHarmonicaGuideSeen());
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    sheetAnimationStyle: AppMotion.sheetAnimationStyle(context),
    builder: (sheetContext) {
      return SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppAdaptive.pagePadding(sheetContext),
            8,
            AppAdaptive.pagePadding(sheetContext),
            24,
          ),
          child: HarmonicaGuide(
            skipIsClose: skipIsClose,
            onChooseKey: () => showHarmonicaKeyPicker(sheetContext),
            onSkip: () {
              Navigator.pop(sheetContext);
              onSkip();
            },
            onComplete: () async {
              await AppScope.of(context).markLessonComplete('lesson_1');
              if (!sheetContext.mounted || !context.mounted) return;
              Navigator.pop(sheetContext);
              onComplete();
            },
          ),
        ),
      );
    },
  );
}

class HarmonicaGuide extends StatefulWidget {
  const HarmonicaGuide({
    required this.skipIsClose,
    required this.onChooseKey,
    required this.onSkip,
    required this.onComplete,
    super.key,
  });

  final bool skipIsClose;
  final Future<void> Function() onChooseKey;
  final VoidCallback onSkip;
  final Future<void> Function() onComplete;

  @override
  State<HarmonicaGuide> createState() => _HarmonicaGuideState();
}

class _HarmonicaGuideState extends State<HarmonicaGuide> {
  int _step = 1;
  bool _selectedBlow = true;

  void _selectDirection(bool blow) {
    if (_selectedBlow == blow) return;
    unawaited(AppHaptics.selection(context));
    setState(() => _selectedBlow = blow);
  }

  void _next() {
    if (_step >= 3) {
      unawaited(widget.onComplete());
      return;
    }
    setState(() {
      _step += 1;
      if (_step == 2) _selectedBlow = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final palette = context.colors;
    final controller = AppScope.of(context);
    final compact = AppAdaptive.isCompact(context);
    final steps = <(String, String)>[
      ('guideStep1', 'guideStep1Body'),
      ('guideStep2', 'guideStep2Body'),
      ('guideStep3', 'guideStep3Body'),
    ];
    final title = strings.t(steps[_step - 1].$1);
    final body = strings.t(steps[_step - 1].$2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ChumingBird(
              size: 32,
              mood: _step == 2
                  ? (_selectedBlow ? ChumingMood.blowing : ChumingMood.drawing)
                  : ChumingMood.idle,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                strings.t('guideStepTitle'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                strings.t('guideProgress', {'current': _step}),
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 12 : 20),
        AnimatedSwitcher(
          duration: AppMotion.duration(context, AppMotion.fast),
          child: Column(
            key: ValueKey('$_step-$_selectedBlow'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_step == 1)
                const _GuideDiagram(
                  key: Key('guide-harmonica-diagram'),
                  activeTab: null,
                )
              else if (_step == 2) ...[
                _DirectionChoices(
                  selectedBlow: _selectedBlow,
                  onSelect: _selectDirection,
                ),
                const SizedBox(height: 12),
                _GuideDiagram(
                  key: const Key('guide-harmonica-diagram'),
                  activeTab: _selectedBlow ? '4↑' : '4↓',
                ),
              ] else
                _GuideKeyCover(
                  key: const Key('guide-key-cover'),
                  keyLabel: strings.t('guideKeyCover', {
                    'key': controller.harmonicaKey,
                  }),
                  onChooseKey: widget.onChooseKey,
                ),
              SizedBox(height: compact ? 14 : 18),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(body, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          key: const Key('guide-next'),
          onPressed: _next,
          icon: Icon(
            _step < 3 ? Icons.arrow_forward_rounded : Icons.mic_rounded,
          ),
          label: Text(
            _step < 3 ? strings.t('commonContinue') : strings.t('guideNext'),
          ),
        ),
        const SizedBox(height: 6),
        TextButton(
          key: const Key('guide-skip'),
          onPressed: widget.onSkip,
          child: Text(
            widget.skipIsClose
                ? strings.t('guideClose')
                : strings.t('guideSkip'),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var index = 0; index < 3; index++) ...[
              Expanded(
                child: AnimatedContainer(
                  duration: AppMotion.duration(context, AppMotion.fast),
                  height: 3,
                  margin: EdgeInsets.only(right: index == 2 ? 0 : 6),
                  decoration: BoxDecoration(
                    color: index < _step ? palette.primary : palette.outline,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _DirectionChoices extends StatelessWidget {
  const _DirectionChoices({required this.selectedBlow, required this.onSelect});

  final bool selectedBlow;
  final void Function(bool blow) onSelect;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Row(
      children: [
        Expanded(
          child: Semantics(
            container: true,
            selected: selectedBlow,
            excludeSemantics: true,
            label: strings.t('blowAction'),
            child: SizedBox(
              height: 48,
              child: selectedBlow
                  ? FilledButton.icon(
                      key: const Key('guide-direction-blow'),
                      onPressed: () => onSelect(true),
                      icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                      label: Text(strings.t('blowAction')),
                    )
                  : OutlinedButton.icon(
                      key: const Key('guide-direction-blow'),
                      onPressed: () => onSelect(true),
                      icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                      label: Text(strings.t('blowAction')),
                    ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Semantics(
            container: true,
            selected: !selectedBlow,
            excludeSemantics: true,
            label: strings.t('drawAction'),
            child: SizedBox(
              height: 48,
              child: selectedBlow
                  ? OutlinedButton.icon(
                      key: const Key('guide-direction-draw'),
                      onPressed: () => onSelect(false),
                      icon: const Icon(Icons.arrow_downward_rounded, size: 20),
                      label: Text(strings.t('drawAction')),
                    )
                  : FilledButton.icon(
                      key: const Key('guide-direction-draw'),
                      onPressed: () => onSelect(false),
                      icon: const Icon(Icons.arrow_downward_rounded, size: 20),
                      label: Text(strings.t('drawAction')),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GuideDiagram extends StatelessWidget {
  const _GuideDiagram({required this.activeTab, super.key});

  final String? activeTab;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final compact = AppAdaptive.isCompact(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppAdaptive.cardPadding(context),
        compact ? 10 : 14,
        AppAdaptive.cardPadding(context),
        compact ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.outline),
      ),
      child: Column(
        children: [
          HarmonicaDiagram(activeTab: activeTab),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.strings.t('low'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                context.strings.t('high'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GuideKeyCover extends StatelessWidget {
  const _GuideKeyCover({
    required this.keyLabel,
    required this.onChooseKey,
    super.key,
  });

  final String keyLabel;
  final Future<void> Function() onChooseKey;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.outline),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: palette.surfaceHigh,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.outline),
            ),
            child: Text(
              keyLabel,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            key: const Key('guide-key-action'),
            onPressed: () => unawaited(onChooseKey()),
            icon: const Icon(Icons.tune_rounded),
            label: Text(context.strings.t('guideKeyAction')),
          ),
        ],
      ),
    );
  }
}
