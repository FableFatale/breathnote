import 'dart:async';

import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../services/haptics.dart';
import '../state/app_controller.dart';
import '../theme/app_adaptive.dart';
import '../theme/app_theme.dart';
import '../widgets/cute_illustrations.dart';
import '../widgets/gesture_guide.dart';
import 'lesson_routes.dart';

class BreathLessonScreen extends StatefulWidget {
  const BreathLessonScreen({super.key});

  @override
  State<BreathLessonScreen> createState() => _BreathLessonScreenState();
}

class _BreathLessonScreenState extends State<BreathLessonScreen> {
  static const _phaseDurationMs = 3000;
  static const _tickMs = 100;
  static const _targetRounds = 2;

  Timer? _timer;
  bool _running = false;
  bool _isBlowPhase = true;
  int _phaseElapsedMs = 0;
  int _completedRounds = 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _togglePacer() {
    unawaited(AppHaptics.selection(context));
    if (_running) {
      _timer?.cancel();
      setState(() => _running = false);
      return;
    }
    if (_completedRounds >= _targetRounds) {
      setState(() {
        _completedRounds = 0;
        _isBlowPhase = true;
        _phaseElapsedMs = 0;
      });
    }
    setState(() => _running = true);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: _tickMs), (_) {
      if (!mounted) return;
      setState(() {
        _phaseElapsedMs += _tickMs;
        if (_phaseElapsedMs >= _phaseDurationMs) {
          _phaseElapsedMs = 0;
          if (_isBlowPhase) {
            _isBlowPhase = false;
            unawaited(AppHaptics.light(context));
          } else {
            _isBlowPhase = true;
            _completedRounds++;
            if (_completedRounds >= _targetRounds) {
              _running = false;
              _timer?.cancel();
              unawaited(AppHaptics.success(context));
            } else {
              unawaited(AppHaptics.light(context));
            }
          }
        }
      });
    });
  }

  Future<void> _completeLesson() async {
    _timer?.cancel();
    final controller = AppScope.read(context);
    await controller.markLessonComplete('lesson_breath');
    await controller.recordPractice(
      seconds: 30,
      score: 0,
      updateBestScore: false,
    );
    if (!mounted) return;
    await AppHaptics.success(context);
  }

  void _openNextLesson() {
    _timer?.cancel();
    final nextId = nextLessonId('lesson_breath');
    if (nextId == null) return;
    unawaited(AppHaptics.selection(context));
    Navigator.of(context).pushReplacement(
      lessonRoute(context, lessonById(nextId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final strings = context.strings;
    final palette = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final pagePadding = AppAdaptive.pagePadding(context);
    final isComplete = controller.completedLessons.contains('lesson_breath');
    final roundsDone = _completedRounds >= _targetRounds;

    final birdMood = roundsDone
        ? ChumingMood.celebrating
        : !_running
        ? ChumingMood.idle
        : _isBlowPhase
        ? ChumingMood.blowing
        : ChumingMood.drawing;

    final phaseLabel = roundsDone
        ? strings.t('breathPhaseDone')
        : !_running
        ? strings.t('breathPhaseReady')
        : _isBlowPhase
        ? strings.t('breathPhaseBlow')
        : strings.t('breathPhaseDraw');

    final phaseColor = roundsDone
        ? palette.success
        : !_running
        ? palette.muted
        : _isBlowPhase
        ? palette.primary
        : palette.accent;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.lessonTitle('lesson_breath')),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(pagePadding, 12, pagePadding, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero summary card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: palette.outline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.t('breathHeroTitle'),
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      strings.t('breathHeroSubtitle'),
                      style: textTheme.bodyMedium?.copyWith(
                        color: palette.muted,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 12),
                    BreathGestureGuide(
                      isBlow: _isBlowPhase,
                      label: _isBlowPhase
                          ? strings.t('blow')
                          : strings.t('draw'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 3 Technique cards
              _BreathTipTile(
                icon: Icons.self_improvement_rounded,
                color: palette.primary,
                title: strings.t('breathTip1Title'),
                body: strings.t('breathTip1Body'),
              ),
              const SizedBox(height: 10),
              _BreathTipTile(
                icon: Icons.air_rounded,
                color: palette.success,
                title: strings.t('breathTip2Title'),
                body: strings.t('breathTip2Body'),
              ),
              const SizedBox(height: 10),
              _BreathTipTile(
                icon: Icons.record_voice_over_rounded,
                color: palette.accent,
                title: strings.t('breathTip3Title'),
                body: strings.t('breathTip3Body'),
              ),
              const SizedBox(height: 16),

              // Interactive Breath Pacer
              Container(
                key: const Key('breath-pacer-card'),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _running || roundsDone
                        ? phaseColor
                        : palette.outline,
                    width: _running || roundsDone ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        ChumingBird(
                          size: 46,
                          mood: birdMood,
                          interactive: false,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                strings.t('breathPacerTitle', {
                                  'done': _completedRounds.clamp(
                                    0,
                                    _targetRounds,
                                  ),
                                }),
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                phaseLabel,
                                style: textTheme.bodySmall?.copyWith(
                                  color: phaseColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: roundsDone
                            ? 1.0
                            : _running
                            ? (_phaseElapsedMs / _phaseDurationMs).clamp(
                                0.0,
                                1.0,
                              )
                            : 0.0,
                        minHeight: 8,
                        color: phaseColor,
                        backgroundColor: palette.surfaceHigh,
                      ),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      key: const Key('breath-pacer-toggle'),
                      onPressed: _togglePacer,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                      ),
                      icon: Icon(
                        _running
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      label: Text(
                        strings.t(
                          _running ? 'breathStopBtn' : 'breathStartBtn',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              if (isComplete) ...[
                FilledButton.icon(
                  key: const Key('breath-next-lesson'),
                  onPressed: _openNextLesson,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(strings.t('nextLesson')),
                ),
              ] else ...[
                FilledButton(
                  key: const Key('breath-complete-btn'),
                  onPressed: _completeLesson,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  child: Text(strings.t('markLessonComplete')),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BreathTipTile extends StatelessWidget {
  const _BreathTipTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: textTheme.bodySmall?.copyWith(
                    color: palette.muted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
