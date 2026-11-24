import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../localization/app_strings.dart';
import '../models/harmonica_layout.dart';
import '../models/pitch_reading.dart';
import '../services/haptics.dart';
import '../services/pitch_service.dart';
import '../theme/app_adaptive.dart';
import '../theme/app_theme.dart';
import '../state/app_controller.dart';
import '../widgets/cute_illustrations.dart';

enum _DetectState { idle, listening, detected, denied, permanentlyDenied, error }

class HarmonicaRegistrationScreen extends StatefulWidget {
  const HarmonicaRegistrationScreen({
    super.key,
    this.isModal = false,
  });

  /// `false`: 首次启动引导页（允许跳过，默认 C 调）；
  /// `true`: 从调号选择器二级打开（仅用于重新选调或吹 4 孔识调）。
  final bool isModal;

  @override
  State<HarmonicaRegistrationScreen> createState() =>
      _HarmonicaRegistrationScreenState();
}

class _HarmonicaRegistrationScreenState
    extends State<HarmonicaRegistrationScreen> {
  final _pitchService = PitchService();
  StreamSubscription<PitchReading>? _subscription;

  late String _selectedKey;
  bool _initializedKey = false;
  bool _showAllKeys = false;

  _DetectState _detectState = _DetectState.idle;
  String? _errorMessage;
  String? _candidateKey;
  String? _candidateNote;
  int _candidateFrames = 0;
  int _missedFrames = 0;
  int? _candidateStartMicros;
  DateTime? _candidateStartWall;
  double _detectProgress = 0;
  DetectedHarmonicaKey? _detectedResult;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedKey) {
      _initializedKey = true;
      _selectedKey = AppScope.maybeRead(context)?.harmonicaKey ?? 'C';
      if (kSecondaryHarmonicaKeys.contains(_selectedKey)) {
        _showAllKeys = true;
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    unawaited(_pitchService.stop());
    super.dispose();
  }

  Future<void> _toggleDetect() async {
    if (_detectState == _DetectState.listening) {
      await _stopDetecting(preserveResult: false);
      return;
    }
    unawaited(AppHaptics.selection(context));
    setState(() {
      _errorMessage = null;
      _detectedResult = null;
      _resetCandidate();
    });

    MicrophonePermission permission;
    try {
      permission = await _pitchService.requestPermission();
    } on PlatformException {
      if (!mounted) return;
      setState(() {
        _detectState = _DetectState.error;
        _errorMessage = context.strings.t('regDetectUnsupported');
      });
      return;
    }

    if (!mounted) return;
    if (permission == MicrophonePermission.denied) {
      setState(() {
        _detectState = _DetectState.denied;
        _errorMessage = context.strings.t('regDetectDenied');
      });
      return;
    }
    if (permission == MicrophonePermission.permanentlyDenied) {
      setState(() {
        _detectState = _DetectState.permanentlyDenied;
        _errorMessage = context.strings.t('regDetectPermDenied');
      });
      return;
    }

    final sensitivity =
        AppScope.maybeRead(context)?.microphoneSensitivity ?? 0.68;
    _subscription ??= _pitchService.readings.listen(
      _onReading,
      onError: (Object _) => unawaited(_handleStreamError()),
    );

    bool started;
    try {
      started = await _pitchService.start(sensitivity: sensitivity);
    } on PlatformException {
      if (!mounted) return;
      setState(() {
        _detectState = _DetectState.error;
        _errorMessage = context.strings.t('regDetectUnsupported');
      });
      return;
    }

    if (!mounted) return;
    if (!started) {
      setState(() {
        _detectState = _DetectState.error;
        _errorMessage = context.strings.t('microphoneSettingsError');
      });
      return;
    }

    setState(() {
      _detectState = _DetectState.listening;
      _errorMessage = null;
    });
    await AppHaptics.light(context);
  }

  Future<void> _handleStreamError() async {
    await _pitchService.stop();
    if (!mounted) return;
    setState(() {
      _detectState = _DetectState.error;
      _errorMessage = context.strings.t('microphoneReadError');
      _resetCandidate();
    });
  }

  Future<void> _stopDetecting({required bool preserveResult}) async {
    await _pitchService.stop();
    if (!mounted) return;
    setState(() {
      if (!preserveResult) {
        _detectState = _DetectState.idle;
        _detectedResult = null;
      }
      _resetCandidate();
    });
  }

  void _resetCandidate() {
    _candidateKey = null;
    _candidateNote = null;
    _candidateFrames = 0;
    _missedFrames = 0;
    _candidateStartMicros = null;
    _candidateStartWall = null;
    _detectProgress = 0;
  }

  void _onReading(PitchReading reading) {
    if (!mounted || _detectState != _DetectState.listening) return;

    final lowConfidenceNoise =
        reading.confidence > 0 && reading.confidence < 0.65;
    final detected = reading.detected && !lowConfidenceNoise
        ? detectHarmonicaKeyFromHole4Blow(reading.frequency)
        : null;

    if (detected == null || detected.cents.abs() > 40) {
      _missedFrames++;
      if (_missedFrames >= 3 && _candidateKey != null) {
        setState(_resetCandidate);
      }
      return;
    }

    _missedFrames = 0;
    final now = DateTime.now();

    if (_candidateKey != detected.key) {
      setState(() {
        _candidateKey = detected.key;
        _candidateNote = detected.noteLabel;
        _candidateFrames = 1;
        _candidateStartMicros =
            reading.timestampMicros > 0 ? reading.timestampMicros : null;
        _candidateStartWall = now;
        _detectProgress = 0.25;
      });
      return;
    }

    _candidateFrames++;
    _candidateNote = detected.noteLabel;

    final elapsedMs = _elapsedMillis(reading.timestampMicros, now);
    final timeRatio = (elapsedMs / 700.0).clamp(0.0, 1.0);
    final frameRatio = (_candidateFrames / 3.0).clamp(0.0, 1.0);
    final progress = (timeRatio < frameRatio ? timeRatio : frameRatio)
        .clamp(0.25, 1.0);

    if ((_candidateFrames >= 3 && elapsedMs >= 500) || elapsedMs >= 900) {
      unawaited(_finishDetection(detected));
      return;
    }

    setState(() {
      _detectProgress = progress;
    });
  }

  int _elapsedMillis(int timestampMicros, DateTime now) {
    final startMicros = _candidateStartMicros;
    if (startMicros != null && timestampMicros > startMicros) {
      return (timestampMicros - startMicros) ~/ 1000;
    }
    final startWall = _candidateStartWall;
    if (startWall != null) {
      return now.difference(startWall).inMilliseconds;
    }
    return 0;
  }

  Future<void> _finishDetection(DetectedHarmonicaKey result) async {
    await _pitchService.stop();
    if (!mounted) return;
    setState(() {
      _selectedKey = result.key;
      if (kSecondaryHarmonicaKeys.contains(result.key)) {
        _showAllKeys = true;
      }
      _detectedResult = result;
      _detectState = _DetectState.detected;
      _detectProgress = 1.0;
      _errorMessage = null;
    });
    await AppHaptics.success(context);
  }

  Future<void> _skip() async {
    if (_detectState == _DetectState.listening) {
      unawaited(_pitchService.stop());
    }
    unawaited(AppHaptics.selection(context));
    if (widget.isModal) {
      Navigator.of(context).pop();
      return;
    }
    // 允许暂不登记，默认 C 调 10 孔口琴开始体验
    await AppScope.read(context).completeHarmonicaRegistration(key: 'C');
  }

  Future<void> _complete() async {
    if (_detectState == _DetectState.listening) {
      unawaited(_pitchService.stop());
    }
    unawaited(AppHaptics.success(context));
    final controller = AppScope.read(context);
    if (widget.isModal) {
      await controller.setHarmonicaKey(_selectedKey);
      if (mounted) Navigator.of(context).pop(_selectedKey);
      return;
    }
    await controller.completeHarmonicaRegistration(key: _selectedKey);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final palette = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final pagePadding = AppAdaptive.pagePadding(context);

    final birdMood = switch (_detectState) {
      _DetectState.listening => ChumingMood.listening,
      _DetectState.detected => ChumingMood.celebrating,
      _ => ChumingMood.idle,
    };

    final visibleKeys = _showAllKeys
        ? [...kPrimaryHarmonicaKeys, ...kSecondaryHarmonicaKeys]
        : kPrimaryHarmonicaKeys;

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar: brand welcome badge + skip/close button
            Padding(
              padding: EdgeInsets.fromLTRB(pagePadding, 12, pagePadding, 4),
              child: SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.isModal) ...[
                          IconButton(
                            key: const Key('registration-close'),
                            onPressed: _skip,
                            icon: const Icon(Icons.close_rounded),
                            tooltip: strings.t('commonCancel'),
                          ),
                        ] else ...[
                          const HarmonicaBrandIcon(size: 22),
                          const SizedBox(width: 8),
                          Text(
                            strings.t('regWelcomeBadge'),
                            style: textTheme.labelLarge?.copyWith(
                              color: palette.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (!widget.isModal)
                      TextButton(
                        key: const Key('registration-skip'),
                        onPressed: _skip,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(44, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        child: Text(
                          strings.t('regSkip'),
                          style: textTheme.bodyMedium?.copyWith(
                            color: palette.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Scrollable registration content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(pagePadding, 8, pagePadding, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Hero header with Chuming Bird
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: palette.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: palette.outline),
                          ),
                          alignment: Alignment.center,
                          child: ChumingBird(
                            size: 44,
                            mood: birdMood,
                            interactive: false,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                strings.t('regTitle'),
                                style: textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                strings.t('regSubtitle'),
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

                    const SizedBox(height: 18),

                    // Key selection card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: palette.outline),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final key in visibleKeys)
                                ChoiceChip(
                                  key: Key('reg-key-$key'),
                                  label: Text(
                                    strings.t('keyName', {'key': key}),
                                  ),
                                  selected: _selectedKey == key,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.padded,
                                  onSelected: (_) {
                                    unawaited(AppHaptics.selection(context));
                                    setState(() {
                                      _selectedKey = key;
                                      _detectedResult = null;
                                      if (_detectState ==
                                          _DetectState.detected) {
                                        _detectState = _DetectState.idle;
                                      }
                                    });
                                  },
                                ),
                              ActionChip(
                                key: const Key('reg-more-keys'),
                                label: Text(
                                  strings.t(
                                    _showAllKeys
                                        ? 'regLessKeys'
                                        : 'regMoreKeys',
                                  ),
                                ),
                                avatar: Icon(
                                  _showAllKeys
                                      ? Icons.expand_less_rounded
                                      : Icons.expand_more_rounded,
                                  size: 18,
                                ),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.padded,
                                onPressed: () {
                                  unawaited(AppHaptics.selection(context));
                                  setState(
                                    () => _showAllKeys = !_showAllKeys,
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // 10-Hole Blow/Draw Preview Card
                    _TenHoleKeyPreviewCard(
                      key: const Key('reg-hole-preview'),
                      harmonicaKey: _selectedKey,
                    ),

                    const SizedBox(height: 14),

                    // Hole-4 Auto Key Detection Card
                    _Hole4DetectCard(
                      detectState: _detectState,
                      candidateKey: _candidateKey,
                      candidateNote: _candidateNote,
                      progress: _detectProgress,
                      detectedResult: _detectedResult,
                      errorMessage: _errorMessage,
                      onToggleDetect: _toggleDetect,
                      onOpenSettings: _pitchService.openAppSettings,
                    ),
                  ],
                ),
              ),
            ),

            // Bottom CTA bar
            Container(
              padding: EdgeInsets.fromLTRB(pagePadding, 12, pagePadding, 16),
              decoration: BoxDecoration(
                color: palette.surface,
                border: Border(top: BorderSide(color: palette.outline)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton(
                    key: const Key('registration-complete'),
                    onPressed: _complete,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: Text(
                      strings.t('regComplete', {'key': _selectedKey}),
                    ),
                  ),
                  if (!widget.isModal) ...[
                    const SizedBox(height: 8),
                    Text(
                      strings.t('regFooterNote'),
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        color: palette.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TenHoleKeyPreviewCard extends StatelessWidget {
  const _TenHoleKeyPreviewCard({
    super.key,
    required this.harmonicaKey,
  });

  final String harmonicaKey;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final strings = context.strings;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Text(
                strings.t('regPreviewTitle', {'key': harmonicaKey}),
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _LegendPill(
                    label: strings.t('regBlowRow'),
                    color: palette.primary,
                  ),
                  _LegendPill(
                    label: strings.t('regDrawRow'),
                    color: palette.accent,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(10, (index) {
              final hole = index + 1;
              final isHole4 = hole == 4;
              final blowNote = shortNoteNameForHole(
                hole,
                isBlow: true,
                key: harmonicaKey,
              );
              final drawNote = shortNoteNameForHole(
                hole,
                isBlow: false,
                key: harmonicaKey,
              );

              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 1,
                  ),
                  decoration: BoxDecoration(
                    color: isHole4
                        ? palette.success.withValues(alpha: 0.12)
                        : palette.surfaceHigh,
                    borderRadius: BorderRadius.circular(8),
                    border: isHole4
                        ? Border.all(
                            color: palette.success.withValues(alpha: 0.65),
                            width: 1.2,
                          )
                        : null,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          blowNote,
                          style: textTheme.labelSmall?.copyWith(
                            color: palette.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isHole4 ? palette.success : palette.surface,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: isHole4 ? palette.success : palette.outline,
                          ),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '$hole',
                            style: textTheme.labelSmall?.copyWith(
                              color: isHole4 ? Colors.white : palette.text,
                              fontWeight: FontWeight.w800,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          drawNote,
                          style: textTheme.labelSmall?.copyWith(
                            color: palette.accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _LegendPill extends StatelessWidget {
  const _LegendPill({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Hole4DetectCard extends StatelessWidget {
  const _Hole4DetectCard({
    required this.detectState,
    required this.candidateKey,
    required this.candidateNote,
    required this.progress,
    required this.detectedResult,
    required this.errorMessage,
    required this.onToggleDetect,
    required this.onOpenSettings,
  });

  final _DetectState detectState;
  final String? candidateKey;
  final String? candidateNote;
  final double progress;
  final DetectedHarmonicaKey? detectedResult;
  final String? errorMessage;
  final VoidCallback onToggleDetect;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final strings = context.strings;
    final textTheme = Theme.of(context).textTheme;
    final isListening = detectState == _DetectState.listening;
    final isDetected = detectState == _DetectState.detected;

    final borderColor = isDetected
        ? palette.success
        : isListening
        ? palette.primary
        : palette.outline;

    return Container(
      key: const Key('reg-detect-card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: borderColor,
          width: isListening || isDetected ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: (isDetected ? palette.success : palette.primary)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(
                  isDetected
                      ? Icons.check_circle_rounded
                      : isListening
                      ? Icons.graphic_eq_rounded
                      : Icons.mic_none_rounded,
                  size: 20,
                  color: isDetected ? palette.success : palette.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.t('regDetectTitle'),
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      strings.t('regDetectSubtitle'),
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
          const SizedBox(height: 12),
          if (isListening) ...[
            Text(
              candidateKey != null && candidateNote != null
                  ? strings.t('regDetectHolding', {
                      'note': candidateNote!,
                      'key': candidateKey!,
                    })
                  : strings.t('regDetectListening'),
              key: const Key('reg-detect-status'),
              style: textTheme.bodySmall?.copyWith(
                color: palette.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: candidateKey != null ? progress : null,
                minHeight: 6,
                backgroundColor: palette.surfaceHigh,
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (isDetected && detectedResult != null) ...[
            Container(
              key: const Key('reg-detect-result'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: palette.success.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: palette.success.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                strings.t('regDetectSuccess', {
                  'key': detectedResult!.key,
                  'note': detectedResult!.noteLabel,
                }),
                style: textTheme.bodySmall?.copyWith(
                  color: palette.success,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (errorMessage != null) ...[
            Container(
              key: const Key('reg-detect-error'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: palette.warning.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: palette.warning.withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    errorMessage!,
                    style: textTheme.bodySmall?.copyWith(
                      color: palette.text,
                    ),
                  ),
                  if (detectState == _DetectState.permanentlyDenied) ...[
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: onOpenSettings,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(44, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(strings.t('openSettingsBtn')),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            key: const Key('reg-detect-key-btn'),
            onPressed: onToggleDetect,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
            ),
            icon: Icon(
              isListening ? Icons.stop_rounded : Icons.mic_rounded,
              size: 18,
            ),
            label: Text(
              strings.t(isListening ? 'regDetectStop' : 'regDetectStart'),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            strings.t('regWiredTip'),
            style: textTheme.labelSmall?.copyWith(
              color: palette.muted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
