import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../localization/app_strings.dart';
import '../models/harmonica_layout.dart';
import '../models/pitch_reading.dart';
import '../models/song_score.dart';
import '../services/guide_tone_service.dart';
import '../services/haptics.dart';
import '../services/pitch_service.dart';
import '../state/app_controller.dart';
import '../theme/app_adaptive.dart';
import '../theme/app_theme.dart';
import '../widgets/cute_illustrations.dart';
import '../widgets/shared_widgets.dart';

/// 第 07 课：1–2–3 孔和弦与节奏
/// 不强行用单音音分判定，而是采用「节奏拍点 + 气息音量包络检测 + 示范音对比」。
class ChordRhythmLessonScreen extends StatefulWidget {
  const ChordRhythmLessonScreen({super.key});

  @override
  State<ChordRhythmLessonScreen> createState() =>
      _ChordRhythmLessonScreenState();
}

class _ChordRhythmLessonScreenState extends State<ChordRhythmLessonScreen> {
  static const _targetBars = 2;

  final _pitchService = PitchService();
  final _guideToneService = GuideToneService();

  StreamSubscription<PitchReading>? _subscription;
  Timer? _beatTimer;
  Timer? _demoTimer;

  int _bpm = 72;
  bool _listening = false;
  bool _demoPlaying = false;
  bool _completed = false;
  String? _errorMessage;

  // 4-beat groove: 0 = Blow 1-3↑, 1 = Rest, 2 = Draw 1-3↓, 3 = Rest
  int _currentBeat = 0;
  bool _blowBeatHit = false;
  bool _drawBeatHit = false;
  int _completedBars = 0;
  double _liveLevelDb = -60;
  bool _lastBeatHitFlash = false;
  double _activeThresholdDb = -37.9;
  int _restBleedCount = 0;
  bool _restBleedThisBeat = false;
  int _rhythmScore = 96;

  static double _envelopeThresholdDbFor(double sensitivity) =>
      -26.0 - sensitivity * 17.5;

  @override
  void dispose() {
    _beatTimer?.cancel();
    _demoTimer?.cancel();
    _subscription?.cancel();
    unawaited(_pitchService.stop());
    unawaited(_guideToneService.stop());
    super.dispose();
  }

  Future<void> _toggleDemo() async {
    if (_demoPlaying) {
      _demoTimer?.cancel();
      await _guideToneService.stop();
      if (mounted) setState(() => _demoPlaying = false);
      return;
    }

    if (_listening) {
      await _stopListening();
    }
    if (!mounted) return;

    final key = AppScope.maybeRead(context)?.harmonicaKey ?? 'C';
    // 1-2-3 孔吹气主和弦分解音 + 1-2-3 孔吸气属和弦分解音（按当前口琴调性换算）
    final freqs = [
      harmonicaHoleInfo(1, isBlow: true).frequencyForKey(key),
      harmonicaHoleInfo(2, isBlow: true).frequencyForKey(key),
      harmonicaHoleInfo(3, isBlow: true).frequencyForKey(key),
      harmonicaHoleInfo(1, isBlow: false).frequencyForKey(key),
      harmonicaHoleInfo(2, isBlow: false).frequencyForKey(key),
      harmonicaHoleInfo(3, isBlow: false).frequencyForKey(key),
    ];

    try {
      setState(() {
        _demoPlaying = true;
        _errorMessage = null;
      });
      final durationMs = await _guideToneService.play(
        frequencies: freqs,
        speed: _bpm >= 90 ? 1.0 : 0.75,
        repeat: false,
      );
      if (!mounted) return;
      _demoTimer?.cancel();
      _demoTimer = Timer(Duration(milliseconds: durationMs + 150), () {
        if (mounted) setState(() => _demoPlaying = false);
      });
    } on PlatformException {
      if (!mounted) return;
      setState(() {
        _demoPlaying = false;
        _errorMessage = context.strings.t('featureUnavailable');
      });
    }
  }

  Future<void> _togglePractice() async {
    if (_listening) {
      await _stopListening();
      return;
    }
    if (_demoPlaying) {
      _demoTimer?.cancel();
      await _guideToneService.stop();
      if (!mounted) return;
      setState(() => _demoPlaying = false);
    }

    unawaited(AppHaptics.selection(context));
    setState(() => _errorMessage = null);

    MicrophonePermission permission;
    try {
      permission = await _pitchService.requestPermission();
    } on PlatformException {
      if (!mounted) return;
      setState(() => _errorMessage = context.strings.t('regDetectUnsupported'));
      return;
    }
    if (!mounted) return;
    if (permission == MicrophonePermission.denied) {
      setState(() => _errorMessage = context.strings.t('regDetectDenied'));
      return;
    }
    if (permission == MicrophonePermission.permanentlyDenied) {
      setState(() => _errorMessage = context.strings.t('regDetectPermDenied'));
      return;
    }

    final sensitivity =
        AppScope.maybeRead(context)?.microphoneSensitivity ?? 0.68;
    _activeThresholdDb = _envelopeThresholdDbFor(sensitivity);
    _subscription ??= _pitchService.readings.listen(
      _onReading,
      onError: (Object _) => unawaited(_handleAudioError()),
    );

    bool started;
    try {
      started = await _pitchService.start(sensitivity: sensitivity);
    } on PlatformException {
      if (!mounted) return;
      setState(() => _errorMessage = context.strings.t('regDetectUnsupported'));
      return;
    }
    if (!mounted) return;
    if (!started) {
      setState(
        () => _errorMessage = context.strings.t('microphoneSettingsError'),
      );
      return;
    }

    setState(() {
      _listening = true;
      _completed = false;
      _currentBeat = 0;
      _blowBeatHit = false;
      _drawBeatHit = false;
      _completedBars = 0;
      _liveLevelDb = -60;
      _lastBeatHitFlash = false;
      _restBleedCount = 0;
      _restBleedThisBeat = false;
      _rhythmScore = 96;
    });

    _startBeatClock();
    await AppHaptics.light(context);
  }

