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
import '../widgets/cute_illustrations.dart';
import '../widgets/gesture_guide.dart';
import '../widgets/motion_widgets.dart';
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

class _TunerScreenState extends State<TunerScreen> with WidgetsBindingObserver {
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
      final tab = _tabForReading(reading, AppScope.of(context).harmonicaKey);
      if (tab != null &&
          (_lastPersistedAt == null ||
              now.difference(_lastPersistedAt!).inMilliseconds >= 500)) {
        _lastPersistedAt = now;
        unawaited(
          AppScope.of(context).recordPitchAttempt(
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
    final key = AppScope.of(context).harmonicaKey;
    final palette = context.colors;
    final listening = _status == _TunerStatus.listening;
    final detected = listening && _reading.detected;
    final cents = detected ? _reading.cents.round().clamp(-50, 50).toInt() : 0;
    final tab = detected ? tabForReading(_reading, key) : null;
    final accuracy = AppScope.of(context).weakNoteAccuracy();
    final weakCells = accuracy
        .where((value) => value != null && value < 0.75)
        .length;
    final hasWeakData = accuracy.any((value) => value != null);
    final pagePadding = AppAdaptive.pagePadding(context);
    final cardPadding = AppAdaptive.cardPadding(context);
    final compact = AppAdaptive.isCompact(context);
    final shortViewport = MediaQuery.sizeOf(context).height <= 600;

    return SingleChildScrollView(
      key: const PageStorageKey('tuner'),
      padding: EdgeInsets.fromLTRB(
        pagePadding,
        shortViewport ? 12 : 20,
        pagePadding,
        108,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.strings.t('tuner'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              IconButton.filledTonal(
                tooltip: context.strings.t('tunerSettings'),
                onPressed: _showSettings,
                icon: const Icon(Icons.tune_rounded),
              ),
            ],
          ),
          SizedBox(
            height: shortViewport
                ? 6
                : compact
                ? 12
                : AppAdaptive.groupGap(context) / 1.6,
          ),
          _StatusLine(status: _status, detected: detected),
          SizedBox(
            height: shortViewport
                ? 6
                : compact
                ? 12
                : AppAdaptive.groupGap(context) / 1.6,
          ),
          _NoteDisplay(
            note: detected ? _reading.note : '--',
            octave: detected ? _reading.octave.toString() : '',
            subtitle: tab != null
                ? context.strings.t(tab.isBlow ? 'blowTab' : 'drawTab', {
                    'tab': tab.hole,
                  })
                : detected
                ? '${_reading.frequency.toStringAsFixed(1)} Hz'
                : context.strings.t('waitingSound'),
            active: detected,
          ),
          SizedBox(
            height: shortViewport
                ? 6
                : compact
                ? 14
                : 28,
          ),
          _PitchArc(cents: cents, active: detected),
          SizedBox(height: shortViewport ? 6 : 14),
          Semantics(
            key: const Key('tuner-arc-summary'),
            container: true,
            label: detected
                ? context.strings.t('pitchArcSummary', {
                    'note': _reading.noteWithOctave,
                    'cents': '${cents >= 0 ? '+' : ''}$cents',
                  })
                : _hintText,
            excludeSemantics: true,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Text(
                _hintText,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          SizedBox(
            height: shortViewport
                ? 8
                : compact
                ? 14
                : 22,
          ),
          SizedBox(
            width: double.infinity,
            child: TapGesturePulse(
              enabled: !listening,
              child: FilledButton.icon(
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
          if (_status == _TunerStatus.permanentlyDenied) ...[
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
              style: TextStyle(
                color: _unsupported ? palette.muted : palette.danger,
              ),
            ),
          ],
          SizedBox(
            height: shortViewport
                ? 10
                : compact
                ? 14
                : 18,
          ),
          Card(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                cardPadding,
                cardPadding,
                cardPadding,
                cardPadding - 3,
              ),
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
                  Slider(
                    value: _sensitivity,
                    min: 0,
                    max: 1,
                    divisions: 100,
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

class _PitchArc extends StatelessWidget {
  const _PitchArc({required this.cents, required this.active});

  final int cents;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return _ChartFrame(
      child: Column(
        children: [
          _PitchArcPainter(cents: cents, active: active),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.strings.t('low'),
                style: TextStyle(color: context.colors.muted, fontSize: 11),
              ),
              Text(
                context.strings.t('accurate'),
                style: TextStyle(color: context.colors.primary, fontSize: 11),
              ),
              Text(
                context.strings.t('high'),
                style: TextStyle(color: context.colors.muted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: active ? cents.toDouble() : 0),
            duration: AppMotion.duration(context, AppMotion.fast),
            curve: AppMotion.standardCurve,
            builder: (context, animatedCents, _) {
              final display = animatedCents.round();
              return Text.rich(
                TextSpan(
                  text: active ? '${display >= 0 ? '+' : ''}$display ' : '-- ',
                  style: TextStyle(
                    color: context.colors.text,
                    fontFamily: 'monospace',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                  children: [
                    TextSpan(
                      text: context.strings.t('cents'),
                      style: TextStyle(
                        color: context.colors.muted,
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
              ? 74
              : AppAdaptive.compactValue(context, compact: 104, regular: 128),
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

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.status, required this.detected});

  final _TunerStatus status;
  final bool detected;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final listening = status == _TunerStatus.listening;
    final mood = listening
        ? (detected ? ChumingMood.celebrating : ChumingMood.listening)
        : ChumingMood.idle;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ChumingBird(
          size: 32,
          mood: mood,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: BreathingPulse(
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
        ),
        const SizedBox(width: 8),
        Flexible(
          child: AnimatedSwitcher(
            duration: AppMotion.duration(context, AppMotion.base),
            child: Text(
              listening
                  ? detected
                        ? context.strings.t('pitchDetected')
                        : context.strings.t('listening')
                  : context.strings.t('microphoneNotStarted'),
              key: ValueKey((status, detected)),
              style: TextStyle(
                color: listening ? palette.success : palette.muted,
                fontWeight: FontWeight.w700,
              ),
              softWrap: true,
            ),
          ),
        ),
      ],
    );
  }
}

class _NoteDisplay extends StatelessWidget {
  const _NoteDisplay({
    required this.note,
    required this.octave,
    required this.subtitle,
    required this.active,
  });

  final String note;
  final String octave;
  final String subtitle;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final shortViewport = MediaQuery.sizeOf(context).height <= 600;
    return Column(
      children: [
        SizedBox(
          key: const Key('tuner-note-transition'),
          height: shortViewport
              ? 62
              : AppAdaptive.compactValue(context, compact: 86, regular: 106),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: AppMotion.duration(context, AppMotion.base),
              layoutBuilder: (currentChild, previousChildren) {
                return Stack(
                  alignment: Alignment.topCenter,
                  children: [...previousChildren, ?currentChild],
                );
              },
              child: Stack(
                key: ValueKey('$note$octave'),
                clipBehavior: Clip.none,
                alignment: Alignment.topRight,
                children: [
                  Text(
                    note,
                    style: TextStyle(
                      color: active ? palette.text : palette.muted,
                      fontSize: AppAdaptive.compactValue(
                        context,
                        compact: shortViewport ? 56 : 76,
                        regular: 96,
                      ),
                      height: 1,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                  if (octave.isNotEmpty)
                    Positioned(
                      right: -18,
                      top: 2,
                      child: Text(
                        octave,
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 5),
        AnimatedSwitcher(
          duration: AppMotion.duration(context, AppMotion.fast),
          child: Text(
            subtitle,
            key: ValueKey(subtitle),
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.muted, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
