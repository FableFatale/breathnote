import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../localization/app_strings.dart';
import '../models/harmonica_layout.dart';
import '../models/pitch_reading.dart';
import '../services/haptics.dart';
import '../services/pitch_service.dart';
import '../state/app_controller.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';
import '../theme/app_adaptive.dart';
import '../widgets/chuming_coach.dart';
import '../widgets/cute_illustrations.dart';
import '../widgets/gesture_guide.dart';
import '../widgets/harmonica_guide.dart';
import '../widgets/liquid_glass_tab_bar.dart';
import '../widgets/motion_widgets.dart';
import '../widgets/shared_widgets.dart';
import 'help_screen.dart';

class TunerScreen extends StatefulWidget {
  const TunerScreen({required this.active, super.key});

  final bool active;

  @override
  State<TunerScreen> createState() => _TunerScreenState();
}

enum _TunerStatus {
  idle,
  requestingPermission,
  listening,
  denied,
  permanentlyDenied,
  error,
}

class _TunerScreenState extends State<TunerScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final _pitchService = PitchService();
  StreamSubscription<PitchReading>? _subscription;
  PitchReading _reading = const PitchReading.silent();
  _TunerStatus _status = _TunerStatus.idle;
  double _sensitivity = 0.68;
  int _lastSensitivityStep = 68;
  bool _changingSensitivity = false;
  bool _wasInTune = false;
  bool _unsupported = false;
  String? _errorMessage;
  final List<double> _sessionCents = [];
  final Set<int> _verifiedHoles = <int>{};
  double _levelDb = -120;
  DateTime? _lastPersistedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_changingSensitivity) return;
    final savedSensitivity = AppScope.of(context).microphoneSensitivity;
    if ((_sensitivity - savedSensitivity).abs() < 0.001) return;
    _sensitivity = savedSensitivity;
    _lastSensitivityStep = (_sensitivity * 100).round();
  }

  @override
  void didUpdateWidget(covariant TunerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active && !widget.active) {
      _stopListening();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _stopListening();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    _pitchService.stop();
    super.dispose();
  }

  Future<void> _startListening() async {
    if (_status == _TunerStatus.requestingPermission) return;
    setState(() {
      _status = _TunerStatus.requestingPermission;
      _unsupported = false;
      _errorMessage = null;
    });

    try {
      final permission = await _pitchService.requestPermission();
      if (!mounted) return;
      if (permission != MicrophonePermission.granted) {
        setState(() {
          _status = permission == MicrophonePermission.permanentlyDenied
              ? _TunerStatus.permanentlyDenied
              : _TunerStatus.denied;
        });
        return;
      }

      _subscription ??= _pitchService.readings.listen(
        _onReading,
        onError: (Object _) => unawaited(_handleReadingError()),
      );
      setState(() {
        _reading = const PitchReading.silent();
        _sessionCents.clear();
        _levelDb = -120;
        _lastPersistedAt = null;
      });
      final started = await _pitchService.start(sensitivity: _sensitivity);
      if (!mounted) return;
      setState(() {
        _status = started ? _TunerStatus.listening : _TunerStatus.error;
        _errorMessage = started
            ? null
            : context.strings.t('microphoneSettingsError');
      });
      if (started) await AppHaptics.light(context);
    } catch (error) {
      if (!mounted) return;
      final unsupported = _isUnsupportedError(error);
      setState(() {
        _status = _TunerStatus.error;
        _unsupported = unsupported;
        _errorMessage = unsupported
            ? context.strings.t('useAndroidApp')
            : _messageForError(error, 'microphoneStartError');
      });
    }
  }

  Future<void> _stopListening() async {
    await _pitchService.stop();
    if (!mounted) return;
    setState(() {
      _status = _TunerStatus.idle;
      _reading = const PitchReading.silent();
      _wasInTune = false;
      _levelDb = -120;
    });
  }

  Future<void> _handleReadingError() async {
    await _pitchService.stop();
    if (!mounted) return;
    setState(() {
      _status = _TunerStatus.error;
      _reading = const PitchReading.silent();
      _wasInTune = false;
      _levelDb = -120;
      _errorMessage = context.strings.t('microphoneReadError');
    });
  }

  void _onReading(PitchReading reading) {
    if (!mounted || _status != _TunerStatus.listening) return;
    final controller = AppScope.maybeRead(context);
    if (controller == null) return;
    final inTune = reading.detected && reading.cents.abs() <= 5;
    if (inTune && !_wasInTune) {
      AppHaptics.success(context);
    }
    _wasInTune = inTune;
    _levelDb = reading.levelDb;
    if (reading.detected) {
      _sessionCents.add(reading.cents.clamp(-50.0, 50.0).toDouble());
      if (_sessionCents.length > 64) {
        _sessionCents.removeAt(0);
      }
      final now = DateTime.now();
      final detectedTab = tabForReading(reading, controller.harmonicaKey);
      if (detectedTab != null && reading.cents.abs() <= 25) {
        if (_verifiedHoles.add(detectedTab.hole)) {
          unawaited(AppHaptics.reedResonance(context));
        }
      }
      final tab = _tabForReading(reading, controller.harmonicaKey);
      if (tab != null &&
          (_lastPersistedAt == null ||
              now.difference(_lastPersistedAt!).inMilliseconds >= 500)) {
        _lastPersistedAt = now;
        unawaited(
          controller.recordPitchAttempt(
            tab: tab,
            reading: reading,
            cents: reading.cents,
          ),
        );
      }
    }
    setState(() => _reading = reading);
  }

  String? _tabForReading(PitchReading reading, String key) {
    final tab = tabForReading(reading, key);
    if (tab == null) return null;
    return '${tab.hole}${tab.isBlow ? '↑' : '↓'}';
  }

  double get _thresholdDb => -38 - _sensitivity * 34;

  double get _inputLevel {
    if (_levelDb <= -90) return 0;
    return ((_levelDb + 90) / 90).clamp(0.0, 1.0).toDouble();
  }

  double get _thresholdLevel {
    return ((_thresholdDb + 90) / 90).clamp(0.0, 1.0).toDouble();
  }

  String get _distributionSummary {
    if (_sessionCents.length < 5) return context.strings.t('collectingSamples');
    final sorted = [..._sessionCents]..sort();
    final median = pitchSampleMedian(sorted).round();
    final accurate = _sessionCents.where((value) => value.abs() <= 25).length;
    final percent = (accurate / _sessionCents.length * 100).round();
    final direction = median.abs() <= 3
        ? context.strings.t('centered')
        : median < 0
        ? context.strings.t('medianLow')
        : context.strings.t('medianHigh');
    return context.strings.t('distributionSummary', {
      'direction': direction,
      'cents': median.abs(),
      'percent': percent,
    });
  }

  Future<void> _showSettings() async {
    final controller = AppScope.of(context);
    unawaited(AppHaptics.selection(context));
    await showModalBottomSheet<void>(
      context: context,
      sheetAnimationStyle: AppMotion.sheetAnimationStyle(context),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppAdaptive.pagePadding(context),
              4,
              AppAdaptive.pagePadding(context),
              24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.strings.t('tunerSettings'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const HarmonicaBrandIcon(size: 22),
                  title: Text(context.strings.t('currentHarmonica')),
                  trailing: Text(
                    context.strings.t('keyName', {
                      'key': controller.harmonicaKey,
                    }),
                  ),
                ),
                ListTile(
                  key: const Key('tuner-help-setting'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.help_outline_rounded),
                  title: Text(context.strings.t('help')),
                  onTap: () {
                    Navigator.pop(context);
                    unawaited(showHelpScreen(context));
                  },
                ),
                if (_status == _TunerStatus.permanentlyDenied)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _pitchService.openAppSettings();
                      },
                      icon: const Icon(Icons.settings_rounded),
                      label: Text(context.strings.t('commonOpenSettings')),
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
    super.build(context);
    final key = AppScope.of(context).harmonicaKey;
    final palette = context.colors;
    final listening = _status == _TunerStatus.listening;
    final detected = listening && _reading.detected;
    final cents = detected ? _reading.cents.round().clamp(-50, 50).toInt() : 0;
    final activeTabs = detected
        ? tabsForReading(_reading, key)
        : const <HarmonicaTabMatch>[];
    final tab = activeTabs.isEmpty ? null : activeTabs.first;
    final accuracy = AppScope.of(context).weakNoteAccuracy();
    final weakCells = accuracy
        .where((value) => value != null && value < 0.75)
        .length;
    final hasWeakData = accuracy.any((value) => value != null);
    final pagePadding = AppAdaptive.pagePadding(context);
    final cardPadding = AppAdaptive.cardPadding(context);
    final compact = AppAdaptive.isCompact(context);
    final shortViewport = MediaQuery.sizeOf(context).height <= 600;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            key: const PageStorageKey('tuner'),
            padding: EdgeInsets.fromLTRB(
              pagePadding,
              shortViewport ? 10 : 16,
              pagePadding,
              16,
            ),
            child: Column(
              children: [
                TabPageHeader(
                  title: context.strings.t('tuner'),
                  harmonicaKey: key,
                  keyPillKey: const Key('tuner-key-chip'),
                  showCoachTrigger:
                      shortViewport ||
                      AppScope.of(context).seenCoachTips.contains('tuner'),
                  birdMood: detected
                      ? ChumingMood.celebrating
                      : ChumingMood.listening,
                  onReopenCoach: () {
                    unawaited(AppHaptics.reedResonance(context));
                    unawaited(AppScope.of(context).reopenCoachTip('tuner'));
                  },
                  onChooseKey: () {
                    unawaited(AppHaptics.selection(context));
                    unawaited(showHarmonicaKeyPicker(context));
                  },
                  trailingAction: IconButton.filledTonal(
                    tooltip: context.strings.t('tunerSettings'),
                    onPressed: _showSettings,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(40, 40),
                      fixedSize: const Size(40, 40),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.tune_rounded, size: 20),
                  ),
                ),
                if (!shortViewport) ...[
                  const SizedBox(height: 12),
                  const ChumingCoachBanner(
                    featureId: 'tuner',
                    messageKey: 'coachTuner',
                    mood: ChumingMood.listening,
                    bottomSpacing: 4,
                  ),
                ],
                SizedBox(
                  height: shortViewport ? 8 : compact ? 10 : 12,
                ),
                _PitchGaugeCard(
                  listening: listening,
                  detected: detected,
                  inTune: detected && cents.abs() <= 5,
                  hintText: _hintText,
                  note: detected ? _reading.note : '--',
                  octave: detected ? _reading.octave.toString() : '',
                  noteWithOctave: _reading.noteWithOctave,
                  targetLabel: tab != null
                      ? context.strings.t(
                          tab.isBlow ? 'blowTab' : 'drawTab',
                          {'tab': tab.hole},
                        )
                      : detected
                      ? '${_reading.frequency.toStringAsFixed(1)} Hz'
                      : null,
                  cents: cents,
                ),
                SizedBox(
                  height: shortViewport ? 8 : compact ? 10 : 12,
                ),
                KeyedSubtree(
                  key: const Key('tuner-hole-checkup'),
                  child: _UnifiedTenHoleCard(
                    key: const Key('tuner-live-hole-strip'),
                    harmonicaKey: key,
                    activeTabs: activeTabs,
                    detectedNote: detected ? _reading.noteWithOctave : null,
                    inTune: detected && cents.abs() <= 10,
                    verifiedHoles: _verifiedHoles,
                    onToggleHole: (hole) {
                      unawaited(AppHaptics.selection(context));
                      setState(() {
                        if (!_verifiedHoles.remove(hole)) {
                          _verifiedHoles.add(hole);
                        }
                      });
                    },
                    onReset: () {
                      unawaited(AppHaptics.selection(context));
                      setState(_verifiedHoles.clear);
                    },
                  ),
                ),
                SizedBox(
                  height: shortViewport
                      ? 10
                      : compact
                      ? 12
                      : 14,
                ),
                Card(
            child: Padding(
              padding: EdgeInsets.all(cardPadding),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.strings.t('detectionSensitivity'),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        tooltip: context.strings.t('helpSensitivityTitle'),
                        onPressed: () => unawaited(
                          showHelpScreen(
                            context,
                            section: HelpSection.sensitivity,
                          ),
                        ),
                        icon: const Icon(Icons.info_outline_rounded, size: 18),
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints.tightFor(
                          width: 40,
                          height: 40,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${(_sensitivity * 100).round()}%',
                            style: TextStyle(
                              color: palette.primary,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  _SensitivitySlider(
                    key: const Key('tuner-sensitivity-slider'),
                    value: _sensitivity,
                    onChanged: (value) {
                      _changingSensitivity = true;
                      final step = (value * 100).round();
                      if (step != _lastSensitivityStep) {
                        _lastSensitivityStep = step;
                        AppHaptics.selection(context);
                      }
                      setState(() => _sensitivity = value);
                      if (listening) _pitchService.setSensitivity(value);
                    },
                    onChangeEnd: (value) {
                      _changingSensitivity = false;
                      unawaited(
                        AppScope.of(context).setMicrophoneSensitivity(value),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  Semantics(
                    key: const Key('tuner-input-level'),
                    container: true,
                    label: context.strings.t('inputLevel', {
                      'level': (_inputLevel * 100).round(),
                      'threshold': _thresholdDb.round(),
                    }),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: SizedBox(
                        height: 8,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: ColoredBox(color: palette.surfaceHigh),
                            ),
                            FractionallySizedBox(
                              widthFactor: _inputLevel,
                              child: ColoredBox(
                                color: _reading.detected
                                    ? palette.primary
                                    : palette.muted,
                              ),
                            ),
                            Align(
                              alignment: Alignment(_thresholdLevel * 2 - 1, 0),
                              child: Container(width: 2, color: palette.accent),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
          if (listening || _sessionCents.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SessionDistribution(
              key: const Key('tuner-session-distribution'),
              samples: List.unmodifiable(_sessionCents),
              summary: _distributionSummary,
            ),
          ],
          if (hasWeakData) ...[
            const SizedBox(height: 16),
            _WeakNoteMap(
              key: const Key('tuner-weak-note-map'),
              accuracy: accuracy,
              weakCells: weakCells,
            ),
          ],
          const SizedBox(height: 14),
              ],
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.25, 1.0],
              colors: [
                palette.background.withValues(alpha: 0.0),
                palette.background.withValues(alpha: 0.94),
                palette.background,
              ],
            ),
          ),
          padding: EdgeInsets.fromLTRB(
            pagePadding,
            8,
            pagePadding,
            floatingNavBarClearance(context, extra: 12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _unsupported ? palette.muted : palette.danger,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              if (_status == _TunerStatus.permanentlyDenied) ...[
                TextButton.icon(
                  onPressed: _pitchService.openAppSettings,
                  icon: const Icon(Icons.settings_rounded),
                  label: Text(context.strings.t('commonOpenSettings')),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              SizedBox(
                width: double.infinity,
                child: TapGesturePulse(
                  enabled: !listening,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: _unsupported
                        ? () => unawaited(showHelpScreen(context))
                        : _status == _TunerStatus.requestingPermission
                        ? null
                        : listening
                        ? _stopListening
                        : _startListening,
                    icon: Icon(
                      _unsupported
                          ? Icons.help_outline_rounded
                          : listening
                          ? Icons.stop_rounded
                          : Icons.mic_rounded,
                    ),
                    label: Text(
                      _unsupported
                          ? context.strings.t('help')
                          : listening
                          ? context.strings.t('stopTuning')
                          : _primaryButtonLabel,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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

  String get _hintText {
    final strings = context.strings;
    if (_unsupported) return strings.t('featureUnavailable');
    if (_status == _TunerStatus.denied) {
      return strings.t('permissionNeededForTuner');
    }
    if (_status == _TunerStatus.permanentlyDenied) {
      return strings.t('permissionClosed');
    }
    if (_status == _TunerStatus.error) {
      return strings.t('microphoneUnavailable');
    }
    if (_status != _TunerStatus.listening) return strings.t('tapToTune');
    if (!_reading.detected) return strings.t('blowStableNote');
    if (_reading.cents.abs() <= 5) return strings.t('inTuneKeep');
    return _reading.cents < 0 ? strings.t('pitchLow') : strings.t('pitchHigh');
  }

  String get _primaryButtonLabel {
    final strings = context.strings;
    return switch (_status) {
      _TunerStatus.requestingPermission => strings.t('requestingPermission'),
      _TunerStatus.denied => strings.t('grantMicrophoneAgain'),
      _TunerStatus.permanentlyDenied => strings.t('permissionOff'),
      _TunerStatus.error => strings.t('commonRetry'),
      _ => strings.t('startTuning'),
    };
  }
}

class _PitchGaugeCard extends StatelessWidget {
  const _PitchGaugeCard({
    required this.listening,
    required this.detected,
    required this.inTune,
    required this.hintText,
    required this.note,
    required this.octave,
    required this.noteWithOctave,
    required this.targetLabel,
    required this.cents,
  });

  final bool listening;
  final bool detected;
  final bool inTune;
  final String hintText;
  final String note;
  final String octave;
  final String noteWithOctave;
  final String? targetLabel;
  final int cents;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final shortViewport = MediaQuery.sizeOf(context).height <= 600;
    final statusAccent = listening
        ? (detected && inTune ? palette.success : palette.primary)
        : palette.muted;

    return _ChartFrame(
      child: Column(
        children: [
          Row(
            children: [
              BreathingPulse(
                active: listening,
                color: palette.success,
                shape: BoxShape.circle,
                child: AnimatedContainer(
                  duration: AppMotion.duration(context, AppMotion.fast),
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: listening ? palette.success : palette.muted,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AnimatedSwitcher(
                  duration: AppMotion.duration(context, AppMotion.fast),
                  layoutBuilder: (currentChild, previousChildren) {
                    return Stack(
                      alignment: Alignment.centerLeft,
                      children: [...previousChildren, ?currentChild],
                    );
                  },
                  child: Align(
                    key: ValueKey(hintText),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      hintText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: listening
                            ? (inTune ? palette.success : palette.text)
                            : palette.muted,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: shortViewport ? 6 : 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                key: const Key('tuner-note-transition'),
                height: shortViewport ? 48 : 58,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: AnimatedSwitcher(
                    duration: AppMotion.duration(context, AppMotion.base),
                    layoutBuilder: (currentChild, previousChildren) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [...previousChildren, ?currentChild],
                      );
                    },
                    child: Row(
                      key: ValueKey('$note$octave'),
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          note,
                          style: TextStyle(
                            color: detected ? palette.text : palette.muted,
                            fontSize: shortViewport ? 44 : 54,
                            height: 1,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                        if (octave.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 3, left: 2),
                            child: Text(
                              octave,
                              style: TextStyle(
                                color: palette.muted,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (detected && targetLabel != null) ...[
                const SizedBox(width: 12),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: statusAccent.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Text(
                      targetLabel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: statusAccent,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: shortViewport ? 6 : 8),
          _PitchArcPainter(cents: cents, active: detected),
          const SizedBox(height: 6),
          Semantics(
            key: const Key('tuner-arc-summary'),
            container: true,
            label: detected
                ? context.strings.t('pitchArcSummary', {
                    'note': noteWithOctave,
                    'cents': '${cents >= 0 ? '+' : ''}$cents',
                  })
                : '-- ${context.strings.t('cents')}',
            excludeSemantics: true,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.strings.t('low'),
                      style: TextStyle(color: palette.muted, fontSize: 11),
                    ),
                    Text(
                      context.strings.t('accurate'),
                      style: TextStyle(color: palette.primary, fontSize: 11),
                    ),
                    Text(
                      context.strings.t('high'),
                      style: TextStyle(color: palette.muted, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    begin: 0,
                    end: detected ? cents.toDouble() : 0,
                  ),
                  duration: AppMotion.duration(context, AppMotion.fast),
                  curve: AppMotion.standardCurve,
                  builder: (context, animatedCents, _) {
                    final display = animatedCents.round();
                    return Text.rich(
                      TextSpan(
                        text: detected
                            ? '${display >= 0 ? '+' : ''}$display '
                            : '-- ',
                        style: TextStyle(
                          color: palette.text,
                          fontFamily: 'monospace',
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                        children: [
                          TextSpan(
                            text: context.strings.t('cents'),
                            style: TextStyle(
                              color: palette.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PitchArcPainter extends StatelessWidget {
  const _PitchArcPainter({required this.cents, required this.active});

  final int cents;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final shortViewport = MediaQuery.sizeOf(context).height <= 600;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: active ? cents.toDouble() : 0),
      duration: AppMotion.duration(context, AppMotion.fast),
      curve: AppMotion.standardCurve,
      builder: (context, animatedCents, _) {
        return SizedBox(
          height: shortViewport
              ? 68
              : AppAdaptive.compactValue(context, compact: 80, regular: 92),
          child: CustomPaint(
            key: const Key('tuner-segmented-arc'),
            painter: _SegmentedArcPainter(
              cents: animatedCents.round(),
              active: active,
              primary: context.colors.primary,
              accent: context.colors.accent,
              outline: context.colors.outline,
            ),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }
}

class _SegmentedArcPainter extends CustomPainter {
  const _SegmentedArcPainter({
    required this.cents,
    required this.active,
    required this.primary,
    required this.accent,
    required this.outline,
  });

  final int cents;
  final bool active;
  final Color primary;
  final Color accent;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 1.03);
    final radius = math.min(size.width * 0.43, size.height * 0.93);
    const count = 31;
    final gap = 0.012;
    final sweep = math.pi / count - gap;
    final normalized = active ? (cents + 50) / 100 : 0.5;
    final selected = (normalized * count).round().clamp(0, count - 1);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 7;
    for (var index = 0; index < count; index++) {
      final start = math.pi + index * math.pi / count + gap / 2;
      final distance = (index - 15).abs();
      final isCenter = distance <= 3;
      final isSelected = active && index == selected;
      paint.color = isSelected
          ? (distance > 7 ? accent : primary)
          : isCenter
          ? primary.withValues(alpha: 0.82)
          : outline;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SegmentedArcPainter old) {
    return old.cents != cents ||
        old.active != active ||
        old.primary != primary ||
        old.accent != accent ||
        old.outline != outline;
  }
}

class _SensitivitySlider extends StatefulWidget {
  const _SensitivitySlider({
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
    super.key,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  @override
  State<_SensitivitySlider> createState() => _SensitivitySliderState();
}

class _SensitivitySliderState extends State<_SensitivitySlider> {
  double? _dragValue;

  double _quantize(double raw) {
    return (raw.clamp(0.0, 1.0) * 100).round() / 100.0;
  }

  double _valueFromDx(double dx, double width) {
    const horizontalInset = 12.0;
    final usableWidth = (width - horizontalInset * 2).clamp(1.0, double.infinity);
    final ratio = (dx - horizontalInset) / usableWidth;
    return _quantize(ratio);
  }

  void _commitDragEnd(double fallback) {
    final finalValue = _dragValue ?? fallback;
    _dragValue = null;
    widget.onChangeEnd(finalValue);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final clamped = (_dragValue ?? widget.value).clamp(0.0, 1.0);
    final percent = (clamped * 100).round();

    return Semantics(
      slider: true,
      value: '$percent%',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : 240.0;
          const horizontalInset = 12.0;
          const thumbSize = 22.0;
          final usableWidth =
              (width - horizontalInset * 2).clamp(1.0, double.infinity);
          final thumbCenterX = horizontalInset + usableWidth * clamped;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              final next = _valueFromDx(details.localPosition.dx, width);
              _dragValue = null;
              widget.onChanged(next);
              widget.onChangeEnd(next);
            },
            onHorizontalDragStart: (details) {
              final next = _valueFromDx(details.localPosition.dx, width);
              _dragValue = next;
              widget.onChanged(next);
            },
            onHorizontalDragUpdate: (details) {
              final next = _valueFromDx(details.localPosition.dx, width);
              _dragValue = next;
              widget.onChanged(next);
            },
            onHorizontalDragEnd: (_) => _commitDragEnd(_quantize(clamped)),
            onHorizontalDragCancel: () => _commitDragEnd(_quantize(clamped)),
            child: SizedBox(
              height: 44,
              width: double.infinity,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Positioned(
                    left: horizontalInset,
                    right: horizontalInset,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: palette.surfaceHigh,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: palette.outline.withValues(alpha: 0.7),
                          width: 0.5,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: horizontalInset,
                    width: (usableWidth * clamped).clamp(0.0, usableWidth),
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: palette.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Positioned(
                    left: (thumbCenterX - thumbSize / 2).clamp(
                      0.0,
                      (width - thumbSize).clamp(0.0, double.infinity),
                    ),
                    child: Container(
                      width: thumbSize,
                      height: thumbSize,
                      decoration: BoxDecoration(
                        color: palette.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: palette.primary, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: palette.primary.withValues(alpha: 0.22),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
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

class _SessionDistribution extends StatelessWidget {
  const _SessionDistribution({
    required this.samples,
    required this.summary,
    super.key,
  });

  final List<double> samples;
  final String summary;

  @override
  Widget build(BuildContext context) {
    return _ChartFrame(
      title: context.strings.t('sessionPitch'),
      trailing: context.strings.t('sampleCount', {'count': samples.length}),
      helpSection: HelpSection.charts,
      child: Column(
        children: [
          SizedBox(
            height: 92,
            child: CustomPaint(
              key: const Key('tuner-dot-distribution'),
              painter: _DotDistributionPainter(
                samples: samples,
                primary: context.colors.primary,
                accent: context.colors.accent,
                outline: context.colors.outline,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('−50', style: _coordinateStyle(context)),
              Text('0', style: _coordinateStyle(context)),
              Text('+50', style: _coordinateStyle(context)),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              summary,
              style: TextStyle(color: context.colors.text, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

TextStyle _coordinateStyle(BuildContext context) {
  return TextStyle(
    color: context.colors.muted,
    fontFamily: 'monospace',
    fontSize: 11,
  );
}

class _DotDistributionPainter extends CustomPainter {
  const _DotDistributionPainter({
    required this.samples,
    required this.primary,
    required this.accent,
    required this.outline,
  });

  final List<double> samples;
  final Color primary;
  final Color accent;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final accurateHalf = size.width * 0.25;
    final background = Paint()
      ..color = primary.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          centerX - accurateHalf,
          8,
          accurateHalf * 2,
          size.height - 16,
        ),
        const Radius.circular(8),
      ),
      background,
    );
    final line = Paint()
      ..color = outline
      ..strokeWidth = 1;
    canvas.drawLine(Offset(centerX, 0), Offset(centerX, size.height), line);
    canvas.drawLine(Offset(0, centerY), Offset(size.width, centerY), line);

    final binCounts = List<int>.filled(21, 0);
    for (final sample in samples) {
      final cents = sample.clamp(-50.0, 50.0).toDouble();
      final bin = ((cents + 50) / 5).round().clamp(0, 20).toInt();
      final stackIndex = binCounts[bin]++;
      final x = 8 + bin / 20 * (size.width - 16);
      final level = stackIndex ~/ 2 + 1;
      final direction = stackIndex.isEven ? -1 : 1;
      final y = (centerY + direction * level * 7.0)
          .clamp(6.0, size.height - 6.0)
          .toDouble();
      final dot = Paint()
        ..color = cents.abs() > 25 ? accent : primary
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), 3.2, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _DotDistributionPainter old) {
    return shouldRepaintPitchSamples(old.samples, samples) ||
        old.primary != primary ||
        old.accent != accent ||
        old.outline != outline;
  }
}

@visibleForTesting
bool shouldRepaintPitchSamples(List<double> previous, List<double> next) {
  return !listEquals(previous, next);
}

@visibleForTesting
double pitchSampleMedian(List<double> sortedSamples) {
  if (sortedSamples.isEmpty) return 0;
  final middle = sortedSamples.length ~/ 2;
  if (sortedSamples.length.isOdd) return sortedSamples[middle];
  return (sortedSamples[middle - 1] + sortedSamples[middle]) / 2;
}

class _WeakNoteMap extends StatelessWidget {
  const _WeakNoteMap({
    required this.accuracy,
    required this.weakCells,
    super.key,
  });

  final List<double?> accuracy;
  final int weakCells;

  @override
  Widget build(BuildContext context) {
    final trailing = weakCells == 0
        ? context.strings.t('noWeakNotes')
        : context.strings.t('weakNoteCount', {'count': weakCells});
    return _ChartFrame(
      title: context.strings.t('weakNoteMap'),
      trailing: trailing,
      helpSection: HelpSection.charts,
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 28),
              ...List.generate(10, (index) {
                return Expanded(
                  child: Text(
                    '${index + 1}',
                    textAlign: TextAlign.center,
                    style: _coordinateStyle(context),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 6),
          for (final row in [0, 1]) ...[
            _WeakNoteRow(
              label: context.strings.t(row == 0 ? 'blowShort' : 'drawShort'),
              values: accuracy.sublist(row * 10, row * 10 + 10),
            ),
            if (row == 0) const SizedBox(height: 6),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _WeakNoteRow extends StatelessWidget {
  const _WeakNoteRow({required this.label, required this.values});

  final String label;
  final List<double?> values;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 28,
          child: Text(label, style: _coordinateStyle(context)),
        ),
        ...values.map((value) {
          final color = value == null
              ? context.colors.surfaceHigh
              : value < 0.5
              ? context.colors.accent
              : Color.lerp(
                  context.colors.accent,
                  context.colors.primary,
                  value,
                )!;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: AspectRatio(
                aspectRatio: 1,
                child: AnimatedContainer(
                  duration: AppMotion.duration(context, AppMotion.base),
                  curve: AppMotion.standardCurve,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: context.colors.outline),
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _ChartFrame extends StatelessWidget {
  const _ChartFrame({
    required this.child,
    this.title,
    this.trailing,
    this.helpSection,
  });

  final Widget child;
  final String? title;
  final String? trailing;
  final HelpSection? helpSection;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final shortViewport = MediaQuery.sizeOf(context).height <= 600;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppAdaptive.cardPadding(context),
        shortViewport ? 10 : 14,
        AppAdaptive.cardPadding(context),
        shortViewport ? 10 : 14,
      ),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.outline),
      ),
      child: Column(
        children: [
          if (title != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    title!,
                    style: Theme.of(context).textTheme.titleMedium,
                    softWrap: true,
                  ),
                ),
                if (helpSection != null)
                  IconButton(
                    tooltip: context.strings.t('help'),
                    onPressed: () => unawaited(
                      showHelpScreen(context, section: helpSection!),
                    ),
                    icon: const Icon(Icons.info_outline_rounded, size: 18),
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(
                      width: 40,
                      height: 40,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      trailing!,
                      style: _coordinateStyle(context),
                      textAlign: TextAlign.end,
                      softWrap: true,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
          ],
          child,
        ],
      ),
    );
  }
}

/// 调音器合并十孔音位 & 新琴体检卡片：支持 2↓ / 3↑ 同音同时点亮、吹准自动打卡与轻点手动标记。
class _UnifiedTenHoleCard extends StatelessWidget {
  const _UnifiedTenHoleCard({
    required this.harmonicaKey,
    required this.activeTabs,
    required this.detectedNote,
    required this.inTune,
    required this.verifiedHoles,
    required this.onToggleHole,
    required this.onReset,
    super.key,
  });

  final String harmonicaKey;
  final List<HarmonicaTabMatch> activeTabs;
  final String? detectedNote;
  final bool inTune;
  final Set<int> verifiedHoles;
  final ValueChanged<int> onToggleHole;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final strings = context.strings;
    final hasActive = activeTabs.isNotEmpty && detectedNote != null;
    final activeLabels = activeTabs
        .map((match) => '${match.hole}${match.isBlow ? '↑' : '↓'}')
        .join(' / ');
    final allClear = verifiedHoles.length == 10;

    return _ChartFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  strings.t('tunerUnifiedHolesTitle'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (hasActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: (inTune ? palette.success : palette.primary)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$activeLabels · $detectedNote',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: inTune ? palette.success : palette.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: (allClear ? palette.success : palette.primary)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        strings.t('tenHoleCheckupProgress', {
                          'count': verifiedHoles.length,
                        }),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: allClear ? palette.success : palette.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (verifiedHoles.isNotEmpty)
                      IconButton(
                        key: const Key('reset-hole-checkup'),
                        tooltip: strings.t('tenHoleCheckupReset'),
                        onPressed: onReset,
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints.tightFor(
                          width: 28,
                          height: 28,
                        ),
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          Icons.refresh_rounded,
                          size: 16,
                          color: palette.muted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(10, (index) {
              final hole = index + 1;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: index == 0 ? 0 : 3),
                  child: _buildHoleCell(context, hole),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              allClear
                  ? strings.t('tenHoleCheckupAllClear')
                  : strings.t('tunerUnifiedHolesHint'),
              style: TextStyle(
                color: allClear ? palette.success : palette.muted,
                fontSize: 11.5,
                fontWeight: allClear ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHoleCell(BuildContext context, int hole) {
    final palette = context.colors;
    HarmonicaTabMatch? match;
    for (final candidate in activeTabs) {
      if (candidate.hole == hole) {
        match = candidate;
        break;
      }
    }
    final isActive = match != null;
    final isBlow = match?.isBlow ?? true;
    final verified = verifiedHoles.contains(hole);
    final activeColor = inTune
        ? palette.success
        : (isBlow ? palette.primary : palette.accent);
    final highlightColor = isActive
        ? activeColor
        : verified
        ? palette.success
        : null;
    final noteName = isActive
        ? shortNoteNameForHole(hole, isBlow: isBlow, key: harmonicaKey)
        : shortNoteNameForHole(hole, isBlow: true, key: harmonicaKey);

    return GestureDetector(
      key: Key('checkup-hole-$hole'),
      behavior: HitTestBehavior.opaque,
      onTap: () => onToggleHole(hole),
      child: AnimatedContainer(
        key: Key('tuner-hole-cell-$hole'),
        duration: AppMotion.duration(context, AppMotion.fast),
        constraints: const BoxConstraints(minHeight: 44),
        decoration: BoxDecoration(
          color: highlightColor != null
              ? highlightColor.withValues(alpha: isActive ? 0.16 : 0.12)
              : palette.surfaceHigh.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: highlightColor ?? palette.outline,
            width: isActive || verified ? 1.5 : 1.0,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isActive ? '$hole${isBlow ? '↑' : '↓'}' : '$hole',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w800,
                        color: highlightColor ?? palette.text,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      noteName,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: isActive || verified
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: highlightColor ?? palette.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (verified)
              Positioned(
                top: 2,
                right: 2,
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 10,
                  color: highlightColor ?? palette.success,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