  void _startBeatClock() {
    _beatTimer?.cancel();
    final beatMs = (60000 / _bpm).round();
    _beatTimer = Timer.periodic(Duration(milliseconds: beatMs), (_) {
      if (!mounted || !_listening || _completed) return;
      final nextBeat = (_currentBeat + 1) % 4;
      if (nextBeat == 0) {
        final barSuccess = _blowBeatHit && _drawBeatHit;
        if (barSuccess) {
          _completedBars++;
          if (_completedBars >= _targetBars) {
            unawaited(_finishLesson());
            return;
          }
          unawaited(AppHaptics.success(context));
        }
        if (AppScope.maybeRead(context)?.metronomeEnabled ?? true) {
          unawaited(_guideToneService.playMetronomeClick(accent: true));
        }
        setState(() {
          _currentBeat = 0;
          _blowBeatHit = false;
          _drawBeatHit = false;
          _lastBeatHitFlash = false;
          _restBleedThisBeat = false;
        });
      } else {
        if (AppScope.maybeRead(context)?.metronomeEnabled ?? true) {
          unawaited(_guideToneService.playMetronomeClick(accent: false));
        }
        setState(() {
          _currentBeat = nextBeat;
          _lastBeatHitFlash = false;
          _restBleedThisBeat = false;
        });
      }
    });
  }

  void _onReading(PitchReading reading) {
    if (!mounted || !_listening || _completed) return;
    final hasEnvelope = reading.levelDb >= _activeThresholdDb;
    var hitNow = false;

    if (hasEnvelope) {
      if (_currentBeat == 0 && !_blowBeatHit) {
        _blowBeatHit = true;
        hitNow = true;
      } else if (_currentBeat == 2 && !_drawBeatHit) {
        _drawBeatHit = true;
        hitNow = true;
      } else if ((_currentBeat == 1 || _currentBeat == 3) &&
          !_restBleedThisBeat) {
        _restBleedThisBeat = true;
        _restBleedCount++;
      }
    }

    setState(() {
      _liveLevelDb = reading.levelDb;
      if (hitNow) _lastBeatHitFlash = true;
    });

    if (hitNow) {
      unawaited(AppHaptics.light(context));
      // If both beats in the final bar are already locked, finish right away
      if (_blowBeatHit && _drawBeatHit && _completedBars + 1 >= _targetBars) {
        _completedBars = _targetBars;
        unawaited(_finishLesson());
      }
    }
  }

  Future<void> _finishLesson() async {
    _beatTimer?.cancel();
    await _pitchService.stop();
    if (!mounted) return;
    _rhythmScore = (100 - _restBleedCount * 12).clamp(60, 100).toInt();
    final controller = AppScope.read(context);
    await controller.markLessonComplete('lesson_chord', score: _rhythmScore);
    await controller.recordPractice(seconds: 45, score: _rhythmScore);
    if (!mounted) return;
    setState(() {
      _listening = false;
      _completed = true;
    });
    await AppHaptics.success(context);
  }

  Future<void> _handleAudioError() async {
    _beatTimer?.cancel();
    await _pitchService.stop();
    if (!mounted) return;
    setState(() {
      _listening = false;
      _errorMessage = context.strings.t('microphoneReadError');
    });
  }

  Future<void> _stopListening() async {
    _beatTimer?.cancel();
    await _pitchService.stop();
    if (!mounted) return;
    setState(() {
      _listening = false;
      _liveLevelDb = -60;
    });
  }

  double get _normalizedEnvelope =>
      ((_liveLevelDb + 58) / 42).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final palette = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final pagePadding = AppAdaptive.pagePadding(context);

