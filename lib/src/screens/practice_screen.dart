import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/pitch_reading.dart';
import '../models/practice_note.dart';
import '../services/guide_tone_service.dart';
import '../services/haptics.dart';
import '../services/pitch_service.dart';
import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({
    required this.target,
    required this.title,
    required this.lessonId,
    required this.instruction,
    this.step = 1,
    super.key,
  });

  final PracticeNote target;
  final String title;
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
  DateTime? _startedAt;
  String? _errorMessage;
  bool _completed = false;
  bool _guidePlaying = false;
  bool _guideLoop = false;
  bool _resumeAfterGuide = false;
  double _guideSpeed = 1;
  int _score = 0;

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
    if (_status == _PracticeStatus.requestingPermission || _completed) return;
    setState(() {
      _status = _PracticeStatus.requestingPermission;
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
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _status = _PracticeStatus.error;
        _errorMessage = error.message ?? '无法启动麦克风。';
      });
    }
  }

  Future<void> _beginListening() async {
    _subscription ??= _pitchService.readings.listen(
      _onReading,
      onError: (Object _) {
        if (!mounted) return;
        setState(() {
          _status = _PracticeStatus.error;
          _errorMessage = '麦克风读取失败，请重试。';
        });
      },
    );
    final started = await _pitchService.start();
    if (!mounted) return;
    setState(() {
      _status = started ? _PracticeStatus.listening : _PracticeStatus.error;
      _errorMessage = started ? null : '无法启动麦克风，请检查系统设置。';
      _startedAt ??= DateTime.now();
    });
    if (started) await AppHaptics.light(context);
  }

  Future<void> _stopAll({required bool resetStatus}) async {
    _guideTimer?.cancel();
    await Future.wait([_pitchService.stop(), _guideToneService.stop()]);
    if (!mounted) return;
    setState(() {
      _guidePlaying = false;
      _resumeAfterGuide = false;
      _reading = const PitchReading.silent();
      _stableSince = null;
      if (resetStatus && !_completed) _status = _PracticeStatus.idle;
    });
  }

  void _onReading(PitchReading reading) {
    if (!mounted || _status != _PracticeStatus.listening || _completed) return;
    final cents = widget.target.centsFromFrequency(
      reading.frequency,
      AppScope.of(context).harmonicaKey,
    );
    final matches = reading.detected && cents.abs() <= 25;
    final now = DateTime.now();
    if (matches) {
      _stableSince ??= now;
      if (now.difference(_stableSince!).inMilliseconds >= 450) {
        _complete(cents);
        return;
      }
    } else {
      _stableSince = null;
    }
    setState(() => _reading = reading);
  }

  Future<void> _complete(double cents) async {
    if (_completed) return;
    _completed = true;
    _score = (100 - cents.abs() * 1.2).round().clamp(0, 100).toInt();
    final seconds = _startedAt == null
        ? 1
        : DateTime.now()
              .difference(_startedAt!)
              .inSeconds
              .clamp(1, 3600)
              .toInt();
    await Future.wait([
      _pitchService.stop(),
      _guideToneService.stop(),
      AppScope.of(context).markLessonComplete(widget.lessonId),
      AppScope.of(context).recordPractice(seconds: seconds, score: _score),
    ]);
    if (!mounted) return;
    await AppHaptics.success(context);
    if (!mounted) return;
    setState(() {
      _status = _PracticeStatus.idle;
      _guidePlaying = false;
    });
  }

  Future<void> _toggleGuide() async {
    if (_guidePlaying) {
      await _stopGuideAndResume();
      return;
    }

    _resumeAfterGuide = _status == _PracticeStatus.listening;
    if (_resumeAfterGuide) await _pitchService.stop();
    if (!mounted) return;
    setState(() {
      _guidePlaying = true;
      _status = _PracticeStatus.idle;
      _reading = const PitchReading.silent();
      _stableSince = null;
      _errorMessage = null;
    });

    try {
      final duration = await _guideToneService.play(
        frequencies: [
          widget.target.frequencyForKey(AppScope.of(context).harmonicaKey),
        ],
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
        _status = _PracticeStatus.error;
        _errorMessage = error.message ?? '无法播放示范音。';
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
      _completed = false;
      _score = 0;
      _startedAt = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final palette = context.colors;
    final targetFrequency = widget.target.frequencyForKey(
      controller.harmonicaKey,
    );
    final cents = _reading.detected
        ? widget.target.centsFromFrequency(
            _reading.frequency,
            controller.harmonicaKey,
          )
        : 0.0;
    final stableProgress = _stableSince == null
        ? 0.0
        : DateTime.now()
                  .difference(_stableSince!)
                  .inMilliseconds
                  .clamp(0, 450) /
              450;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '第 ${widget.step} 步，共 5 步',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Text(
                '${(widget.step / 5 * 100).round()}%',
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
            child: LinearProgressIndicator(
              value: widget.step / 5,
              minHeight: 6,
              backgroundColor: palette.surfaceHigh,
            ),
          ),
          const SizedBox(height: 26),
          if (_completed)
            _CompletionCard(score: _score)
          else ...[
            Center(
              child: Column(
                children: [
                  const SectionLabel('目标音'),
                  const SizedBox(height: 4),
                  Text(
                    widget.target.labelForKey(controller.harmonicaKey),
                    style: Theme.of(context).textTheme.displaySmall
                        ?.copyWith(fontSize: 54, color: palette.primary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.target.tab} · ${targetFrequency.toStringAsFixed(1)} Hz',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    HarmonicaDiagram(activeTab: widget.target.tab),
                    const SizedBox(height: 16),
                    Text(
                      widget.instruction,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            _DetectedNoteCard(
              reading: _reading,
              cents: cents,
              stableProgress: stableProgress,
              listening: _status == _PracticeStatus.listening,
            ),
          ],
          const SizedBox(height: 16),
          _GuideControls(
            playing: _guidePlaying,
            speed: _guideSpeed,
            loop: _guideLoop,
            onPlay: _completed ? null : _toggleGuide,
            onSpeedChanged: _completed
                ? null
                : (value) async {
                    final wasPlaying = _guidePlaying;
                    if (wasPlaying) await _stopGuideAndResume();
                    if (!context.mounted) return;
                    setState(() => _guideSpeed = value);
                    await AppHaptics.selection(context);
                  },
            onLoopChanged: _completed
                ? null
                : (value) async {
                    final wasPlaying = _guidePlaying;
                    if (wasPlaying) await _stopGuideAndResume();
                    if (!context.mounted) return;
                    setState(() => _guideLoop = value);
                    await AppHaptics.selection(context);
                  },
          ),
          const SizedBox(height: 16),
          if (!_completed)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _status == _PracticeStatus.requestingPermission
                    ? null
                    : _status == _PracticeStatus.listening
                    ? () => _stopAll(resetStatus: true)
                    : _requestAndStart,
                icon: Icon(
                  _status == _PracticeStatus.listening
                      ? Icons.stop_rounded
                      : Icons.mic_rounded,
                ),
                label: Text(_primaryButtonLabel),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _restart,
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('再练一次'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('完成'),
                  ),
                ),
              ],
            ),
          if (_status == _PracticeStatus.permanentlyDenied) ...[
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

  String get _primaryButtonLabel {
    return switch (_status) {
      _PracticeStatus.requestingPermission => '正在请求权限',
      _PracticeStatus.listening => '停止聆听',
      _PracticeStatus.denied => '重新授权麦克风',
      _PracticeStatus.permanentlyDenied => '权限未开启',
      _PracticeStatus.error => '重试',
      _ => '开始练习',
    };
  }
}

class _DetectedNoteCard extends StatelessWidget {
  const _DetectedNoteCard({
    required this.reading,
    required this.cents,
    required this.stableProgress,
    required this.listening,
  });

  final PitchReading reading;
  final double cents;
  final double stableProgress;
  final bool listening;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final matched = reading.detected && cents.abs() <= 25;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  listening ? Icons.graphic_eq_rounded : Icons.mic_off_rounded,
                  color: listening ? palette.success : palette.muted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    listening ? '正在聆听' : '麦克风未启动',
                    style: TextStyle(
                      color: listening ? palette.success : palette.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (reading.detected)
                  Text(
                    '${cents >= 0 ? '+' : ''}${cents.round()} 音分',
                    style: TextStyle(
                      color: matched ? palette.success : palette.accentInk,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              reading.detected ? reading.noteWithOctave : '--',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontSize: 42,
                color: matched ? palette.success : palette.text,
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: stableProgress,
                minHeight: 8,
                backgroundColor: palette.surfaceHigh,
                color: palette.success,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              matched ? '保持这个音' : '稳定匹配约半秒即可完成',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideControls extends StatelessWidget {
  const _GuideControls({
    required this.playing,
    required this.speed,
    required this.loop,
    required this.onPlay,
    required this.onSpeedChanged,
    required this.onLoopChanged,
  });

  final bool playing;
  final double speed;
  final bool loop;
  final VoidCallback? onPlay;
  final ValueChanged<double>? onSpeedChanged;
  final ValueChanged<bool>? onLoopChanged;

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
              onPressed: onPlay,
              icon: Icon(
                playing ? Icons.stop_rounded : Icons.volume_up_rounded,
              ),
              label: Text(playing ? '停止示范' : '播放示范'),
            ),
            SegmentedButton<double>(
              segments: const [
                ButtonSegment(value: 0.5, label: Text('0.5×')),
                ButtonSegment(value: 1, label: Text('1×')),
              ],
              selected: {speed},
              showSelectedIcon: false,
              onSelectionChanged: onSpeedChanged == null
                  ? null
                  : (value) => onSpeedChanged!(value.first),
            ),
            FilterChip(
              selected: loop,
              onSelected: onLoopChanged,
              avatar: const Icon(Icons.repeat_rounded, size: 18),
              label: const Text('循环'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletionCard extends StatelessWidget {
  const _CompletionCard({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: palette.success.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_rounded,
                color: palette.success,
                size: 42,
              ),
            ),
            const SizedBox(height: 16),
            Text('音高稳定', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              '本次得分 $score',
              style: TextStyle(
                color: palette.primary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
