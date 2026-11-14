import 'dart:async';

import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../models/harmonica_layout.dart';
import '../services/guide_tone_service.dart';
import '../services/haptics.dart';
import '../state/app_controller.dart';
import '../theme/app_adaptive.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';
import '../widgets/chuming_coach.dart';
import '../widgets/cute_illustrations.dart';
import '../widgets/harmonica_guide.dart' show showHarmonicaGuide;
import '../widgets/shared_widgets.dart';
import 'lesson_routes.dart';

class LessonDetailScreen extends StatefulWidget {
  const LessonDetailScreen({super.key});

  @override
  State<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen> {
  final _guideToneService = GuideToneService();
  Timer? _toneTimer;
  bool _completing = false;
  bool _playingHoleTone = false;
  int _selectedHole = 4;
  bool _isBlow = true;

  @override
  void deactivate() {
    _toneTimer?.cancel();
    super.deactivate();
  }

  @override
  void dispose() {
    _toneTimer?.cancel();
    unawaited(_guideToneService.stop());
    super.dispose();
  }

  void _selectHole(int hole, {bool? isBlow}) {
    final nextHole = hole.clamp(1, 10);
    final nextBlow = isBlow ?? _isBlow;
    setState(() {
      _selectedHole = nextHole;
      _isBlow = nextBlow;
    });
  }

  void _stepHole(int delta) {
    final nextHole = (_selectedHole + delta).clamp(1, 10);
    if (nextHole == _selectedHole) return;
    unawaited(AppHaptics.reedResonance(context));
    setState(() => _selectedHole = nextHole);
  }

  Future<void> _playCurrentHoleTone() async {
    if (!mounted) return;
    unawaited(AppHaptics.reedResonance(context));
    _toneTimer?.cancel();
    if (_playingHoleTone) {
      await _guideToneService.stop();
      if (!mounted) return;
      setState(() => _playingHoleTone = false);
      return;
    }

    final key = AppScope.maybeRead(context)?.harmonicaKey ?? 'C';
    final info = harmonicaHoleInfo(_selectedHole, isBlow: _isBlow);
    setState(() => _playingHoleTone = true);
    try {
      final duration = await _guideToneService.play(
        frequencies: [info.frequencyForKey(key)],
        speed: 1.0,
        repeat: false,
      );
      if (!mounted) return;
      _toneTimer = Timer(Duration(milliseconds: duration + 80), () {
        if (!mounted) return;
        setState(() => _playingHoleTone = false);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _playingHoleTone = false);
    }
  }

  Future<void> _complete(BuildContext context) async {
    if (_completing || !mounted) return;
    final controller = AppScope.maybeRead(context);
    if (controller == null) return;
    setState(() => _completing = true);
    await controller.markLessonComplete('lesson_1');
    if (!context.mounted) return;
    await AppHaptics.success(context);
    if (!context.mounted) return;
    setState(() => _completing = false);
  }

  void _openGuide(BuildContext context) {
    unawaited(AppHaptics.selection(context));
    showHarmonicaGuide(
      context,
      skipIsClose: true,
      onSkip: () {},
      onComplete: () {},
    );
  }

  void _openNextLesson(BuildContext context) {
    unawaited(AppHaptics.selection(context));
    Navigator.of(context)
        .pushReplacement(lessonRoute(context, lessonById('lesson_2')));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final controller = AppScope.of(context);
    final strings = context.strings;
    final lang = strings.languageCode;
    final completed = controller.completedLessons.contains('lesson_1');
    final pagePadding = AppAdaptive.pagePadding(context);
    final cardPadding = AppAdaptive.cardPadding(context);
    final currentInfo = harmonicaHoleInfo(_selectedHole, isBlow: _isBlow);
    final activeTab = '$_selectedHole${_isBlow ? '↑' : '↓'}';

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.lessonTitle('lesson_1')),
        actions: [
          if (controller.seenCoachTips.contains('lesson_1'))
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () {
                  unawaited(AppHaptics.reedResonance(context));
                  unawaited(controller.reopenCoachTip('lesson_1'));
                },
                child: ChumingBird(
                  size: 32,
                  mood: _isBlow ? ChumingMood.blowing : ChumingMood.drawing,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(pagePadding, 8, pagePadding, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          const ChumingCoachBanner(
            featureId: 'lesson_1',
            messageKey: 'coachLesson1',
            mood: ChumingMood.idle,
          ),
          Card(
            child: Padding(
              padding: EdgeInsets.all(cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.t('tenHoleHarmonica'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    strings.t('harmonicaIntro'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _ZoneChip(
                          label: strings.t('zoneMiddleShort'),
                          selected:
                              _selectedHole >= 4 && _selectedHole <= 7,
                          onTap: () {
                            unawaited(AppHaptics.selection(context));
                            _selectHole(4, isBlow: true);
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _ZoneChip(
                          label: strings.t('zoneLowShort'),
                          selected: _selectedHole <= 3,
                          onTap: () {
                            unawaited(AppHaptics.selection(context));
                            _selectHole(1, isBlow: true);
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _ZoneChip(
                          label: strings.t('zoneHighShort'),
                          selected: _selectedHole >= 8,
                          onTap: () {
                            unawaited(AppHaptics.selection(context));
                            _selectHole(8, isBlow: true);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _BreathDirectionButton(
                          key: const Key('lesson-1-blow-toggle'),
                          label: strings.t('blow'),
                          selected: _isBlow,
                          isBlow: true,
                          onTap: () {
                            unawaited(AppHaptics.selection(context));
                            setState(() => _isBlow = true);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _BreathDirectionButton(
                          key: const Key('lesson-1-draw-toggle'),
                          label: strings.t('draw'),
                          selected: !_isBlow,
                          isBlow: false,
                          onTap: () {
                            unawaited(AppHaptics.selection(context));
                            setState(() => _isBlow = false);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  HarmonicaDiagram(
                    activeTab: activeTab,
                    onHoleTap: (hole) => _selectHole(hole),
                  ),
                  const SizedBox(height: 14),
                  _HoleMeaningDetailCard(
                    info: currentInfo,
                    harmonicaKey: controller.harmonicaKey,
                    lang: lang,
                    playingTone: _playingHoleTone,
                    canPrev: _selectedHole > 1,
                    canNext: _selectedHole < 10,
                    onPrev: () => _stepHole(-1),
                    onNext: () => _stepHole(1),
                    onPlayTone: _playCurrentHoleTone,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _HoleQuickReferenceCard(
            selectedHole: _selectedHole,
            isBlow: _isBlow,
            onSelect: (hole, blow) {
              unawaited(AppHaptics.reedResonance(context));
              _selectHole(hole, isBlow: blow);
            },
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            key: const Key('lesson-1-guide'),
            onPressed: () => _openGuide(context),
            icon: const Icon(Icons.front_hand_outlined),
            label: Text(strings.t('guideReopen')),
          ),
          const SizedBox(height: 20),
          Text(
            strings.t('postureSectionTitle'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: cardPadding),
              child: Column(
                children: [
                  _Instruction(
                    number: '1',
                    title: strings.t('holdNaturally'),
                    detail: strings.t('holdNaturallyDetail'),
                    color: palette.primary,
                  ),
                  Divider(height: 1, color: palette.outline),
                  _Instruction(
                    number: '2',
                    title: strings.t('relaxLips'),
                    detail: strings.t('relaxLipsDetail'),
                    color: palette.primary,
                  ),
                  Divider(height: 1, color: palette.outline),
                  _Instruction(
                    number: '3',
                    title: strings.t('bellyBreathing'),
                    detail: strings.t('bellyBreathingDetail'),
                    color: palette.primary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          AnimatedSwitcher(
            duration: AppMotion.duration(context, AppMotion.base),
            child: completed
                ? _CompletedAction(
                    key: const ValueKey('lesson-1-complete'),
                    onNext: () => _openNextLesson(context),
                  )
                : SizedBox(
                    key: const ValueKey('lesson-1-action'),
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _completing ? null : () => _complete(context),
                      icon: const Icon(Icons.check_rounded),
                      label: Text(strings.t('completeLesson')),
                    ),
                  ),
          ),
        ],
        ),
      ),
    );
  }
}

class _ZoneChip extends StatelessWidget {
  const _ZoneChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Material(
      color: selected
          ? palette.primary.withValues(alpha: 0.12)
          : palette.surfaceHigh,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? palette.primary : palette.outline,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                color: selected ? palette.primary : palette.text,
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BreathDirectionButton extends StatelessWidget {
  const _BreathDirectionButton({
    required this.label,
    required this.selected,
    required this.isBlow,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final bool isBlow;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final activeColor = isBlow ? palette.primary : palette.accentInk;
    return Material(
      color: selected
          ? activeColor.withValues(alpha: 0.12)
          : palette.surfaceHigh,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? activeColor : palette.outline,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? activeColor : palette.muted,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _HoleMeaningDetailCard extends StatelessWidget {
  const _HoleMeaningDetailCard({
    required this.info,
    required this.harmonicaKey,
    required this.lang,
    required this.playingTone,
    required this.canPrev,
    required this.canNext,
    required this.onPrev,
    required this.onNext,
    required this.onPlayTone,
  });

  final HarmonicaHoleInfo info;
  final String harmonicaKey;
  final String lang;
  final bool playingTone;
  final bool canPrev;
  final bool canNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onPlayTone;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final strings = context.strings;
    final noteName = info.noteLabelForKey(harmonicaKey);
    final accentColor = info.isBlow ? palette.primary : palette.accentInk;

    return AnimatedContainer(
      duration: AppMotion.duration(context, AppMotion.fast),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surfaceHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  info.tab,
                  style: TextStyle(
                    color: palette.onPrimary,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                info.roleTitle(lang),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 15,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: palette.outline),
                ),
                child: Text(
                  '$harmonicaKey 调: $noteName',
                  style: TextStyle(
                    color: palette.muted,
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            info.zoneLabel(lang),
            style: TextStyle(
              color: accentColor,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            info.beginnerMeaning(lang),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('lesson-1-prev-hole'),
                  onPressed: canPrev ? onPrev : null,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    minimumSize: const Size(0, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.chevron_left_rounded, size: 18),
                        const SizedBox(width: 2),
                        Text(strings.t('prevHole')),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonal(
                  key: const Key('lesson-1-play-hole'),
                  onPressed: onPlayTone,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    minimumSize: const Size(0, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          playingTone
                              ? Icons.stop_rounded
                              : Icons.volume_up_rounded,
                          size: 17,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          strings.t(
                            playingTone
                                ? 'playingHoleSound'
                                : 'listenHoleSound',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  key: const Key('lesson-1-next-hole'),
                  onPressed: canNext ? onNext : null,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    minimumSize: const Size(0, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(strings.t('nextHole')),
                        const SizedBox(width: 2),
                        const Icon(Icons.chevron_right_rounded, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HoleQuickReferenceCard extends StatelessWidget {
  const _HoleQuickReferenceCard({
    required this.selectedHole,
    required this.isBlow,
    required this.onSelect,
  });

  final int selectedHole;
  final bool isBlow;
  final void Function(int hole, bool blow) onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final strings = context.strings;
    final cardPadding = AppAdaptive.cardPadding(context);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.t('holeQuickMapTitle'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                SizedBox(
                  width: 34,
                  child: Text(
                    strings.t('blowShort'),
                    style: TextStyle(
                      color: palette.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                for (var hole = 1; hole <= 10; hole++)
                  Expanded(
                    child: _QuickMapCell(
                      hole: hole,
                      blow: true,
                      label: harmonicaHoleInfo(hole, isBlow: true).solfege,
                      selected: selectedHole == hole && isBlow,
                      onTap: () => onSelect(hole, true),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                SizedBox(
                  width: 34,
                  child: Text(
                    strings.t('drawShort'),
                    style: TextStyle(
                      color: palette.accentInk,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                for (var hole = 1; hole <= 10; hole++)
                  Expanded(
                    child: _QuickMapCell(
                      hole: hole,
                      blow: false,
                      label: harmonicaHoleInfo(hole, isBlow: false).solfege,
                      selected: selectedHole == hole && !isBlow,
                      onTap: () => onSelect(hole, false),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickMapCell extends StatelessWidget {
  const _QuickMapCell({
    required this.hole,
    required this.blow,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final int hole;
  final bool blow;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final activeColor = blow ? palette.primary : palette.accentInk;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 1),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? activeColor.withValues(alpha: 0.14)
              : palette.surfaceHigh,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? activeColor : palette.outline,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$hole',
              style: TextStyle(
                color: selected ? activeColor : palette.muted,
                fontSize: 9,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? activeColor : palette.text,
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletedAction extends StatelessWidget {
  const _CompletedAction({required this.onNext, super.key});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle_rounded, color: context.colors.success),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.strings.t('lessonComplete'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('lesson-1-next'),
          onPressed: onNext,
          child: Text(context.strings.t('nextLesson')),
        ),
      ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
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
    );
  }
}
