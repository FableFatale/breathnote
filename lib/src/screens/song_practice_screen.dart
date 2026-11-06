import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/pitch_reading.dart';
import '../models/song.dart';
import '../services/guide_tone_service.dart';
import '../services/haptics.dart';
import '../services/pitch_service.dart';
import '../state/app_controller.dart';
import '../theme/app_theme.dart';
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
  DateTime? _startedAt;
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
          _status = _SongStatus.error;
          _errorMessage = '麦克风读取失败，请重试。';
        });
      },
    );
    final started = await _pitchService.start();
    if (!mounted) return;
    setState(() {
      _status = started ? _SongStatus.listening : _SongStatus.error;
      _errorMessage = started ? null : '无法启动麦克风，请检查系统设置。';
      _startedAt ??= DateTime.now();
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
    if (matches) {
      _stableSince ??= now;
      if (now.difference(_stableSince!).inMilliseconds >= 420) {
        _advance(cents.abs());
        return;
      }
    } else {
      _stableSince = null;
    }
    setState(() => _reading = reading);
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
        _finishing = false;
      });
      return;
    }

    _completed = true;
    _score = (100 - _matchedError / widget.song.notes.length * 1.4)
        .round()
        .clamp(0, 100)
        .toInt();
    final seconds =
        (_startedAt == null
                ? 1
                : DateTime.now().difference(_startedAt!).inSeconds)
            .clamp(1, 3600)
            .toInt();
    final futures = <Future<void>>[
      _pitchService.stop(),
      _guideToneService.stop(),
      AppScope.of(context).recordPractice(seconds: seconds, score: _score),
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
    await Future.wait([_pitchService.stop(), _guideToneService.stop()]);
    if (!mounted) return;
    setState(() {
      _guidePlaying = false;
      _resumeAfterGuide = false;
      _reading = const PitchReading.silent();
      _stableSince = null;
      if (resetStatus && !_completed) _status = _SongStatus.idle;
    });
  }

  Future<void> _toggleGuide() async {
    if (_guidePlaying) {
      await _stopGuideAndResume();
      return;
    }
    _resumeAfterGuide = _status == _SongStatus.listening;
    if (_resumeAfterGuide) await _pitchService.stop();
    if (!mounted) return;
    setState(() {
      _guidePlaying = true;
      _status = _SongStatus.idle;
      _reading = const PitchReading.silent();
      _stableSince = null;
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
        _errorMessage = error.message ?? '无法播放示范旋律。';
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
      _startedAt = null;
    });
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
      appBar: AppBar(title: Text(widget.song.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _completed
                      ? '练习完成'
                      : '第 ${_index + 1} 个音，共 ${widget.song.notes.length} 个',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
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
              value: progress,
              minHeight: 6,
              backgroundColor: palette.surfaceHigh,
            ),
          ),
          const SizedBox(height: 22),
          if (_completed)
            _SongCompletion(score: _score)
          else ...[
            Center(
              child: Column(
                children: [
                  const SectionLabel('当前目标'),
                  const SizedBox(height: 4),
                  Text(
                    target.labelForKey(controller.harmonicaKey),
                    style: Theme.of(context).textTheme.displaySmall
                        ?.copyWith(fontSize: 54, color: palette.primary),
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
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    HarmonicaDiagram(activeTab: target.tab),
                    const SizedBox(height: 16),
                    _Sequence(song: widget.song, currentIndex: _index),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Icon(
                      _status == _SongStatus.listening
                          ? Icons.graphic_eq_rounded
                          : Icons.mic_off_rounded,
                      color: _status == _SongStatus.listening
                          ? palette.success
                          : palette.muted,
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
                                ? '等待稳定音高'
                                : '麦克风未启动',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (_reading.detected)
                            Text(
                              '${cents >= 0 ? '+' : ''}${cents.round()} 音分',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                    if (_stableSince != null)
                      Icon(Icons.check_circle_rounded, color: palette.success),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          _SongGuideControls(
            playing: _guidePlaying,
            speed: _guideSpeed,
            loop: _guideLoop,
            enabled: !_completed,
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
          const SizedBox(height: 16),
          if (!_completed)
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
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _restart,
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('重新练习'),
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
          if (_status == _SongStatus.permanentlyDenied) ...[
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

  String get _buttonLabel {
    return switch (_status) {
      _SongStatus.requestingPermission => '正在请求权限',
      _SongStatus.listening => '停止练习',
      _SongStatus.denied => '重新授权麦克风',
      _SongStatus.permanentlyDenied => '权限未开启',
      _SongStatus.error => '重试',
      _ => '开始曲谱练习',
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
          duration: AppScope.of(context).reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 160),
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
              label: Text(playing ? '停止示范' : '播放旋律'),
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
              label: const Text('循环'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SongCompletion extends StatelessWidget {
  const _SongCompletion({required this.score});

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
            Text('旋律完成', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              '本次得分 $score',
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
