import 'dart:async';

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
import '../widgets/motion_widgets.dart';
import '../widgets/shared_widgets.dart';

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
  String? _errorMessage;

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
        onError: (Object _) {
          if (!mounted) return;
          setState(() {
            _status = _TunerStatus.error;
            _errorMessage = context.strings.t('microphoneReadError');
          });
        },
      );
      final started = await _pitchService.start(sensitivity: _sensitivity);
      if (!mounted) return;
      setState(() {
        _status = started ? _TunerStatus.listening : _TunerStatus.error;
        _errorMessage = started
            ? null
            : context.strings.t('microphoneSettingsError');
      });
      if (started) await AppHaptics.light(context);
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _status = _TunerStatus.error;
        _errorMessage =
            error.message ?? context.strings.t('microphoneStartError');
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
    });
  }

  void _onReading(PitchReading reading) {
    if (!mounted || _status != _TunerStatus.listening) return;
    final inTune = reading.detected && reading.cents.abs() <= 5;
    if (inTune && !_wasInTune) {
      AppHaptics.success(context);
    }
    _wasInTune = inTune;
    setState(() => _reading = reading);
  }

  Future<void> _showSettings() async {
    final controller = AppScope.of(context);
    unawaited(AppHaptics.selection(context));
    await showModalBottomSheet<void>(
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
                  context.strings.t('tunerSettings'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.piano_rounded),
                  title: Text(context.strings.t('currentHarmonica')),
                  trailing: Text(
                    context.strings.t('keyName', {
                      'key': controller.harmonicaKey,
                    }),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.lock_outline_rounded),
                  title: Text(context.strings.t('localAudioProcessing')),
                  subtitle: Text(
                    context.strings.t('localAudioProcessingDetail'),
                  ),
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

    return SingleChildScrollView(
      key: const PageStorageKey('tuner'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
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
          const SizedBox(height: 24),
          _StatusLine(status: _status, detected: detected),
          const SizedBox(height: 22),
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
          const SizedBox(height: 28),
          _PitchScale(cents: cents, active: detected),
          const SizedBox(height: 14),
          Text(
            _hintText,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 22),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 13),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.strings.t('detectionSensitivity'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        '${(_sensitivity * 100).round()}%',
                        style: TextStyle(
                          color: palette.primary,
                          fontWeight: FontWeight.w800,
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
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      context.strings.t('sensitivityHint'),
                      style: TextStyle(color: palette.muted, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _status == _TunerStatus.requestingPermission
                  ? null
                  : listening
                  ? _stopListening
                  : _startListening,
              icon: Icon(listening ? Icons.stop_rounded : Icons.mic_rounded),
              label: Text(
                listening
                    ? context.strings.t('stopTuning')
                    : _primaryButtonLabel,
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
              style: TextStyle(color: palette.danger),
            ),
          ],
          const SizedBox(height: 14),
          const PrivacyNote(),
        ],
      ),
    );
  }

  String get _hintText {
    final strings = context.strings;
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

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.status, required this.detected});

  final _TunerStatus status;
  final bool detected;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final listening = status == _TunerStatus.listening;
    return Row(
      mainAxisSize: MainAxisSize.min,
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
        AnimatedSwitcher(
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
    return Column(
      children: [
        SizedBox(
          key: const Key('tuner-note-transition'),
          height: 106,
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
                    fontSize: 96,
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
        const SizedBox(height: 5),
        AnimatedSwitcher(
          duration: AppMotion.duration(context, AppMotion.fast),
          child: Text(
            subtitle,
            key: ValueKey(subtitle),
            style: TextStyle(color: palette.muted, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _PitchScale extends StatelessWidget {
  const _PitchScale({required this.cents, required this.active});

  final int cents;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.strings.t('low'),
              style: TextStyle(color: palette.muted, fontSize: 12),
            ),
            Text(
              context.strings.t('accurate'),
              style: TextStyle(color: palette.success, fontSize: 12),
            ),
            Text(
              context.strings.t('high'),
              style: TextStyle(color: palette.muted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(21, (index) {
                  final major = index % 5 == 0;
                  return Container(
                    width: major ? 2 : 1,
                    height: major ? 22 : 11,
                    color: index == 10 ? palette.success : palette.outline,
                  );
                }),
              ),
              AnimatedAlign(
                key: const Key('tuner-cent-indicator'),
                duration: AppMotion.duration(context, AppMotion.fast),
                curve: AppMotion.standardCurve,
                alignment: Alignment(active ? cents / 50 : 0, -1),
                child: Icon(
                  Icons.arrow_drop_down_rounded,
                  color: active ? palette.primary : palette.muted,
                  size: 36,
                ),
              ),
            ],
          ),
        ),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: active ? cents.toDouble() : 0),
          duration: AppMotion.duration(context, AppMotion.fast),
          curve: AppMotion.standardCurve,
          builder: (context, animatedCents, _) {
            final displayCents = animatedCents.round();
            return Text.rich(
              TextSpan(
                text: active
                    ? '${displayCents >= 0 ? '+' : ''}$displayCents '
                    : '-- ',
                style: TextStyle(
                  color: active ? palette.text : palette.muted,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                ),
                children: [
                  TextSpan(
                    text: context.strings.t('cents'),
                    style: TextStyle(
                      color: palette.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
