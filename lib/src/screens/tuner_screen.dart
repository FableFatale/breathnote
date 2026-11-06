import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/harmonica_layout.dart';
import '../models/pitch_reading.dart';
import '../services/haptics.dart';
import '../services/pitch_service.dart';
import '../state/app_controller.dart';
import '../theme/app_theme.dart';
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
  int _lastSensitivityStep = 14;
  bool _wasInTune = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
            _errorMessage = '麦克风读取失败，请重试。';
          });
        },
      );
      final started = await _pitchService.start(sensitivity: _sensitivity);
      if (!mounted) return;
      setState(() {
        _status = started ? _TunerStatus.listening : _TunerStatus.error;
        _errorMessage = started ? null : '无法启动麦克风，请检查系统设置。';
      });
      if (started) await AppHaptics.light(context);
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _status = _TunerStatus.error;
        _errorMessage = error.message ?? '无法启动麦克风。';
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
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('调音设置', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.piano_rounded),
                  title: const Text('当前口琴'),
                  trailing: Text('${controller.harmonicaKey} 调'),
                ),
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.lock_outline_rounded),
                  title: Text('本地音频处理'),
                  subtitle: Text('原始麦克风音频不会离开设备，也不会保存。'),
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
                      label: const Text('打开系统设置'),
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
    final hole = detected ? tabForReading(_reading, key) : null;

    return SingleChildScrollView(
      key: const PageStorageKey('tuner'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '音准',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              IconButton.filledTonal(
                tooltip: '调音设置',
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
            subtitle:
                hole ??
                (detected
                    ? '${_reading.frequency.toStringAsFixed(1)} Hz'
                    : '等待声音'),
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
                      const Expanded(
                        child: Text(
                          '检测灵敏度',
                          style: TextStyle(fontWeight: FontWeight.w700),
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
                    min: 0.2,
                    max: 1,
                    onChanged: (value) {
                      final step = (value * 20).round();
                      if (step != _lastSensitivityStep) {
                        _lastSensitivityStep = step;
                        AppHaptics.selection(context);
                      }
                      setState(() => _sensitivity = value);
                      if (listening) _pitchService.setSensitivity(value);
                    },
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '环境较吵时可适当调低',
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
              label: Text(listening ? '停止调音' : _primaryButtonLabel),
            ),
          ),
          if (_status == _TunerStatus.permanentlyDenied) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _pitchService.openAppSettings,
              icon: const Icon(Icons.settings_rounded),
              label: const Text('打开系统设置'),
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
    if (_status == _TunerStatus.denied) return '需要麦克风权限才能检测音准';
    if (_status == _TunerStatus.permanentlyDenied) {
      return '麦克风权限已关闭，请到系统设置中开启';
    }
    if (_status == _TunerStatus.error) return '麦克风暂时不可用';
    if (_status != _TunerStatus.listening) return '点击下方按钮开始调音';
    if (!_reading.detected) return '请吹一个稳定的单音';
    if (_reading.cents.abs() <= 5) return '音准稳定，保持住';
    return _reading.cents < 0 ? '音高偏低，气息稍微加强' : '音高偏高，放松一点';
  }

  String get _primaryButtonLabel {
    return switch (_status) {
      _TunerStatus.requestingPermission => '正在请求权限',
      _TunerStatus.denied => '重新授权麦克风',
      _TunerStatus.permanentlyDenied => '权限未开启',
      _TunerStatus.error => '重试',
      _ => '开始调音',
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
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: listening ? palette.success : palette.muted,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          listening
              ? detected
                    ? '已检测到音高'
                    : '正在聆听'
              : '麦克风未启动',
          style: TextStyle(
            color: listening ? palette.success : palette.muted,
            fontWeight: FontWeight.w700,
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
          height: 106,
          child: Stack(
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
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: TextStyle(color: palette.muted, fontWeight: FontWeight.w600),
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
            Text('偏低', style: TextStyle(color: palette.muted, fontSize: 12)),
            Text('准确', style: TextStyle(color: palette.success, fontSize: 12)),
            Text('偏高', style: TextStyle(color: palette.muted, fontSize: 12)),
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
              Align(
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
        Text.rich(
          TextSpan(
            text: active ? '${cents >= 0 ? '+' : ''}$cents ' : '-- ',
            style: TextStyle(
              color: active ? palette.text : palette.muted,
              fontSize: 25,
              fontWeight: FontWeight.w800,
            ),
            children: [
              TextSpan(
                text: '音分',
                style: TextStyle(
                  color: palette.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
