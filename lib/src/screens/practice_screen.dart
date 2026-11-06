import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../localization/app_strings.dart';
import '../models/pitch_reading.dart';
import '../models/practice_note.dart';
import '../models/song.dart';
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
      unawaited(_stopAll(resetStatus: true));
    }
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
        _errorMessage =
            error.message ?? context.strings.t('microphoneStartError');
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
          _errorMessage = context.strings.t('microphoneReadError');
        });
      },
    );
    final started = await _pitchService.start(
      sensitivity: AppScope.of(context).microphoneSensitivity,
    );
    if (!mounted) return;
    setState(() {
      _status = started ? _PracticeStatus.listening : _PracticeStatus.error;
      _errorMessage = started
          ? null
          : context.strings.t('microphoneSettingsError');
      _startedAt ??= DateTime.now();
    });
    if (started) await AppHaptics.light(context);
  }

  Future<void> _stopListening() async {
    await _pitchService.stop();
    if (!mounted) return;
    setState(() {
      _status = _PracticeStatus.idle;
      _reading = const PitchReading.silent();
      _stableSince = null;
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
        unawaited(_complete(cents));
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
    if (_completed) return;
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
        _errorMessage = error.message ?? context.strings.t('guideToneError');
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
    if (_completed) return;
    if (_guidePlaying) {
      _resumeAfterGuide = false;
      await _stopGuideAndResume();
    }
    if (!mounted) return;
    setState(() => _guideSpeed = _guideSpeed == 1 ? 0.5 : 1);
    await AppHaptics.selection(context);
  }

  Future<void> _toggleLoop() async {
    if (_completed) return;
    if (_guidePlaying) {
      _resumeAfterGuide = false;
      await _stopGuideAndResume();
    }
    if (!mounted) return;
    setState(() => _guideLoop = !_guideLoop);
    await AppHaptics.selection(context);
  }

  Future<void> _restart() async {
    await _stopAll(resetStatus: true);
    if (!mounted) return;
    setState(() {
      _completed = false;
      _score = 0;
      _startedAt = null;
      _errorMessage = null;
    });
  }

  Future<void> _handlePrimaryAction() async {
    if (_completed) {
      Navigator.of(context).pop();
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

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final palette = context.colors;
    final strings = context.strings;
    final noteWithOctave = widget.target.labelForKey(controller.harmonicaKey);
    final note = noteWithOctave.replaceAll(RegExp(r'\d+$'), '');
    final cents = _reading.detected
        ? widget.target.centsFromFrequency(
            _reading.frequency,
            controller.harmonicaKey,
          )
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 84,
        backgroundColor: palette.surfaceHigh,
        titleSpacing: 4,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.lessonTitle(widget.lessonId),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 2),
            Text(
              strings.t('lessonSubtitle', {'number': widget.step}),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: MaterialLocalizations.of(context).showMenuTooltip,
            icon: const Icon(Icons.more_horiz_rounded),
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
              child: Column(
                children: [
                  const _StageProgress(),
                  const SizedBox(height: 28),
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
                  const SizedBox(height: 24),
                  AnimatedSwitcher(
                    duration: controller.reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 240),
                    child: _completed
                        ? _CompletionDisplay(score: _score)
                        : Column(
                            key: const ValueKey('target-note'),
                            children: [
                              Text(
                                note,
                                style: TextStyle(
                                  color: palette.primary,
                                  fontFamily: 'serif',
                                  fontSize: 82,
                                  height: 1,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                strings.lessonInstruction(widget.lessonId),
                                style: TextStyle(
                                  color: palette.muted,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 38),
                  HarmonicaDiagram(activeTab: widget.target.tab),
                  const SizedBox(height: 26),
                  _UpcomingNotes(activeTab: widget.target.tab),
                  const SizedBox(height: 34),
                  _GuidanceTile(
                    icon: _guidanceIcon,
                    title: _guidanceTitle(noteWithOctave, cents),
                    detail: _guidanceDetail,
                    color: _guidanceColor(palette, cents),
                    onTap: _completed ? null : _toggleGuide,
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
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
            ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(4, 0, 4, 4),
            child: _ControlDock(
              speed: _guideSpeed,
              loop: _guideLoop,
              completed: _completed,
              active: _guidePlaying || _status == _PracticeStatus.listening,
              waiting: _status == _PracticeStatus.requestingPermission,
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
    return Icons.multiline_chart_rounded;
  }

  String _guidanceTitle(String note, double cents) {
    final strings = context.strings;
    if (_completed) return strings.t('pitchStable');
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
    return strings.t('playTargetNote', {'note': note});
  }

  String get _guidanceDetail {
    final strings = context.strings;
    if (_completed) return strings.t('score', {'score': _score});
    if (_guidePlaying) return strings.t('guidePlayingDetail');
    if (_status == _PracticeStatus.listening) {
      if (_reading.detected && _stableSince != null) {
        return strings.t('keepThisPitch');
      }
      return strings.t('waitingStablePitch');
    }
    return widget.instruction.isEmpty
        ? strings.t('tapPlayToStart')
        : widget.instruction;
  }

  Color _guidanceColor(AppPalette palette, double cents) {
    if (_completed) return palette.success;
    if (_status == _PracticeStatus.listening &&
        _reading.detected &&
        cents.abs() <= 25) {
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
  const _StageProgress();

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final palette = context.colors;
    return Semantics(
      label: '${strings.t('stageSingle')}, 2 / 3',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _StageNode(label: strings.t('stagePrepare'), state: _StageState.done),
          _StageLine(color: palette.outline),
          _StageNode(
            label: strings.t('stageSingle'),
            state: _StageState.active,
          ),
          _StageLine(color: palette.outline),
          _StageNode(
            label: strings.t('stageFollow'),
            state: _StageState.pending,
          ),
        ],
      ),
    );
  }
}

enum _StageState { done, active, pending }

class _StageNode extends StatelessWidget {
  const _StageNode({required this.label, required this.state});

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
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: state == _StageState.pending ? palette.outline : color,
            ),
          ),
          child: state == _StageState.done
              ? Icon(Icons.check_rounded, color: color, size: 18)
              : Text(
                  state == _StageState.active ? '2' : '3',
                  style: TextStyle(color: color, fontSize: 12),
                ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: state == _StageState.active
                ? FontWeight.w700
                : FontWeight.w500,
          ),
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
    return Container(
      width: 30,
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: color,
    );
  }
}

class _UpcomingNotes extends StatelessWidget {
  const _UpcomingNotes({required this.activeTab});

  final String activeTab;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final preview = songs.first.notes;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(preview.length, (index) {
        final note = preview[index];
        final active = index == 1 && note.tab == activeTab;
        final direction = note.tab.contains('↓') ? '↓' : '↑';
        final hole = note.tab.replaceAll(RegExp(r'[^0-9]'), '');
        return Opacity(
          opacity: index == 0 ? 0.35 : 1,
          child: Column(
            children: [
              Text(
                hole,
                style: TextStyle(
                  color: active ? palette.primary : palette.muted,
                  fontSize: 20,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                direction,
                style: TextStyle(
                  color: active ? palette.primary : palette.muted,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 5),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: active ? palette.accent : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        );
      }),
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
    return Material(
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: palette.outline),
      ),
      elevation: Theme.of(context).brightness == Brightness.light ? 1 : 0,
      shadowColor: const Color(0x242A2118),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 96),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Icon(icon, color: color, size: 25),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        detail,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(fontSize: 12),
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
    );
  }
}

class _ControlDock extends StatelessWidget {
  const _ControlDock({
    required this.speed,
    required this.loop,
    required this.completed,
    required this.active,
    required this.waiting,
    required this.onSpeed,
    required this.onPrimary,
    required this.onLoop,
  });

  final double speed;
  final bool loop;
  final bool completed;
  final bool active;
  final bool waiting;
  final VoidCallback onSpeed;
  final VoidCallback onPrimary;
  final VoidCallback onLoop;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final strings = context.strings;
    return Container(
      height: 112,
      decoration: BoxDecoration(
        color: palette.surfaceHigh,
        borderRadius: BorderRadius.circular(32),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: _DockButton(
              icon: completed ? Icons.replay_rounded : Icons.speed_rounded,
              label: completed ? strings.t('practiceAgain') : '$speed×',
              color: palette.muted,
              onTap: onSpeed,
            ),
          ),
          const SizedBox(width: 14),
          Semantics(
            button: true,
            label: completed
                ? strings.t('commonDone')
                : active
                ? strings.t('stopListening')
                : strings.t('startPractice'),
            child: FilledButton(
              key: const Key('practice-primary-control'),
              onPressed: waiting ? null : onPrimary,
              style: FilledButton.styleFrom(
                fixedSize: const Size(84, 84),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: waiting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      completed
                          ? Icons.check_rounded
                          : active
                          ? Icons.stop_rounded
                          : Icons.play_arrow_rounded,
                      size: 34,
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _DockButton(
              icon: Icons.repeat_rounded,
              label: strings.t('loop'),
              color: loop ? palette.primary : palette.muted,
              selected: loop,
              onTap: completed ? null : onLoop,
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
    return InkResponse(
      onTap: onTap,
      radius: 36,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 64, minHeight: 64),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 25),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletionDisplay extends StatelessWidget {
  const _CompletionDisplay({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Column(
      key: const ValueKey('completion'),
      children: [
        Container(
          width: 82,
          height: 82,
          decoration: BoxDecoration(
            color: palette.success.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check_rounded, color: palette.success, size: 46),
        ),
        const SizedBox(height: 12),
        Text(
          context.strings.t('pitchStable'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(
          context.strings.t('score', {'score': score}),
          style: TextStyle(color: palette.primary, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
