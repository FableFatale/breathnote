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
import '../theme/app_adaptive.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';
import '../widgets/cute_illustrations.dart';
import '../widgets/gesture_guide.dart';
import '../widgets/motion_widgets.dart';
import '../widgets/shared_widgets.dart';
import 'help_screen.dart';

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
  Timer? _guideStepTimer;
  PitchReading _reading = const PitchReading.silent();
  _SongStatus _status = _SongStatus.idle;
  DateTime? _stableSince;
  int? _stableSinceMicros;
  DateTime? _listeningStartedAt;
  Duration _activePracticeDuration = Duration.zero;
  DateTime? _lastSampleAt;
  String? _errorMessage;
  int _index = 0;
  int _demoNoteIndex = 0;
  double _holdProgress = 0;
  int _score = 0;
  double _matchedError = 0;
  bool _completed = false;
  bool _finishing = false;
  bool _guidePlaying = false;
  bool _guideLoop = false;
  bool _resumeAfterGuide = false;
  bool _unsupported = false;
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
  void deactivate() {
    _guideTimer?.cancel();
    _guideStepTimer?.cancel();
    _pausePracticeTimer();
    super.deactivate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _guideTimer?.cancel();
    _guideStepTimer?.cancel();
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
      _unsupported = false;
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
    } catch (error) {
      if (!mounted) return;
      final unsupported = _isUnsupportedError(error);
      setState(() {
        _status = _SongStatus.error;
        _unsupported = unsupported;
        _errorMessage = unsupported
            ? null
            : _messageForError(error, 'microphoneStartError');
      });
    }
  }

  Future<void> _beginListening() async {
    if (!mounted) return;
    final sensitivity =
        AppScope.maybeRead(context)?.microphoneSensitivity ?? 0.68;
    _subscription ??= _pitchService.readings.listen(
      _onReading,
      onError: (Object _) => unawaited(_handleReadingError()),
    );
    final started = await _pitchService.start(sensitivity: sensitivity);
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
    final controller = AppScope.maybeRead(context);
    if (controller == null) return;
    final target = widget.song.notes[_index];
    final cents = target.centsFromFrequency(
      reading.frequency,
      controller.harmonicaKey,
    );
    final matches = reading.detected && cents.abs() <= 35;
    final now = DateTime.now();
    if (reading.detected &&
        (_lastSampleAt == null ||
            now.difference(_lastSampleAt!).inMilliseconds >= 500)) {
      _lastSampleAt = now;
      unawaited(
        controller.recordPitchAttempt(
          tab: target.tab,
          reading: reading,
          cents: cents,
        ),
      );
    }
    if (matches) {
      if (_stableSince == null && _stableSinceMicros == null) {
        unawaited(AppHaptics.reedResonance(context));
      }
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
      _holdProgress = 0;
    }
    setState(() => _reading = reading);
  }

  bool _isStableForMicros(int timestampMicros) {
    _stableSince = null;
    _stableSinceMicros ??= timestampMicros;
    final elapsed = timestampMicros - _stableSinceMicros!;
    _holdProgress = (elapsed / 420000).clamp(0.0, 1.0).toDouble();
    return elapsed >= 420000;
  }

  bool _isStableForWallClock(DateTime now) {
    _stableSinceMicros = null;
    _stableSince ??= now;
    final elapsed = now.difference(_stableSince!).inMilliseconds;
    _holdProgress = (elapsed / 420).clamp(0.0, 1.0).toDouble();
    return elapsed >= 420;
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
        _demoNoteIndex = _index;
        _holdProgress = 0;
        _reading = const PitchReading.silent();
        _stableSince = null;
        _stableSinceMicros = null;
        _lastSampleAt = null;
        _finishing = false;
      });
      return;
    }

    _completed = true;
    _holdProgress = 1;
    _pausePracticeTimer();
    _score = (100 - _matchedError / widget.song.notes.length * 1.4)
        .round()
        .clamp(0, 100)
        .toInt();
    final controller = AppScope.maybeRead(context);
    if (controller == null) return;
    final seconds = _activePracticeDuration.inSeconds.clamp(0, 3600).toInt();
    final futures = <Future<void>>[
      _pitchService.stop(),
      _guideToneService.stop(),
      controller.recordPractice(
        seconds: seconds == 0 ? 1 : seconds,
        score: _score,
      ),
    ];
    if (widget.lessonId != null) {
      futures.add(controller.markLessonComplete(widget.lessonId!));
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
    _guideStepTimer?.cancel();
    _pausePracticeTimer();
    await Future.wait([_pitchService.stop(), _guideToneService.stop()]);
    if (!mounted) return;
    setState(() {
      _guidePlaying = false;
      _resumeAfterGuide = false;
      _holdProgress = 0;
      _reading = const PitchReading.silent();
      _stableSince = null;
      _stableSinceMicros = null;
      _lastSampleAt = null;
      if (resetStatus && !_completed) _status = _SongStatus.idle;
    });
  }

  Future<void> _handleReadingError() async {
    _guideTimer?.cancel();
    _guideStepTimer?.cancel();
    _pausePracticeTimer();
    await Future.wait([_pitchService.stop(), _guideToneService.stop()]);
    if (!mounted || _completed) return;
    setState(() {
      _status = _SongStatus.error;
      _finishing = false;
      _guidePlaying = false;
      _resumeAfterGuide = false;
      _holdProgress = 0;
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
      _demoNoteIndex = _index;
      _holdProgress = 0;
      _status = _SongStatus.idle;
      _reading = const PitchReading.silent();
      _stableSince = null;
      _stableSinceMicros = null;
      _lastSampleAt = null;
      _errorMessage = null;
    });

    try {
      final key = AppScope.maybeRead(context)?.harmonicaKey ?? 'C';
      final duration = await _guideToneService.play(
        frequencies: widget.song.notes
            .map((note) => note.frequencyForKey(key))
            .toList(),
        speed: _guideSpeed,
        repeat: _guideLoop,
      );
      if (!mounted) return;
      final stepMs = (duration / widget.song.notes.length)
          .round()
          .clamp(160, 1200);
      _guideStepTimer?.cancel();
      _guideStepTimer = Timer.periodic(Duration(milliseconds: stepMs), (timer) {
        if (!mounted || !_guidePlaying) {
          timer.cancel();
          return;
        }
        setState(() {
          if (_demoNoteIndex < widget.song.notes.length - 1) {
            _demoNoteIndex++;
          } else if (_guideLoop) {
            _demoNoteIndex = 0;
          }
        });
      });
      if (_guideLoop) return;
      _guideTimer = Timer(
        Duration(milliseconds: duration + 120),
        _stopGuideAndResume,
      );
    } catch (error) {
      _guideStepTimer?.cancel();
      if (!mounted) return;
      final unsupported = _isUnsupportedError(error);
      setState(() {
        _guidePlaying = false;
        _status = _SongStatus.error;
        _unsupported = unsupported;
        _errorMessage = unsupported
            ? null
            : _messageForError(error, 'guideMelodyError');
      });
    }
  }

  Future<void> _stopGuideAndResume() async {
    _guideTimer?.cancel();
    _guideStepTimer?.cancel();
    await _guideToneService.stop();
    if (!mounted) return;
    final shouldResume = _resumeAfterGuide && !_completed;
    setState(() {
      _guidePlaying = false;
      _demoNoteIndex = _index;
      _resumeAfterGuide = false;
    });
    if (shouldResume) await _beginListening();
  }

  Future<void> _restart() async {
    await _stopAll(resetStatus: true);
    if (!mounted) return;
    setState(() {
      _index = 0;
      _demoNoteIndex = 0;
      _holdProgress = 0;
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
    final activeNoteIndex = _guidePlaying ? _demoNoteIndex : _index;
    final target = widget.song.notes[activeNoteIndex];
    final nextNote = activeNoteIndex + 1 < widget.song.notes.length
        ? widget.song.notes[activeNoteIndex + 1]
        : null;
    final cents = _reading.detected
        ? target.centsFromFrequency(_reading.frequency, controller.harmonicaKey)
        : 0.0;
    final progress = _completed
        ? 1.0
        : _guidePlaying
        ? ((activeNoteIndex + 1) / widget.song.notes.length)
              .clamp(0.0, 1.0)
              .toDouble()
        : ((_index + _holdProgress) / widget.song.notes.length)
              .clamp(0.0, 1.0)
              .toDouble();
    final pagePadding = AppAdaptive.pagePadding(context);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        title: Row(
          children: [
            SongArtworkBadge(
              iconId: controller.iconIdForSong(widget.song),
              songId: widget.song.id,
              size: 36,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.strings.songTitle(widget.song.id, widget.song.title),
                maxLines: 2,
                softWrap: true,
                overflow: TextOverflow.visible,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compactHeight = constraints.maxHeight < 700;
            final sectionGap = compactHeight ? 10.0 : 12.0;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                pagePadding,
                4,
                pagePadding,
                compactHeight ? 12 : 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. 顶部动态进度卡片
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: palette.outline),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: AnimatedSwitcher(
                                duration: AppMotion.duration(
                                  context,
                                  AppMotion.fast,
                                ),
                                layoutBuilder: (currentChild, prevChildren) {
                                  return Align(
                                    alignment: Alignment.centerLeft,
                                    child: currentChild,
                                  );
                                },
                                child: Text(
                                  _completed
                                      ? context.strings.t(
                                          'songPracticeComplete',
                                        )
                                      : context.strings.t('songNoteProgress', {
                                          'current': activeNoteIndex + 1,
                                          'total': widget.song.notes.length,
                                        }),
                                  key: ValueKey(
                                    'progress_${_completed}_$activeNoteIndex',
                                  ),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(end: progress),
                              duration: AppMotion.duration(
                                context,
                                AppMotion.base,
                              ),
                              curve: AppMotion.standardCurve,
                              builder: (context, value, _) {
                                return Text(
                                  context.strings.t('songProgress', {
                                    'percent': (value * 100).round(),
                                  }),
                                  style: TextStyle(
                                    color: palette.primary,
                                    fontSize: 13,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w800,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: MotionLinearProgress(
                            value: progress,
                            minHeight: 7,
                            backgroundColor: palette.surfaceHigh,
                            color: _completed
                                ? palette.success
                                : palette.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: sectionGap),
                  AnimatedSwitcher(
                    duration: AppMotion.duration(context, AppMotion.base),
                    child: _completed
                        ? _SongCompletion(
                            key: const ValueKey('song-complete'),
                            score: _score,
                          )
                        : Column(
                            key: const ValueKey('song-active'),
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // 2. 核心主舞台卡片（当前目标音 + 10孔动态口琴图 + 等宽对齐走谱条）
                              Container(
                                padding: EdgeInsets.all(
                                  compactHeight ? 12 : 14,
                                ),
                                decoration: BoxDecoration(
                                  color: palette.surface,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: palette.outline),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // 目标音横幅（左：标签与孔位，中：大音名，右：吹吸动效）
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: compactHeight ? 8 : 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: palette.surfaceHigh.withValues(
                                          alpha: 0.65,
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Column(
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Align(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: SectionLabel(
                                                    context.strings.t(
                                                      'currentTarget',
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              BreathGestureGuide(
                                                isBlow: target.isBlow,
                                                label: context.strings.t(
                                                  target.isBlow
                                                      ? 'blowAction'
                                                      : 'drawAction',
                                                ),
                                                compact: true,
                                              ),
                                            ],
                                          ),
                                          SizedBox(
                                            height: compactHeight ? 2 : 4,
                                          ),
                                          AnimatedSwitcher(
                                            duration: AppMotion.duration(
                                              context,
                                              AppMotion.base,
                                            ),
                                            transitionBuilder:
                                                (child, animation) {
                                                  return ScaleTransition(
                                                    scale: Tween<double>(
                                                      begin: 0.92,
                                                      end: 1.0,
                                                    ).animate(animation),
                                                    child: FadeTransition(
                                                      opacity: animation,
                                                      child: child,
                                                    ),
                                                  );
                                                },
                                            child: Row(
                                              key: ValueKey(
                                                'target_${activeNoteIndex}_${target.tab}',
                                              ),
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                Text(
                                                  target.labelForKey(
                                                    controller.harmonicaKey,
                                                  ),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .displaySmall
                                                      ?.copyWith(
                                                        fontSize: compactHeight
                                                            ? 40
                                                            : 46,
                                                        height: 1.05,
                                                        color: palette.primary,
                                                      ),
                                                ),
                                                const SizedBox(width: 12),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 5,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: palette.primary
                                                        .withValues(
                                                          alpha: 0.12,
                                                        ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                    border: Border.all(
                                                      color: palette.primary
                                                          .withValues(
                                                            alpha: 0.30,
                                                          ),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    target.tab,
                                                    style: TextStyle(
                                                      color: palette.primary,
                                                      fontSize: 16,
                                                      fontFamily: 'monospace',
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                ),
                                                if (nextNote != null) ...[
                                                  const SizedBox(width: 8),
                                                  Icon(
                                                    Icons.arrow_forward_rounded,
                                                    size: 14,
                                                    color: palette.muted,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    nextNote.tab,
                                                    style: TextStyle(
                                                      color: palette.muted,
                                                      fontSize: 13,
                                                      fontFamily: 'monospace',
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          if (_holdProgress > 0) ...[
                                            const SizedBox(height: 6),
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                              child: LinearProgressIndicator(
                                                value: _holdProgress,
                                                minHeight: 4,
                                                backgroundColor: palette.outline
                                                    .withValues(alpha: 0.35),
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(palette.success),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    SizedBox(height: compactHeight ? 10 : 12),
                                    HarmonicaDiagram(activeTab: target.tab),
                                    SizedBox(height: compactHeight ? 10 : 12),
                                    _Sequence(
                                      song: widget.song,
                                      currentIndex: activeNoteIndex,
                                      holdProgress: _guidePlaying
                                          ? 1.0
                                          : _holdProgress,
                                      onNoteTap: (tappedIndex) {
                                        if (_completed) return;
                                        unawaited(
                                          AppHaptics.selection(context),
                                        );
                                        setState(() {
                                          _index = tappedIndex;
                                          _demoNoteIndex = tappedIndex;
                                          _holdProgress = 0;
                                          _stableSince = null;
                                          _stableSinceMicros = null;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: sectionGap),
                              // 3. 麦克风音准状态卡片（与上方舞台卡片严格等宽对齐）
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: compactHeight ? 10 : 12,
                                ),
                                decoration: BoxDecoration(
                                  color: palette.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: palette.outline),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: _status == _SongStatus.listening
                                            ? palette.success.withValues(
                                                alpha: 0.14,
                                              )
                                            : _guidePlaying
                                            ? palette.primary.withValues(
                                                alpha: 0.14,
                                              )
                                            : palette.surfaceHigh,
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: AnimatedSwitcher(
                                        duration: AppMotion.duration(
                                          context,
                                          AppMotion.fast,
                                        ),
                                        child: Icon(
                                          _status == _SongStatus.listening
                                              ? Icons.graphic_eq_rounded
                                              : _guidePlaying
                                              ? Icons.volume_up_rounded
                                              : Icons.mic_off_rounded,
                                          key: ValueKey(
                                            '${_status}_$_guidePlaying',
                                          ),
                                          size: 18,
                                          color:
                                              _status == _SongStatus.listening
                                              ? palette.success
                                              : _guidePlaying
                                              ? palette.primary
                                              : palette.muted,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _unsupported
                                                ? context.strings.t(
                                                    'featureUnavailable',
                                                  )
                                                : _guidePlaying
                                                ? context.strings.t(
                                                    'guidePlaying',
                                                  )
                                                : _reading.detected
                                                ? _reading.noteWithOctave
                                                : _status ==
                                                      _SongStatus.listening
                                                ? context.strings.t(
                                                    'waitingStablePitch',
                                                  )
                                                : context.strings.t(
                                                    'microphoneNotStarted',
                                                  ),
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(fontSize: 15),
                                          ),
                                          if (_reading.detected)
                                            Text(
                                              '${cents >= 0 ? '+' : ''}${cents.round()} '
                                              '${context.strings.t('cents')}',
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodySmall,
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
                  SizedBox(height: sectionGap),
                  if (!_completed) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: _unsupported
                            ? () => unawaited(showHelpScreen(context))
                            : _status == _SongStatus.requestingPermission
                            ? null
                            : _status == _SongStatus.listening
                            ? () => _stopAll(resetStatus: true)
                            : _requestAndStart,
                        icon: Icon(
                          _status == _SongStatus.listening
                              ? Icons.stop_rounded
                              : _unsupported
                              ? Icons.help_outline_rounded
                              : Icons.mic_rounded,
                        ),
                        label: Text(_buttonLabel),
                      ),
                    ),
                    SizedBox(height: sectionGap),
                    _SongGuideControls(
                      playing: _guidePlaying,
                      speed: _guideSpeed,
                      loop: _guideLoop,
                      enabled: !_unsupported,
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
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: _restart,
                              icon: const Icon(Icons.replay_rounded),
                              label: Text(
                                context.strings.t('restartPractice'),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: FilledButton.icon(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.check_rounded),
                              label: Text(context.strings.t('commonDone')),
                            ),
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
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: palette.danger),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _messageForError(Object error, String fallbackKey) {
    final strings = context.strings;
    if (error is PlatformException) {
      if (error.code == 'unsupported') return strings.t('featureUnavailable');
      if (error.message != null) return error.message!;
    }
    return strings.t(fallbackKey);
  }

  bool _isUnsupportedError(Object error) {
    return error is PlatformException && error.code == 'unsupported';
  }

  String get _buttonLabel {
    final strings = context.strings;
    if (_unsupported) return strings.t('help');
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
  const _Sequence({
    required this.song,
    required this.currentIndex,
    this.holdProgress = 0,
    this.onNoteTap,
  });

  final Song song;
  final int currentIndex;
  final double holdProgress;
  final ValueChanged<int>? onNoteTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final total = song.notes.length;

    Widget buildNoteCell(int index, {required bool expanded}) {
      final complete = index < currentIndex;
      final active = index == currentIndex;
      final fillFraction = complete
          ? 1.0
          : active
          ? holdProgress.clamp(0.0, 1.0)
          : 0.0;

      final cell = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onNoteTap != null ? () => onNoteTap!(index) : null,
        child: AnimatedScale(
          scale: active ? 1.05 : 1.0,
          duration: AppMotion.duration(context, AppMotion.fast),
          curve: AppMotion.standardCurve,
          child: AnimatedContainer(
            duration: AppMotion.duration(context, AppMotion.fast),
            height: 40,
            constraints: BoxConstraints(minWidth: expanded ? 0 : 44),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: complete
                  ? palette.success.withValues(alpha: 0.12)
                  : active
                  ? palette.primary.withValues(alpha: 0.14)
                  : palette.surfaceHigh,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: active
                    ? palette.primary
                    : complete
                    ? palette.success.withValues(alpha: 0.45)
                    : palette.outline,
                width: active ? 1.6 : 1.0,
              ),
            ),
            child: Stack(
              children: [
                if (fillFraction > 0)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 3.5,
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: fillFraction,
                      child: ColoredBox(
                        color: complete ? palette.success : palette.primary,
                      ),
                    ),
                  ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        song.notes[index].tab,
                        style: TextStyle(
                          color: complete
                              ? palette.success
                              : active
                              ? palette.primary
                              : palette.muted,
                          fontSize: 13,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      if (!expanded) return cell;
      return Expanded(child: cell);
    }

    // 8 个音及以内采用单行等分满宽对齐（与上方 10 孔口琴图左右严格对齐）
    if (total <= 8) {
      return Row(
        children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            buildNoteCell(i, expanded: true),
          ],
        ],
      );
    }

    // 超过 8 个音的自定义长曲谱采用单行横向滚动条，保持固定高度不撑破屏幕
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: total,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) => buildNoteCell(index, expanded: false),
      ),
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
    final palette = context.colors;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.outline),
      ),
      child: Row(
        children: [
          // 1. 播放旋律 / 停止旋律（等高 42px）
          Expanded(
            flex: 5,
            child: SizedBox(
              height: 42,
              child: FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: enabled ? onPlay : null,
                icon: Icon(
                  playing ? Icons.stop_rounded : Icons.volume_up_rounded,
                  size: 18,
                ),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    playing
                        ? context.strings.t('stopDemo')
                        : context.strings.t('playMelody'),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 2. 0.5× / 1× 速度切换器（等高 42px，圆角 12px）
          Expanded(
            flex: 4,
            child: Container(
              height: 42,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: palette.surfaceHigh,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.outline),
              ),
              child: Row(
                children: [
                  for (final option in const [
                    (0.5, '0.5×'),
                    (1.0, '1×'),
                  ])
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: enabled
                            ? () => onSpeedChanged(option.$1)
                            : null,
                        child: AnimatedContainer(
                          duration: AppMotion.duration(context, AppMotion.fast),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: speed == option.$1
                                ? palette.primary.withValues(alpha: 0.16)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                              color: speed == option.$1
                                  ? palette.primary
                                  : Colors.transparent,
                            ),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              option.$2,
                              style: TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                                fontWeight: speed == option.$1
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: speed == option.$1
                                    ? palette.primary
                                    : palette.muted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 3. 循环开关（等高 42px，圆角 12px）
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 42,
              child: Material(
                color: loop
                    ? palette.primary.withValues(alpha: 0.14)
                    : palette.surfaceHigh,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: loop ? palette.primary : palette.outline,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: enabled ? () => onLoopChanged(!loop) : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.repeat_rounded,
                          size: 16,
                          color: loop ? palette.primary : palette.muted,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              context.strings.t('loop'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: loop
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: loop ? palette.primary : palette.muted,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
            const ChumingBird(
              size: 72,
              mood: ChumingMood.celebrating,
            ),
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
