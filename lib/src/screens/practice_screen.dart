import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../localization/app_strings.dart';
import '../models/harmonica_layout.dart';
import '../models/pitch_reading.dart';
import '../models/practice_note.dart';
import '../services/guide_tone_service.dart';
import '../services/haptics.dart';
import '../services/pitch_service.dart';
import '../state/app_controller.dart';
import '../theme/app_adaptive.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';
import '../widgets/chuming_coach.dart';
import '../widgets/cute_illustrations.dart';
import '../widgets/gesture_guide.dart';
import '../widgets/motion_widgets.dart';
import '../widgets/shared_widgets.dart';
import 'help_screen.dart';
import 'lesson_routes.dart';

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({
    required this.target,
    required this.lessonId,
    required this.instruction,
    this.step = 1,
    super.key,
  });

  final PracticeNote target;
  final String lessonId;
  final String instruction;
  final int step;

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

enum _PracticeStatus {
  idle,
  requestingPermission,
  listening,
  denied,
  permanentlyDenied,
  error,
}

class _PracticeScreenState extends State<PracticeScreen>
    with WidgetsBindingObserver {
  final _pitchService = PitchService();
  final _guideToneService = GuideToneService();
  StreamSubscription<PitchReading>? _subscription;
  Timer? _guideTimer;
  PitchReading _reading = const PitchReading.silent();
  _PracticeStatus _status = _PracticeStatus.idle;
  DateTime? _stableSince;
  int? _stableSinceMicros;
  DateTime? _listeningStartedAt;
  Duration _activePracticeDuration = Duration.zero;
  DateTime? _lastSampleAt;
  String? _errorMessage;
  bool _completed = false;
  bool _completionVisible = false;
  bool _guidePlaying = false;
  bool _guideLoop = false;
  bool _resumeAfterGuide = false;
  bool _unsupported = false;
  double _guideSpeed = 1;
  double _holdProgress = 0;
  int _missedFrames = 0;
  int _score = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      unawaited(_stopAll(resetStatus: true));
    }
  }

  @override
  void deactivate() {
    _guideTimer?.cancel();
    _pausePracticeTimer();
    super.deactivate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _guideTimer?.cancel();
    _subscription?.cancel();
    unawaited(_pitchService.stop());
    unawaited(_guideToneService.stop());
    super.dispose();
  }

  Future<void> _requestAndStart() async {
    if (_status == _PracticeStatus.requestingPermission || _completed) return;
    if (_guidePlaying) {
      _resumeAfterGuide = false;
      await _stopGuideAndResume();
    }
    if (!mounted) return;
    setState(() {
      _status = _PracticeStatus.requestingPermission;
      _unsupported = false;
      _errorMessage = null;
    });
    try {
      final permission = await _pitchService.requestPermission();
      if (!mounted) return;
      if (permission != MicrophonePermission.granted) {
        setState(() {
          _status = permission == MicrophonePermission.permanentlyDenied
              ? _PracticeStatus.permanentlyDenied
              : _PracticeStatus.denied;
        });
        return;
      }
      await _beginListening();
    } catch (error) {
      if (!mounted) return;
      final unsupported = _isUnsupportedError(error);
      setState(() {
        _status = _PracticeStatus.error;
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
      _status = started ? _PracticeStatus.listening : _PracticeStatus.error;
      _errorMessage = started
          ? null
          : context.strings.t('microphoneSettingsError');
      if (started) _listeningStartedAt ??= DateTime.now();
    });
    if (started) await AppHaptics.light(context);
  }

  Future<void> _stopListening() async {
    _pausePracticeTimer();
    await _pitchService.stop();
    if (!mounted) return;
    setState(() {
      _status = _PracticeStatus.idle;
      _reading = const PitchReading.silent();
      _stableSince = null;
      _stableSinceMicros = null;
      _holdProgress = 0;
      _missedFrames = 0;
      _lastSampleAt = null;
    });
  }

  Future<void> _handleReadingError() async {
    _guideTimer?.cancel();
    _pausePracticeTimer();
    await Future.wait([_pitchService.stop(), _guideToneService.stop()]);
    if (!mounted || _completed) return;
    setState(() {
      _status = _PracticeStatus.error;
      _guidePlaying = false;
      _resumeAfterGuide = false;
      _reading = const PitchReading.silent();
      _stableSince = null;
      _stableSinceMicros = null;
      _holdProgress = 0;
      _missedFrames = 0;
      _lastSampleAt = null;
      _errorMessage = context.strings.t('microphoneReadError');
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
      _holdProgress = 0;
      _missedFrames = 0;
      _lastSampleAt = null;
      if (resetStatus && !_completed) _status = _PracticeStatus.idle;
    });
  }

  void _onReading(PitchReading reading) {
    if (!mounted || _status != _PracticeStatus.listening || _completed) return;
    final controller = AppScope.maybeRead(context);
    if (controller == null) return;
    final cents = widget.target.centsFromFrequency(
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
          tab: widget.target.tab,
          reading: reading,
          cents: cents,
        ),
      );
    }
    if (matches) {
      _missedFrames = 0;
      if (_stableSince == null && _stableSinceMicros == null) {
        unawaited(AppHaptics.reedResonance(context));
      }
      final stableLongEnough = reading.timestampMicros > 0
          ? _isStableForMicros(reading.timestampMicros)
          : _isStableForWallClock(now);
      if (stableLongEnough) {
        unawaited(_complete(cents));
        return;
      }
    } else {
      _missedFrames += 1;
      if (_missedFrames >= 3) {
        _stableSince = null;
        _stableSinceMicros = null;
        _holdProgress = 0;
      }
    }
    setState(() => _reading = reading);
  }

  bool _isStableForMicros(int timestampMicros) {
    _stableSince = null;
    _stableSinceMicros ??= timestampMicros;
    final elapsed = timestampMicros - _stableSinceMicros!;
    _holdProgress = (elapsed / 450000).clamp(0.12, 1.0).toDouble();
    return elapsed >= 450000;
  }

  bool _isStableForWallClock(DateTime now) {
    _stableSinceMicros = null;
    _stableSince ??= now;
    final elapsed = now.difference(_stableSince!).inMilliseconds;
    _holdProgress = (elapsed / 450).clamp(0.12, 1.0).toDouble();
    return elapsed >= 450;
  }

  Future<void> _complete(double cents) async {
    if (_completed || !mounted) return;
    final controller = AppScope.maybeRead(context);
    if (controller == null) return;
    _completed = true;
    _holdProgress = 1;
    _pausePracticeTimer();
    _score = (100 - cents.abs() * 1.2).round().clamp(0, 100).toInt();
    final seconds = _activePracticeDuration.inSeconds.clamp(0, 3600).toInt();
    await Future.wait([
      _pitchService.stop(),
      _guideToneService.stop(),
      controller.markLessonComplete(widget.lessonId),
      controller.recordPractice(
        seconds: seconds == 0 ? 1 : seconds,
        score: _score,
      ),
    ]);
    if (!mounted) return;
    await AppHaptics.success(context);
    if (!mounted) return;
    setState(() {
      _status = _PracticeStatus.idle;
      _guidePlaying = false;
      _completionVisible = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_completed) return;
      setState(() => _completionVisible = true);
    });
  }

  Future<void> _previewHole(int hole) async {
    if (_completed || _status == _PracticeStatus.listening || !mounted) return;
    final key = AppScope.maybeRead(context)?.harmonicaKey ?? 'C';
    final info = harmonicaHoleInfo(hole, isBlow: widget.target.isBlow);
    try {
      await _guideToneService.play(
        frequencies: [info.frequencyForKey(key)],
        speed: 1.0,
        repeat: false,
      );
    } catch (_) {
      // Ignore preview errors when audio plugin is unavailable.
    }
  }

  Future<void> _toggleGuide() async {
    if (_completed || !mounted) return;
    if (_guidePlaying) {
      await _stopGuideAndResume();
      return;
    }

    final harmonicaKey = AppScope.maybeRead(context)?.harmonicaKey ?? 'C';
    _resumeAfterGuide = _status == _PracticeStatus.listening;
    if (_resumeAfterGuide) {
      _pausePracticeTimer();
      await _pitchService.stop();
    }
    if (!mounted) return;
    setState(() {
      _guidePlaying = true;
      _status = _PracticeStatus.idle;
      _reading = const PitchReading.silent();
      _stableSince = null;
      _stableSinceMicros = null;
      _holdProgress = 0;
      _missedFrames = 0;
      _lastSampleAt = null;
      _errorMessage = null;
    });

    try {
      final duration = await _guideToneService.play(
        frequencies: [widget.target.frequencyForKey(harmonicaKey)],
        speed: _guideSpeed,
        repeat: _guideLoop,
      );
      if (!mounted || _guideLoop) return;
      _guideTimer = Timer(
        Duration(milliseconds: duration + 120),
        _stopGuideAndResume,
      );
    } catch (error) {
      if (!mounted) return;
      final unsupported = _isUnsupportedError(error);
      setState(() {
        _guidePlaying = false;
        _status = _PracticeStatus.error;
        _unsupported = unsupported;
        _errorMessage = unsupported
            ? null
            : _messageForError(error, 'guideToneError');
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

  Future<void> _toggleSpeed() async {
    if (_completed || !mounted) return;
    final wasPlaying = _guidePlaying;
    if (wasPlaying) {
      _resumeAfterGuide = false;
      await _stopGuideAndResume();
    }
    if (!mounted) return;
    setState(() => _guideSpeed = _guideSpeed == 1 ? 0.5 : 1);
    await AppHaptics.selection(context);
    if (!mounted) return;
    if (wasPlaying || _status == _PracticeStatus.idle) {
      await _toggleGuide();
    }
  }

  Future<void> _toggleLoop() async {
    if (_completed || !mounted) return;
    final wasPlaying = _guidePlaying;
    if (wasPlaying) {
      _resumeAfterGuide = false;
      await _stopGuideAndResume();
    }
    if (!mounted) return;
    setState(() => _guideLoop = !_guideLoop);
    await AppHaptics.selection(context);
    if (!mounted) return;
    if (_guideLoop && (wasPlaying || _status == _PracticeStatus.idle)) {
      await _toggleGuide();
    }
  }

  Future<void> _restart() async {
    await _stopAll(resetStatus: true);
    if (!mounted) return;
    setState(() {
      _completed = false;
      _completionVisible = false;
      _holdProgress = 0;
      _missedFrames = 0;
      _score = 0;
      _listeningStartedAt = null;
      _activePracticeDuration = Duration.zero;
      _lastSampleAt = null;
      _errorMessage = null;
    });
  }

  Future<void> _handlePrimaryAction() async {
    if (_unsupported) {
      await showHelpScreen(context);
      return;
    }
    if (_completed) {
      await _openNextOrFinish();
      return;
    }
    if (_guidePlaying) {
      _resumeAfterGuide = false;
      await _stopGuideAndResume();
      return;
    }
    if (_status == _PracticeStatus.listening) {
      await _stopListening();
      return;
    }
    await _requestAndStart();
  }

  Future<void> _openNextOrFinish() async {
    final nextId = nextLessonId(widget.lessonId);
    if (nextId == null || !mounted) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    await Navigator.of(context)
        .pushReplacement(lessonRoute(context, lessonById(nextId)));
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
    final strings = context.strings;
    final hasNextLesson = nextLessonId(widget.lessonId) != null;
    final noteWithOctave = widget.target.labelForKey(controller.harmonicaKey);
    final note = noteWithOctave.replaceAll(RegExp(r'\d+$'), '');
    final cents = _reading.detected
        ? widget.target.centsFromFrequency(
            _reading.frequency,
            controller.harmonicaKey,
          )
        : 0.0;
    final currentStage = _status == _PracticeStatus.listening || _completed
        ? 3
        : 2;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 56,
        titleSpacing: 4,
        title: Text(
          strings.lessonTitle(widget.lessonId),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: MaterialLocalizations.of(context).showMenuTooltip,
            icon: const Icon(Icons.more_horiz_rounded),
            popUpAnimationStyle: AppMotion.animationStyle(
              context,
              duration: AppMotion.fast,
              reverseDuration: AppMotion.fast,
            ),
            onSelected: (value) {
              if (value == 'restart') unawaited(_restart());
              if (value == 'settings') {
                unawaited(_pitchService.openAppSettings());
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'restart',
                child: Row(
                  children: [
                    const Icon(Icons.replay_rounded),
                    const SizedBox(width: 12),
                    Text(strings.t('practiceAgain')),
                  ],
                ),
              ),
              if (_status == _PracticeStatus.permanentlyDenied)
                PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: [
                      const Icon(Icons.settings_rounded),
                      const SizedBox(width: 12),
                      Text(strings.t('commonOpenSettings')),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compactHeight = constraints.maxHeight < 680;
                final gap = compactHeight ? 10.0 : 14.0;
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    AppAdaptive.pagePadding(context),
                    compactHeight ? 8 : 14,
                    AppAdaptive.pagePadding(context),
                    compactHeight ? 10 : 16,
                  ),
                  child: Column(
                    children: [
                      _StageProgress(
                        key: const Key('practice-stage-progress'),
                        currentStage: currentStage,
                        complete: _completed,
                      ),
                      SizedBox(height: gap),
                      ChumingCoachBanner(
                        featureId: 'practice',
                        messageKey: 'coachPractice',
                        mood: ChumingMood.blowing,
                        bottomSpacing: compactHeight ? 8 : 12,
                      ),
                      Row(
                        children: [
                          SectionLabel(strings.t('targetNote')),
                          const Spacer(),
                          Text(
                            _tabDescription(strings),
                            style: TextStyle(
                              color: palette.muted,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: compactHeight ? 8 : 14),
                      AnimatedSwitcher(
                        duration: AppMotion.duration(context, AppMotion.base),
                        child: _completed
                            ? _CompletionDisplay(
                                key: const ValueKey('practice-completion'),
                                score: _score,
                                visible: _completionVisible,
                              )
                            : Column(
                                key: const ValueKey('target-note'),
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ChumingBird(
                                        size: compactHeight ? 40 : 46,
                                        mood: widget.target.isBlow
                                            ? ChumingMood.blowing
                                            : ChumingMood.drawing,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        note,
                                        style: TextStyle(
                                          color: palette.primary,
                                          fontFamily: 'MingjieSans',
                                          fontSize: compactHeight ? 48 : 56,
                                          height: 1,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -1.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  BreathGestureGuide(
                                    isBlow: widget.target.isBlow,
                                    label: strings.t(
                                      widget.target.isBlow
                                          ? 'blowAction'
                                          : 'drawAction',
                                    ),
                                    compact: true,
                                  ),
                                ],
                              ),
                      ),
                      SizedBox(height: compactHeight ? 12 : 18),
                      HarmonicaDiagram(
                        activeTab: widget.target.tab,
                        onHoleTap: (hole) => unawaited(_previewHole(hole)),
                      ),
                      SizedBox(height: gap),
                      _HoldStabilityBar(
                        progress: _completed ? 1.0 : _holdProgress,
                        activeTab: widget.target.tab,
                        noteLabel: noteWithOctave,
                        listening: _status == _PracticeStatus.listening,
                      ),
                      SizedBox(height: gap),
                      _GuidanceTile(
                        icon: _guidanceIcon,
                        title: _guidanceTitle(note, cents),
                        detail: _guidanceDetail,
                        color: _guidanceColor(palette, cents),
                        onTap: _completed ? null : _guidanceAction,
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: palette.danger),
                        ),
                      ],
                      if (_status == _PracticeStatus.permanentlyDenied) ...[
                        const SizedBox(height: 4),
                        TextButton.icon(
                          onPressed: _pitchService.openAppSettings,
                          icon: const Icon(Icons.settings_rounded),
                          label: Text(strings.t('commonOpenSettings')),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            minimum: EdgeInsets.fromLTRB(
              AppAdaptive.pagePadding(context),
              0,
              AppAdaptive.pagePadding(context),
              12,
            ),
            child: _ControlDock(
              speed: _guideSpeed,
              loop: _guideLoop,
              completed: _completed,
              hasNextLesson: hasNextLesson,
              guidePlaying: _guidePlaying,
              listening: _status == _PracticeStatus.listening,
              waiting: _status == _PracticeStatus.requestingPermission,
              unsupported: _unsupported,
              onSpeed: _completed ? _restart : _toggleSpeed,
              onPrimary: _handlePrimaryAction,
              onLoop: _toggleLoop,
            ),
          ),
        ],
      ),
    );
  }

  String _tabDescription(AppStrings strings) {
    final hole = widget.target.tab.replaceAll(RegExp(r'[^0-9]'), '');
    return strings.t(widget.target.tab.contains('↓') ? 'drawTab' : 'blowTab', {
      'tab': hole,
    });
  }

  IconData get _guidanceIcon {
    if (_completed) return Icons.check_rounded;
    if (_unsupported) return Icons.help_outline_rounded;
    if (_guidePlaying) return Icons.volume_up_rounded;
    if (_status == _PracticeStatus.listening) {
      return _reading.detected
          ? Icons.graphic_eq_rounded
          : Icons.hearing_rounded;
    }
    if (_status == _PracticeStatus.denied ||
        _status == _PracticeStatus.permanentlyDenied ||
        _status == _PracticeStatus.error) {
      return Icons.mic_off_rounded;
    }
    return Icons.volume_up_rounded;
  }

  VoidCallback get _guidanceAction {
    if (_unsupported) {
      return () => unawaited(showHelpScreen(context));
    }
    if (_status == _PracticeStatus.permanentlyDenied) {
      return _pitchService.openAppSettings;
    }
    if (_status == _PracticeStatus.denied || _status == _PracticeStatus.error) {
      return _requestAndStart;
    }
    return _toggleGuide;
  }

  String _guidanceTitle(String note, double cents) {
    final strings = context.strings;
    if (_completed) return strings.t('pitchStable');
    if (_unsupported) return strings.t('featureUnavailable');
    if (_guidePlaying) return strings.t('guidePlaying');
    if (_status == _PracticeStatus.requestingPermission) {
      return strings.t('requestingPermission');
    }
    if (_status == _PracticeStatus.listening) {
      if (!_reading.detected) return strings.t('listening');
      return strings.t('detectedPitch', {
        'note': _reading.noteWithOctave,
        'cents': '${cents >= 0 ? '+' : ''}${cents.round()}',
      });
    }
    if (_status == _PracticeStatus.permanentlyDenied) {
      return strings.t('permissionOff');
    }
    if (_status == _PracticeStatus.denied) {
      return strings.t('grantMicrophoneAgain');
    }
    if (_status == _PracticeStatus.error) return strings.t('commonRetry');
    return strings.t('hearGuideNote', {'note': note});
  }

  String get _guidanceDetail {
    final strings = context.strings;
    if (_completed) return strings.t('pitchScore', {'score': _score});
    if (_unsupported) return strings.t('useAndroidApp');
    if (_guidePlaying) return strings.t('guidePlayingDetail');
    if (_status == _PracticeStatus.listening) {
      if (_reading.detected &&
          (_stableSince != null || _stableSinceMicros != null)) {
        return strings.t('keepThisPitch');
      }
      return strings.t('waitingStablePitch');
    }
    if (_status == _PracticeStatus.permanentlyDenied) {
      return strings.t('openSettingsForMicrophone');
    }
    if (_status == _PracticeStatus.denied) {
      return strings.t('allowMicrophoneToPractice');
    }
    if (_status == _PracticeStatus.error) {
      return strings.t('microphoneUnavailable');
    }
    return widget.instruction;
  }

  Color _guidanceColor(AppPalette palette, double cents) {
    if (_completed) return palette.success;
    if (_unsupported) return palette.muted;
    if (_status == _PracticeStatus.listening &&
        _reading.detected &&
        cents.abs() <= 35) {
      return palette.success;
    }
    if (_status == _PracticeStatus.denied ||
        _status == _PracticeStatus.permanentlyDenied ||
        _status == _PracticeStatus.error) {
      return palette.danger;
    }
    return palette.accent;
  }
}

class _StageProgress extends StatelessWidget {
  const _StageProgress({
    required this.currentStage,
    required this.complete,
    super.key,
  });

  final int currentStage;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final palette = context.colors;
    final activeLabel = currentStage == 3
        ? strings.t('stageFollow')
        : strings.t('stageSingle');
    return Semantics(
      container: true,
      label: strings.t('stageProgress', {
        'stage': activeLabel,
        'current': currentStage,
      }),
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _StageNode(
            number: 1,
            label: strings.t('stagePrepare'),
            state: _stateFor(1),
          ),
          _StageLine(
            color: currentStage > 2 || complete
                ? palette.success
                : palette.outline,
          ),
          _StageNode(
            number: 2,
            label: strings.t('stageSingle'),
            state: _stateFor(2),
          ),
          _StageLine(color: complete ? palette.success : palette.outline),
          _StageNode(
            number: 3,
            label: strings.t('stageFollow'),
            state: _stateFor(3),
          ),
        ],
      ),
    );
  }

  _StageState _stateFor(int stage) {
    if (complete || stage < currentStage) return _StageState.done;
    if (stage == currentStage) return _StageState.active;
    return _StageState.pending;
  }
}

enum _StageState { done, active, pending }

class _StageNode extends StatelessWidget {
  const _StageNode({
    required this.number,
    required this.label,
    required this.state,
  });

  final int number;
  final String label;
  final _StageState state;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final color = switch (state) {
      _StageState.done => palette.success,
      _StageState.active => palette.primary,
      _StageState.pending => palette.muted,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: AppMotion.duration(context, AppMotion.base),
          curve: AppMotion.standardCurve,
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: state == _StageState.pending ? palette.outline : color,
            ),
          ),
          child: AnimatedSwitcher(
            duration: AppMotion.duration(context, AppMotion.fast),
            child: state == _StageState.done
                ? Icon(
                    Icons.check_rounded,
                    key: ValueKey('done-$number'),
                    color: color,
                    size: 14,
                  )
                : Text(
                    '$number',
                    key: ValueKey('$state-$number'),
                    style: TextStyle(color: color, fontSize: 11),
                  ),
          ),
        ),
        const SizedBox(width: 6),
        AnimatedDefaultTextStyle(
          duration: AppMotion.duration(context, AppMotion.base),
          curve: AppMotion.standardCurve,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: state == _StageState.active
                ? FontWeight.w700
                : FontWeight.w500,
          ),
          child: Text(label),
        ),
      ],
    );
  }
}

