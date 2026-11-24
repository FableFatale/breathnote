import 'dart:async';

import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../models/song.dart';
import '../models/song_score.dart';
import '../services/guide_tone_service.dart';
import '../services/haptics.dart';
import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import 'cute_illustrations.dart';
import 'pro_paywall_sheet.dart';
import 'shared_widgets.dart';

/// 曲谱完成 / 评分报告卡片：
/// - 免费与 Pro 用户均可见：总分、1–3 星级、成就分享卡片；
/// - Pro 用户解锁：三维细分评分（音准/节奏/稳定）、可复听逐音回顾条、针对性改进要点。
class SongScoreReportCard extends StatefulWidget {
  const SongScoreReportCard({
    required this.score,
    required this.song,
    required this.title,
    required this.iconId,
    this.summary,
    super.key,
  });

  final int score;
  final Song song;
  final String title;
  final String iconId;
  final SongScoreSummary? summary;

  @override
  State<SongScoreReportCard> createState() => _SongScoreReportCardState();
}

class _SongScoreReportCardState extends State<SongScoreReportCard> {
  final _guideToneService = GuideToneService();
  int? _playingNoteIndex;

  @override
  void dispose() {
    _guideToneService.stop();
    super.dispose();
  }

  Future<void> _previewNote(NoteScoreRecord record) async {
    final key = AppScope.maybeRead(context)?.harmonicaKey ?? 'C';
    unawaited(AppHaptics.selection(context));
    setState(() => _playingNoteIndex = record.index);
    try {
      await _guideToneService.play(
        frequencies: [record.note.frequencyForKey(key)],
        speed: 1,
        repeat: false,
      );
    } catch (_) {
      // Ignore audio errors on unsupported platforms/tests.
    }
    if (!mounted) return;
    Future<void>.delayed(const Duration(milliseconds: 450), () {
      if (mounted && _playingNoteIndex == record.index) {
        setState(() => _playingNoteIndex = null);
      }
    });
  }

  String _coachTipText(BuildContext context, SongScoreSummary summary) {
    final strings = context.strings;
    final tab = summary.weakestTab;
    final status = summary.weakestStatus;
    if (tab == null || status == null || status == NoteScoreStatus.accurate) {
      return strings.t('scoringCoachPerfect');
    }
    return switch (status) {
      NoteScoreStatus.missed => strings.t('scoringCoachMissed', {'tab': tab}),
      NoteScoreStatus.flat => strings.t('scoringCoachFlat', {'tab': tab}),
      NoteScoreStatus.sharp => strings.t('scoringCoachSharp', {'tab': tab}),
      NoteScoreStatus.accurate => strings.t('scoringCoachPerfect'),
    };
  }

