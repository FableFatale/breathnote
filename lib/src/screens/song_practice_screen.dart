import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../localization/app_strings.dart';
import '../models/pitch_reading.dart';
import '../models/song.dart';
import '../services/guide_tone_service.dart';
import '../services/haptics.dart';
import '../services/pitch_service.dart';
import '../state/app_controller.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';
import '../widgets/motion_widgets.dart';
import '../widgets/shared_widgets.dart';

class SongPracticeScreen extends StatefulWidget {
  const SongPracticeScreen({required this.song, this.lessonId, super.key});

  final Song song;
  final String? lessonId;

  @override
  State<SongPracticeScreen> createState() => _SongPracticeScreenState();
}

enum _SongStatus {
  idle,
  requestingPermission,
  listening,
  denied,
  permanentlyDenied,
  error,
}

class _SongPracticeScreenState extends State<SongPracticeScreen>
    with WidgetsBindingObserver {
  final _pitchService = PitchService();
  final _guideToneService = GuideToneService();
  StreamSubscription<PitchReading>? _subscription;
  Timer? _guideTimer;
  PitchReading _reading = const PitchReading.silent();
  _SongStatus _status = _SongStatus.idle;
  DateTime? _stableSince;
  int? _stableSinceMicros;
  DateTime? _listeningStartedAt;
  Duration _activePracticeDuration = Duration.zero;
  DateTime? _lastSampleAt;
  String? _errorMessage;
  int _index = 0;
  int _score = 0;
  double _matchedError = 0;
  bool _completed = false;
  bool _finishing = false;
  bool _guidePlaying = false;
  bool _guideLoop = false;
  bool _resumeAfterGuide = false;
  double _guideSpeed = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _stopAll(resetStatus: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _guideTimer?.cancel();
    _subscription?.cancel();
    _pitchService.stop();
    _guideToneService.stop();
    super.dispose();
  }

  Future<void> _requestAndStart() async {
    if (_status == _SongStatus.requestingPermission || _completed) return;
    if (_guidePlaying) {
      _resumeAfterGuide = false;
      await _stopGuideAndResume();
    }
    if (!mounted) return;
    setState(() {
      _status = _SongStatus.requestingPermission;
      _errorMessage = null;
    });
    try {
      final permission = await _pitchService.requestPermission();
      if (!mounted) return;
      if (permission != MicrophonePermission.granted) {
        setState(() {
          _status = permission == MicrophonePermission.permanentlyDenied
              ? _SongStatus.permanentlyDenied
              : _SongStatus.denied;
        });
        return;
      }
      await _beginListening();
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _status = _SongStatus.error;
        _errorMessage =
            error.message ?? context.strings.t('microphoneStartError');
      });
    }
  }

  Future<void> _beginListening() async {
    _subscription ??= _pitchService.readings.listen(
      _onReading,
      onError: (Object _) => unawaited(_handleReadingError()),
    );
    final started = await _pitchService.start(
      sensitivity: AppScope.of(context).microphoneSensitivity,
    );
    if (!mounted) return;
    setState(() {
      _status = started ? _SongStatus.listening : _SongStatus.error;
      _errorMessage = started
          ? null
          : context.strings.t('microphoneSettingsError');
      if (started) _listeningStartedAt ??= DateTime.now();
    });
    if (started) await AppHaptics.light(context);
  }

  void _onReading(PitchReading reading) {
    if (!mounted ||
        _status != _SongStatus.listening ||
        _completed ||
        _finishing) {
      return;
    }
    final target = widget.song.notes[_index];
    final cents = target.centsFromFrequency(
      reading.frequency,
      AppScope.of(context).harmonicaKey,
    );
    final matches = reading.detected && cents.abs() <= 25;
    final now = DateTime.now();
    if (reading.detected &&
        (_lastSampleAt == null ||
            now.difference(_lastSampleAt!).inMilliseconds >= 500)) {
      _lastSampleAt = now;
      unawaited(
        AppScope.of(
          context,
        ).recordPitchAttempt(tab: target.tab, reading: reading, cents: cents),
      );
    }
    if (matches) {
      final stableLongEnough = reading.timestampMicros > 0
          ? _isStableForMicros(reading.timestampMicros)
          : _isStableForWallClock(now);
      if (stableLongEnough) {
        _advance(cents.abs());
        return;
      }
    } else {
      _stableSince = null;
      _stableSinceMicros = null;
    }
    setState(() => _reading = reading);
  }

  bool _isStableForMicros(int timestampMicros) {
    _stableSince = null;
    _stableSinceMicros ??= timestampMicros;
    return timestampMicros - _stableSinceMicros! >= 420000;
  }

  bool _isStableForWallClock(DateTime now) {
    _stableSinceMicros = null;
    _stableSince ??= now;
    return now.difference(_stableSince!).inMilliseconds >= 420;
  }

  Future<void> _advance(double error) async {
    if (_finishing) return;
    _finishing = true;
    _matchedError += error;
    if (_index < widget.song.notes.length - 1) {
      await AppHaptics.light(context);
      if (!mounted) return;
      setState(() {
        _index++;
        _reading = const PitchReading.silent();
        _stableSince = null;
        _stableSinceMicros = null;
        _lastSampleAt = null;
        _finishing = false;
      });
      return;
    }

    _completed = true;
    _pausePracticeTimer();
    _score = (100 - _matchedError / widget.song.notes.length * 1.4)
        .round()
        .clamp(0, 100)
        .toInt();
    final seconds = _activePracticeDuration.inSeconds.clamp(0, 3600).toInt();
    final futures = <Future<void>>[
      _pitchService.stop(),
      _guideToneService.stop(),
      AppScope.of(context)
          .recordPractice(seconds: seconds == 0 ? 1 : seconds, score: _score),
    ];
    if (widget.lessonId != null) {
      futures.add(AppScope.of(context).markLessonComplete(widget.lessonId!));
    }
    await Future.wait(futures);
    if (!mounted) return;
    await AppHaptics.success(context);
    if (!mounted) return;
    setState(() {
      _status = _SongStatus.idle;
      _guidePlaying = false;
      _finishing = false;
    });
  }

  Future<void> _stopAll({required bool resetStatus}) async {
    _guideTimer?.cancel();
    _pausePracticeTimer();
    await Future.wait([_pitchService.stop(), _guideToneService.stop()]);
    if (!mounted) return;
    setState(() {
      _guidePlaying = false;
      _resumeAfterGuide = false;
      _reading = const PitchReading.silent();
      _stableSince = null;
      _stableSinceMicros = null;
      _lastSampleAt = null;
      if (resetStatus && !_completed) _status = _SongStatus.idle;
    });
  }

  Future<void> _handleReadingError() async {
    _guideTimer?.cancel();
    _pausePracticeTimer();
    await Future.wait([_pitchService.stop(), _guideToneService.stop()]);
    if (!mounted || _completed) return;
    setState(() {
      _status = _SongStatus.error;
      _finishing = false;
      _guidePlaying = false;
      _resumeAfterGuide = false;
      _reading = const PitchReading.silent();
      _stableSince = null;
      _stableSinceMicros = null;
      _lastSampleAt = null;
      _errorMessage = context.strings.t('microphoneReadError');
    });
  }

  Future<void> _toggleGuide() async {
    if (_guidePlaying) {
      await _stopGuideAndResume();
      return;
    }
    _resumeAfterGuide = _status == _SongStatus.listening;
    if (_resumeAfterGuide) {
      _pausePracticeTimer();
      await _pitchService.stop();
    }
    if (!mounted) return;
    setState(() {
      _guidePlaying = true;
      _status = _SongStatus.idle;
      _reading = const PitchReading.silent();
      _stableSince = null;
      _stableSinceMicros = null;
      _lastSampleAt = null;
      _errorMessage = null;
    });

    try {
      final key = AppScope.of(context).harmonicaKey;
      final duration = await _guideToneService.play(
        frequencies: widget.song.notes
            .map((note) => note.frequencyForKey(key))
            .toList(),
        speed: _guideSpeed,
        repeat: _guideLoop,
      );
      if (!mounted || _guideLoop) return;
      _guideTimer = Timer(
        Duration(milliseconds: duration + 120),
        _stopGuideAndResume,
      );
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _guidePlaying = false;
        _status = _SongStatus.error;
        _errorMessage = error.message ?? context.strings.t('guideMelodyError');
      });
    }
  }

  Future<void> _stopGuideAndResume() async {
    _guideTimer?.cancel();
    await _guideToneService.stop();
    if (!mounted) return;
    final shouldResume = _resumeAfterGuide && !_completed;
    setState(() {
      _guidePlaying = false;
      _resumeAfterGuide = false;
    });
    if (shouldResume) await _beginListening();
  }

  Future<void> _restart() async {
    await _stopAll(resetStatus: true);
    if (!mounted) return;
    setState(() {
      _index = 0;
      _score = 0;
      _matchedError = 0;
      _completed = false;
      _finishing = false;
      _listeningStartedAt = null;
      _activePracticeDuration = Duration.zero;
      _lastSampleAt = null;
    });
  }

  void _pausePracticeTimer() {
    final startedAt = _listeningStartedAt;
    if (startedAt == null) return;
    _activePracticeDuration += DateTime.now().difference(startedAt);
    _listeningStartedAt = null;
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final palette = context.colors;
    final target = widget.song.notes[_index];
    final cents = _reading.detected
        ? target.centsFromFrequency(_reading.frequency, controller.harmonicaKey)
        : 0.0;
    final progress = _completed
        ? 1.0
        : (_index / widget.song.notes.length).clamp(0.0, 1.0).toDouble();

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80,
        title: Text(
          context.strings.songTitle(widget.song.id, widget.song.title),
          maxLines: 2,
          softWrap: true,
          overflow: TextOverflow.visible,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _completed
                      ? context.strings.t('songPracticeComplete')
                      : context.strings.t('songNoteProgress', {
                          'current': _index + 1,
                          'total': widget.song.notes.length,
                        }),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Text(
                context.strings.t('songProgress', {
                  'percent': (progress * 100).round(),
                }),
                style: TextStyle(
                  color: palette.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: MotionLinearProgress(
              value: progress,
              minHeight: 6,
              backgroundColor: palette.surfaceHigh,
            ),
          ),
          const SizedBox(height: 22),
          AnimatedSwitcher(
            duration: AppMotion.duration(context, AppMotion.base),
            child: _completed
                ? _SongCompletion(
                    key: const ValueKey('song-complete'),
                    score: _score,
                  )
                : Column(
                    key: const ValueKey('song-active'),
                    children: [
                      Center(
                        child: AnimatedSwitcher(
                          duration: AppMotion.duration(context, AppMotion.base),
                          child: Column(
                            key: ValueKey(_index),
                            children: [
                              SectionLabel(context.strings.t('currentTarget')),
                              const SizedBox(height: 4),
                              Text(
                                target.labelForKey(controller.harmonicaKey),
                                style: Theme.of(context).textTheme.displaySmall
                                    ?.copyWith(
                                      fontSize: 54,
                                      color: palette.primary,
                                    ),
                              ),
                              Text(
                                target.tab,
                                style: TextStyle(
                                  color: palette.accentInk,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: palette.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: palette.outline),
                        ),
                        child: Column(
                          children: [
                            HarmonicaDiagram(activeTab: target.tab),
                            const SizedBox(height: 16),
                            _Sequence(song: widget.song, currentIndex: _index),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: palette.surfaceHigh,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            AnimatedSwitcher(
                              duration: AppMotion.duration(
                                context,
                                AppMotion.fast,
                              ),
                              child: Icon(
                                _status == _SongStatus.listening
                                    ? Icons.graphic_eq_rounded
                                    : Icons.mic_off_rounded,
                                key: ValueKey(_status),
                                color: _status == _SongStatus.listening
                                    ? palette.success
                                    : palette.muted,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _reading.detected
                                        ? _reading.noteWithOctave
                                        : _status == _SongStatus.listening
                                        ? context.strings.t(
                                            'waitingStablePitch',
                                          )
                                        : context.strings.t(
                                            'microphoneNotStarted',
                                          ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  if (_reading.detected)
                                    Text(
                                      '${cents >= 0 ? '+' : ''}${cents.round()} '
                                      '${context.strings.t('cents')}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                ],
                              ),
                            ),
                            if (_stableSince != null ||
                                _stableSinceMicros != null)
                              Icon(
                                Icons.check_circle_rounded,
                                color: palette.success,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          if (!_completed) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _status == _SongStatus.requestingPermission
                    ? null
                    : _status == _SongStatus.listening
                    ? () => _stopAll(resetStatus: true)
                    : _requestAndStart,
                icon: Icon(
                  _status == _SongStatus.listening
                      ? Icons.stop_rounded
                      : Icons.mic_rounded,
                ),
                label: Text(_buttonLabel),
              ),
            ),
            const SizedBox(height: 16),
            _SongGuideControls(
              playing: _guidePlaying,
              speed: _guideSpeed,
              loop: _guideLoop,
              enabled: true,
              onPlay: _toggleGuide,
              onSpeedChanged: (value) async {
                if (_guidePlaying) await _stopGuideAndResume();
                if (!context.mounted) return;
                setState(() => _guideSpeed = value);
                await AppHaptics.selection(context);
              },
              onLoopChanged: (value) async {
                if (_guidePlaying) await _stopGuideAndResume();
                if (!context.mounted) return;
                setState(() => _guideLoop = value);
                await AppHaptics.selection(context);
              },
            ),
          ] else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _restart,
                    icon: const Icon(Icons.replay_rounded),
                    label: Text(context.strings.t('restartPractice')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.check_rounded),
                    label: Text(context.strings.t('commonDone')),
                  ),
                ),
              ],
            ),
          if (_status == _SongStatus.permanentlyDenied) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _pitchService.openAppSettings,
              icon: const Icon(Icons.settings_rounded),
              label: Text(context.strings.t('commonOpenSettings')),
            ),
          ],
          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.danger),
            ),
          ],
          const SizedBox(height: 14),
          const PrivacyNote(),
        ],
      ),
    );
  }

  String get _buttonLabel {
    final strings = context.strings;
    return switch (_status) {
      _SongStatus.requestingPermission => strings.t('requestingPermission'),
      _SongStatus.listening => strings.t('stopPractice'),
      _SongStatus.denied => strings.t('grantMicrophoneAgain'),
      _SongStatus.permanentlyDenied => strings.t('permissionOff'),
      _SongStatus.error => strings.t('commonRetry'),
      _ => strings.t('startSongPractice'),
    };
  }
}