class _StageLine extends StatelessWidget {
  const _StageLine({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.duration(context, AppMotion.base),
      curve: AppMotion.standardCurve,
      width: 18,
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: color,
    );
  }
}

class _HoldStabilityBar extends StatelessWidget {
  const _HoldStabilityBar({
    required this.progress,
    required this.activeTab,
    required this.noteLabel,
    required this.listening,
  });

  final double progress;
  final String activeTab;
  final String noteLabel;
  final bool listening;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final clamped = progress.clamp(0.0, 1.0);
    final percent = (clamped * 100).round();
    final activeColor = clamped > 0 ? palette.success : palette.primary;
    return Container(
      key: const Key('practice-hold-bar'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: activeColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$activeTab · $noteLabel',
                  style: TextStyle(
                    color: activeColor,
                    fontFamily: 'monospace',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '$percent%',
                style: TextStyle(
                  color: clamped > 0 ? palette.success : palette.muted,
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: MotionLinearProgress(
              value: clamped,
              minHeight: 6,
              backgroundColor: palette.surfaceHigh,
              color: clamped > 0
                  ? palette.success
                  : listening
                  ? palette.primary
                  : palette.outline,
            ),
          ),
        ],
      ),
    );
  }
}

class _GuidanceTile extends StatelessWidget {
  const _GuidanceTile({
    required this.icon,
    required this.title,
    required this.detail,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Semantics(
      container: true,
      button: onTap != null,
      label: title,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: palette.outline),
        ),
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  TweenAnimationBuilder<Color?>(
                    tween: ColorTween(end: color),
                    duration: AppMotion.duration(context, AppMotion.fast),
                    builder: (context, animatedColor, _) {
                      return AnimatedSwitcher(
                        duration: AppMotion.duration(context, AppMotion.fast),
                        child: Icon(
                          icon,
                          key: ValueKey(icon),
                          color: animatedColor,
                          size: 22,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontSize: 14),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          detail,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  if (onTap != null) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right_rounded, color: palette.accent),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ControlDock extends StatelessWidget {
  const _ControlDock({
    required this.speed,
    required this.loop,
    required this.completed,
    required this.hasNextLesson,
    required this.guidePlaying,
    required this.listening,
    required this.waiting,
    required this.unsupported,
    required this.onSpeed,
    required this.onPrimary,
    required this.onLoop,
  });

  final double speed;
  final bool loop;
  final bool completed;
  final bool hasNextLesson;
  final bool guidePlaying;
  final bool listening;
  final bool waiting;
  final bool unsupported;
  final VoidCallback onSpeed;
  final VoidCallback onPrimary;
  final VoidCallback onLoop;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final strings = context.strings;
    final speedLabel = speed == 1 ? '1×' : '0.5×';
    final completedLabel = hasNextLesson
        ? strings.t('nextLesson')
        : strings.t('commonDone');
    return Container(
      height: 98,
      decoration: BoxDecoration(
        color: palette.surfaceHigh,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: _DockButton(
              icon: completed ? Icons.replay_rounded : Icons.speed_rounded,
              label: completed ? strings.t('practiceAgain') : speedLabel,
              color: palette.muted,
              onTap: unsupported ? null : onSpeed,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              BreathingPulse(
                active: listening && !waiting && !completed,
                color: palette.primary,
                child: Semantics(
                  container: true,
                  button: true,
                  enabled: !waiting,
                  label: completed
                      ? completedLabel
                      : unsupported
                      ? strings.t('help')
                      : guidePlaying
                      ? strings.t('stopGuide')
                      : listening
                      ? strings.t('stopListening')
                      : strings.t('startPractice'),
                  excludeSemantics: true,
                  onTap: waiting ? null : onPrimary,
                  child: FilledButton(
                    key: const Key('practice-primary-control'),
                    onPressed: waiting ? null : onPrimary,
                    style: FilledButton.styleFrom(
                      fixedSize: const Size(56, 56),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: AnimatedSwitcher(
                      duration: AppMotion.duration(context, AppMotion.fast),
                      child: waiting
                          ? const SizedBox(
                              key: ValueKey('waiting'),
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              completed
                                  ? Icons.check_rounded
                                  : unsupported
                                  ? Icons.help_outline_rounded
                                  : guidePlaying || listening
                                  ? Icons.stop_rounded
                                  : Icons.mic_rounded,
                              key: ValueKey((
                                completed,
                                guidePlaying,
                                listening,
                              )),
                              size: 28,
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                completed
                    ? completedLabel
                    : unsupported
                    ? strings.t('help')
                    : guidePlaying
                    ? strings.t('stopGuide')
                    : listening
                    ? strings.t('stopPractice')
                    : strings.t('startPractice'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.primary,
                  fontSize: 10,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _DockButton(
              icon: Icons.repeat_rounded,
              label: strings.t('loop'),
              color: loop ? palette.primary : palette.muted,
              selected: loop,
              onTap: completed || unsupported ? null : onLoop,
            ),
          ),
        ],
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: onTap != null,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: color),
        duration: AppMotion.duration(context, AppMotion.fast),
        builder: (context, animatedColor, _) {
          return InkResponse(
            onTap: onTap,
            radius: 36,
            child: AnimatedContainer(
              duration: AppMotion.duration(context, AppMotion.fast),
              constraints: const BoxConstraints(minWidth: 64, minHeight: 64),
              decoration: BoxDecoration(
                color: selected
                    ? context.colors.primary.withValues(alpha: 0.10)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: animatedColor, size: 25),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: animatedColor,
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CompletionDisplay extends StatelessWidget {
  const _CompletionDisplay({
    required this.score,
    required this.visible,
    super.key,
  });

  final int score;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Column(
      key: const ValueKey('completion'),
      children: [
        AnimatedScale(
          duration: AppMotion.duration(context, AppMotion.base),
          curve: AppMotion.standardCurve,
          scale: visible ? 1 : 0.94,
          child: AnimatedOpacity(
            duration: AppMotion.duration(context, AppMotion.base),
            opacity: visible ? 1 : 0,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                const ChumingBird(
                  size: 76,
                  mood: ChumingMood.celebrating,
                ),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: palette.success,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    color: palette.onPrimary,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          context.strings.t('pitchStable'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(
          context.strings.t('pitchScore', {'score': score}),
          style: TextStyle(color: palette.primary, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