  bool get _hasSamePitchHoles => widget.song.notes.any(
    (note) => note.tab == '2↓' || note.tab == '3↑',
  );

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final palette = context.colors;
    final strings = context.strings;
    final summary = widget.summary;
    final totalScore = summary?.totalScore ?? widget.score;
    final stars = summary?.stars ?? starsForSongScore(totalScore);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: const ChumingBird(
                size: 68,
                mood: ChumingMood.celebrating,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              summary != null
                  ? strings.t('scoringResultTitle')
                  : strings.t('melodyComplete'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            // 星级展示（1–3 星，所有人可见）
            Row(
              key: const Key('score-stars-row'),
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) {
                final earned = index < stars;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Icon(
                    earned ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 30,
                    color: earned
                        ? const Color(0xFFF59E0B)
                        : palette.outline,
                  ),
                );
              }),
            ),
            const SizedBox(height: 6),
            Text(
              strings.t('pitchScore', {'score': totalScore}),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.primary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (summary != null) ...[
              const SizedBox(height: 6),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  _MiniStatChip(
                    icon: Icons.check_circle_outline_rounded,
                    label: '${summary.hitCount}/${summary.totalNotes}',
                    color: palette.success,
                  ),
                  _MiniStatChip(
                    icon: Icons.local_fire_department_rounded,
                    label: strings.t('scoringCombo', {
                      'count': summary.maxCombo,
                    }),
                    color: palette.accent,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            Center(
              child: OutlinedButton.icon(
                key: const Key('share-achievement-card'),
                onPressed: () => showAchievementCardSheet(
                  context,
                  title: widget.title,
                  score: totalScore,
                  iconId: widget.iconId,
                  songId: widget.song.id,
                  tabPreview: widget.song.tabPreview,
                ),
                icon: const Icon(Icons.workspace_premium_rounded, size: 18),
                label: Text(strings.t('shareAchievementBtn')),
              ),
            ),
            if (summary != null) ...[
              const SizedBox(height: 18),
              Divider(color: palette.outline, height: 1),
              const SizedBox(height: 16),
              if (controller.isProUnlocked)
                _buildProDiagnostics(context, summary)
              else
                _buildProLockedTeaser(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProDiagnostics(
    BuildContext context,
    SongScoreSummary summary,
  ) {
    final palette = context.colors;
    final strings = context.strings;

    return Column(
      key: const Key('score-pro-diagnostics'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. 三维细分评分：音准 / 节奏 / 稳定
        Row(
          children: [
            Expanded(
              child: _DimensionScoreCard(
                key: const Key('score-dim-pitch'),
                label: strings.t('scoringDimPitch'),
                score: summary.pitchScore,
                color: palette.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _DimensionScoreCard(
                key: const Key('score-dim-timing'),
                label: strings.t('scoringDimTiming'),
                score: summary.timingScore,
                color: palette.accent,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _DimensionScoreCard(
                key: const Key('score-dim-stability'),
                label: strings.t('scoringDimStability'),
                score: summary.stabilityScore,
                color: palette.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // 2. 逐音回顾条（点击复听示范音）
        Text(
          strings.t('scoringNoteReviewTitle'),
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Wrap(
          key: const Key('score-note-review'),
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final record in summary.notes)
              _NoteReviewChip(
                key: Key('note-review-chip-${record.index}'),
                record: record,
                playing: _playingNoteIndex == record.index,
                onTap: () => _previewNote(record),
              ),
          ],
        ),
        const SizedBox(height: 16),
        // 3. 针对性改进要点建议
        Container(
          key: const Key('score-coach-tip'),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: palette.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: palette.primary.withValues(alpha: 0.24),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.tips_and_updates_rounded,
                    size: 16,
                    color: palette.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    strings.t('scoringCoachTitle'),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: palette.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _coachTipText(context, summary),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(height: 1.45),
              ),
              if (_hasSamePitchHoles) ...[
                const SizedBox(height: 6),
                Text(
                  strings.t('scoringCoachSamePitchNote'),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: palette.muted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProLockedTeaser(BuildContext context) {
    final palette = context.colors;
    final strings = context.strings;

    return Container(
      key: const Key('score-pro-locked-card'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline_rounded, size: 18, color: palette.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  strings.t('scoringProLockedTitle'),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: palette.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            strings.t('scoringProLockedBody'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: palette.muted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('score-unlock-pro-btn'),
            onPressed: () => unawaited(showProPaywallSheet(context)),
            icon: const Icon(Icons.auto_awesome_rounded, size: 18),
            label: Text(strings.t('scoringProUnlockBtn')),
          ),
        ],
      ),
    );
  }
}

class _MiniStatChip extends StatelessWidget {
  const _MiniStatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DimensionScoreCard extends StatelessWidget {
  const _DimensionScoreCard({
    required this.label,
    required this.score,
    required this.color,
    super.key,
  });

  final String label;
  final int score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: palette.surfaceHigh.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.outline),
      ),
      child: Column(
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: palette.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$score',
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (score / 100).clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: palette.outline.withValues(alpha: 0.35),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteReviewChip extends StatelessWidget {
  const _NoteReviewChip({
    required this.record,
    required this.playing,
    required this.onTap,
    super.key,
  });

  final NoteScoreRecord record;
  final bool playing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final strings = context.strings;

    final (Color color, String statusText) = switch (record.status) {
      NoteScoreStatus.accurate => (
        palette.success,
        strings.t('scoringStatusAccurate'),
      ),
      NoteScoreStatus.flat => (
        palette.warning,
        strings.t('scoringStatusFlat'),
      ),
      NoteScoreStatus.sharp => (
        palette.accent,
        strings.t('scoringStatusSharp'),
      ),
      NoteScoreStatus.missed => (
        palette.danger,
        strings.t('scoringStatusMissed'),
      ),
    };

    return Material(
      color: playing
          ? color.withValues(alpha: 0.22)
          : color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minWidth: 50, minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: playing ? color : color.withValues(alpha: 0.45),
              width: playing ? 1.8 : 1.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    record.note.tab,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: palette.text,
                    ),
                  ),
                  if (playing) ...[
                    const SizedBox(width: 2),
                    Icon(Icons.volume_up_rounded, size: 12, color: color),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