class _Sequence extends StatelessWidget {
  const _Sequence({required this.song, required this.currentIndex});

  final Song song;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: List.generate(song.notes.length, (index) {
        final complete = index < currentIndex;
        final active = index == currentIndex;
        return AnimatedContainer(
          duration: AppMotion.duration(context, AppMotion.fast),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: complete
                ? palette.success.withValues(alpha: 0.12)
                : active
                ? palette.primary.withValues(alpha: 0.14)
                : palette.surfaceHigh,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active ? palette.primary : Colors.transparent,
            ),
          ),
          child: Text(
            song.notes[index].tab,
            style: TextStyle(
              color: complete
                  ? palette.success
                  : active
                  ? palette.primary
                  : palette.muted,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w800,
            ),
          ),
        );
      }),
    );
  }
}

class _SongGuideControls extends StatelessWidget {
  const _SongGuideControls({
    required this.playing,
    required this.speed,
    required this.loop,
    required this.enabled,
    required this.onPlay,
    required this.onSpeedChanged,
    required this.onLoopChanged,
  });

  final bool playing;
  final double speed;
  final bool loop;
  final bool enabled;
  final VoidCallback onPlay;
  final ValueChanged<double> onSpeedChanged;
  final ValueChanged<bool> onLoopChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.tonalIcon(
              onPressed: enabled ? onPlay : null,
              icon: Icon(
                playing ? Icons.stop_rounded : Icons.volume_up_rounded,
              ),
              label: Text(
                playing
                    ? context.strings.t('stopDemo')
                    : context.strings.t('playMelody'),
              ),
            ),
            SegmentedButton<double>(
              segments: const [
                ButtonSegment(value: 0.5, label: Text('0.5×')),
                ButtonSegment(value: 1, label: Text('1×')),
              ],
              selected: {speed},
              showSelectedIcon: false,
              onSelectionChanged: enabled
                  ? (value) => onSpeedChanged(value.first)
                  : null,
            ),
            FilterChip(
              selected: loop,
              onSelected: enabled ? onLoopChanged : null,
              avatar: const Icon(Icons.repeat_rounded, size: 18),
              label: Text(context.strings.t('loop')),
            ),
          ],
        ),
      ),
    );
  }
}

class _SongCompletion extends StatelessWidget {
  const _SongCompletion({required this.score, super.key});

  final int score;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.celebration_rounded, color: palette.accent, size: 54),
            const SizedBox(height: 12),
            Text(
              context.strings.t('melodyComplete'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              context.strings.t('pitchScore', {'score': score}),
              style: TextStyle(
                color: palette.primary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