    final isBlowBeat = _currentBeat == 0;
    final isDrawBeat = _currentBeat == 2;
    final birdMood = _completed
        ? ChumingMood.celebrating
        : !_listening
        ? ChumingMood.idle
        : isBlowBeat
        ? ChumingMood.blowing
        : isDrawBeat
        ? ChumingMood.drawing
        : ChumingMood.listening;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.lessonTitle('lesson_chord')),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(pagePadding, 12, pagePadding, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Overview card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: palette.outline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ChumingBird(
                          size: 46,
                          mood: birdMood,
                          interactive: false,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            strings.t('chordHeroTitle'),
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      strings.t('chordHeroSubtitle'),
                      style: textTheme.bodySmall?.copyWith(
                        color: palette.muted,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 1-2-3 Hole Chord Visual Highlight Bar
              Container(
                key: const Key('chord-holes-bar'),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: palette.outline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Text(
                          strings.t('chordHolesLabel'),
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SegmentedButton<int>(
                          segments: const [
                            ButtonSegment(value: 72, label: Text('72 BPM')),
                            ButtonSegment(value: 90, label: Text('90 BPM')),
                          ],
                          selected: {_bpm},
                          showSelectedIcon: false,
                          onSelectionChanged: (val) {
                            setState(() => _bpm = val.first);
                            if (_listening) _startBeatClock();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: List.generate(10, (index) {
                        final hole = index + 1;
                        final inChord = hole <= 3;
                        final highlightColor = isDrawBeat
                            ? palette.accent
                            : palette.primary;
                        return Expanded(
                          child: Container(
                            height: 36,
                            margin: const EdgeInsets.symmetric(horizontal: 1.5),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: inChord
                                  ? highlightColor
                                  : palette.surfaceHigh,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '$hole',
                                style: textTheme.labelMedium?.copyWith(
                                  color: inChord ? Colors.white : palette.muted,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 4-Beat Groove & Breath Envelope Card
              Container(
                key: const Key('chord-rhythm-card'),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _completed
                        ? palette.success
                        : _listening
                        ? palette.primary
                        : palette.outline,
                    width: _listening || _completed ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          strings.t('chordBarsProgress', {
                            'done': _completedBars,
                            'total': _targetBars,
                          }),
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (_lastBeatHitFlash)
                          Text(
                            strings.t('chordHitFeedback'),
                            style: textTheme.labelMedium?.copyWith(
                              color: palette.success,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: List.generate(4, (beat) {
                        final active = _listening && _currentBeat == beat;
                        final isBlow = beat == 0;
                        final isDraw = beat == 2;
                        final isHit =
                            (isBlow && _blowBeatHit) ||
                            (isDraw && _drawBeatHit);
                        final label = isBlow
                            ? strings.t('blow')
                            : isDraw
                            ? strings.t('draw')
                            : strings.t('chordRestLabel');
                        final color = isHit
                            ? palette.success
                            : isBlow
                            ? palette.primary
                            : isDraw
                            ? palette.accent
                            : palette.muted;
                        return Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 4,
                            ),
                            decoration: BoxDecoration(
                              color: active || isHit
                                  ? color.withValues(alpha: 0.14)
                                  : palette.surfaceHigh,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: active || isHit
                                    ? color
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '${beat + 1}',
                                  style: textTheme.titleSmall?.copyWith(
                                    color: color,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    label,
                                    style: textTheme.labelSmall?.copyWith(
                                      color: color,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      strings.t('chordEnvelopeLabel'),
                      style: textTheme.labelMedium?.copyWith(
                        color: palette.muted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        key: const Key('chord-envelope-meter'),
                        value: _listening ? _normalizedEnvelope : 0,
                        minHeight: 10,
                        color: _normalizedEnvelope >= 0.45
                            ? palette.success
                            : palette.primary,
                        backgroundColor: palette.surfaceHigh,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _completed
                          ? strings.t('chordDoneBody')
                          : strings.t('chordWaitingBeat'),
                      style: textTheme.bodySmall?.copyWith(
                        color: _completed ? palette.success : palette.muted,
                        fontWeight: _completed
                            ? FontWeight.w700
                            : FontWeight.normal,
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _errorMessage!,
                        style: textTheme.bodySmall?.copyWith(
                          color: palette.danger,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (_completed) ...[
                FilledButton.icon(
                  key: const Key('chord-share-achievement'),
                  onPressed: () => showAchievementCardSheet(
                    context,
                    title: strings.lessonTitle('lesson_chord'),
                    score: _rhythmScore,
                    tabPreview: '1-2-3↑ · 1-2-3↓',
                    grade: gradeForSongScore(_rhythmScore).label,
                    stars: starsForSongScore(_rhythmScore),
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  icon: const Icon(Icons.emoji_events_rounded),
                  label: Text(strings.t('shareAchievementBtn')),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _togglePractice,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                  ),
                  child: Text(strings.t('chordStartPractice')),
                ),
              ] else ...[
                FilledButton.icon(
                  key: const Key('chord-start-practice'),
                  onPressed: _togglePractice,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  icon: Icon(
                    _listening ? Icons.stop_rounded : Icons.mic_rounded,
                  ),
                  label: Text(
                    strings.t(
                      _listening ? 'chordStopPractice' : 'chordStartPractice',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  key: const Key('chord-play-demo'),
                  onPressed: _toggleDemo,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                  ),
                  icon: Icon(
                    _demoPlaying
                        ? Icons.stop_rounded
                        : Icons.volume_up_rounded,
                  ),
                  label: Text(
                    strings.t(_demoPlaying ? 'chordStopDemo' : 'chordPlayDemo'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
