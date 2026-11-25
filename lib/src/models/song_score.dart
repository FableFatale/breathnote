import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'practice_note.dart';

/// 评分模式下单个音符的判定状态。
enum NoteScoreStatus {
  /// 准音（绝对音分偏差 <= 25¢）
  accurate,

  /// 偏低（音分 < -25¢）
  flat,

  /// 偏高（音分 > +25¢）
  sharp,

  /// 漏吹（该拍窗口内未检测到有效发声）
  missed,
}

/// 根据总分计算 1–3 星级（用于评分模式与跟练模式统一展示）。
int starsForSongScore(int score) {
  if (score >= 85) return 3;
  if (score >= 65) return 2;
  if (score > 0) return 1;
  return 0;
}

/// 曲目综合评级（S / A / B / C）。
enum SongScoreGrade { s, a, b, c }

SongScoreGrade gradeForSongScore(int score) {
  if (score >= 92) return SongScoreGrade.s;
  if (score >= 80) return SongScoreGrade.a;
  if (score >= 65) return SongScoreGrade.b;
  return SongScoreGrade.c;
}

extension SongScoreGradeLabel on SongScoreGrade {
  String get label => switch (this) {
    SongScoreGrade.s => 'S',
    SongScoreGrade.a => 'A',
    SongScoreGrade.b => 'B',
    SongScoreGrade.c => 'C',
  };
}

/// 单个音符在评分时间线上的采样与判定结果。
@immutable
class NoteScoreRecord {
  const NoteScoreRecord({
    required this.index,
    required this.note,
    required this.status,
    this.medianCents,
    this.timingOffsetMs,
    this.stabilityStdDevCents,
    this.sampleCount = 0,
  });

  final int index;
  final PracticeNote note;
  final NoteScoreStatus status;

  /// 中位音分偏差（负数为偏低，正数为偏高）；漏吹时为 null。
  final double? medianCents;

  /// 首次起音相对理想拍点的偏移毫秒数（越小越准）；漏吹时为 null。
  final double? timingOffsetMs;

  /// 窗口内音分波动标准差（越小越稳）；漏吹时为 null。
  final double? stabilityStdDevCents;

  /// 窗口内采集的有效音高帧数（0 表示旧构造/单测未传入）。
  final int sampleCount;

  bool get isHit => status != NoteScoreStatus.missed;
  bool get isAccurate => status == NoteScoreStatus.accurate;

  /// 由窗口内采样点构建单音结果（准音阈值 ±25¢）。
  factory NoteScoreRecord.fromSamples({
    required int index,
    required PracticeNote note,
    required List<double> centsSamples,
    required double? firstOnsetOffsetMs,
  }) {
    if (centsSamples.isEmpty) {
      return NoteScoreRecord(
        index: index,
        note: note,
        status: NoteScoreStatus.missed,
      );
    }
    final sorted = [...centsSamples]..sort();
    final mid = sorted.length ~/ 2;
    final median = sorted.length.isOdd
        ? sorted[mid]
        : (sorted[mid - 1] + sorted[mid]) / 2.0;

    // 真实口琴簧片起音瞬间（首帧 ~23–46 ms）常有气压爬升瞬态，样本足够时剔除偏离中位数 >25¢ 的起音瞬态，
    // 让稳定度评分专注衡量稳态气息波动，而非误伤正常起音。
    final steadySamples = centsSamples.length >= 4 &&
            (centsSamples.first - median).abs() > 25.0
        ? centsSamples.sublist(1)
        : centsSamples;

    final mean =
        steadySamples.reduce((a, b) => a + b) / steadySamples.length;
    var varianceSum = 0.0;
    for (final sample in steadySamples) {
      final delta = sample - mean;
      varianceSum += delta * delta;
    }
    final stdDev = math.sqrt(varianceSum / steadySamples.length);

    final NoteScoreStatus status;
    if (median.abs() <= 25.0) {
      status = NoteScoreStatus.accurate;
    } else if (median < 0) {
      status = NoteScoreStatus.flat;
    } else {
      status = NoteScoreStatus.sharp;
    }

    return NoteScoreRecord(
      index: index,
      note: note,
      status: status,
      medianCents: median,
      timingOffsetMs: firstOnsetOffsetMs ?? 0.0,
      stabilityStdDevCents: stdDev,
      sampleCount: centsSamples.length,
    );
  }
}

/// 整首曲目的评分汇总：总分、星级、三维分（音准/节奏/稳定）、逐音回顾与薄弱孔位诊断。
@immutable
class SongScoreSummary {
  const SongScoreSummary({
    required this.totalScore,
    required this.stars,
    required this.pitchScore,
    required this.timingScore,
    required this.stabilityScore,
    required this.maxCombo,
    required this.hitCount,
    required this.notes,
    this.weakestTab,
    this.weakestStatus,
  });

  final int totalScore;
  final int stars;
  final int pitchScore;
  final int timingScore;
  final int stabilityScore;
  final int maxCombo;
  final int hitCount;
  final List<NoteScoreRecord> notes;

  /// 本次失误最多的孔位（如 `6↓`），全部精准时为 null。
  final String? weakestTab;

  /// 薄弱孔位的主要问题类型（`missed` / `flat` / `sharp`）。
  final NoteScoreStatus? weakestStatus;

  int get totalNotes => notes.length;

  SongScoreGrade get grade => gradeForSongScore(totalScore);

  /// 汇总逐音采样结果，输出三维细分评分与诊断要点。
  /// 权重：音准 50% · 节奏 25% · 稳定度 25%（±25¢ 为准音阈值）。
  factory SongScoreSummary.evaluate(
    List<NoteScoreRecord> notes, {
    int? maxCombo,
  }) {
    if (notes.isEmpty) {
      return const SongScoreSummary(
        totalScore: 0,
        stars: 0,
        pitchScore: 0,
        timingScore: 0,
        stabilityScore: 0,
        maxCombo: 0,
        hitCount: 0,
        notes: [],
      );
    }

    var pitchSum = 0.0;
    var timingSum = 0.0;
    var stabilitySum = 0.0;
    var hitCount = 0;
    var currentCombo = 0;
    var computedMaxCombo = 0;

    final tabIssues = <String, List<NoteScoreRecord>>{};

    for (final record in notes) {
      if (record.isAccurate) {
        currentCombo++;
        if (currentCombo > computedMaxCombo) {
          computedMaxCombo = currentCombo;
        }
      } else {
        currentCombo = 0;
        tabIssues.putIfAbsent(record.note.tab, () => []).add(record);
      }

      if (!record.isHit) {
        continue;
      }
      hitCount++;

      // 1. 音准单音分
      final absCents = (record.medianCents ?? 0).abs();
      final double notePitch;
      if (absCents <= 10) {
        notePitch = 100.0;
      } else if (absCents <= 25) {
        notePitch = 100.0 - ((absCents - 10) / 15.0) * 12.0;
      } else if (absCents <= 45) {
        notePitch = 88.0 - ((absCents - 25) / 20.0) * 43.0;
      } else {
        notePitch = math.max(15.0, 45.0 - (absCents - 45) * 0.6);
      }
      pitchSum += notePitch;

      // 2. 节奏起音分
      final absTiming = (record.timingOffsetMs ?? 0).abs();
      final double noteTiming;
      if (absTiming <= 140) {
        noteTiming = 100.0;
      } else if (absTiming <= 340) {
        noteTiming = 100.0 - ((absTiming - 140) / 200.0) * 25.0;
      } else if (absTiming <= 650) {
        noteTiming = 75.0 - ((absTiming - 340) / 310.0) * 35.0;
      } else {
        noteTiming = 30.0;
      }
      timingSum += noteTiming;

      // 3. 气息稳定分（单/双帧样本封顶，避免极短起音虚高）
      final stdDev = (record.stabilityStdDevCents ?? 0).abs();
      final double rawStability;
      if (stdDev <= 6) {
        rawStability = 100.0;
      } else if (stdDev <= 15) {
        rawStability = 100.0 - ((stdDev - 6) / 9.0) * 25.0;
      } else if (stdDev <= 30) {
        rawStability = 75.0 - ((stdDev - 15) / 15.0) * 30.0;
      } else {
        rawStability = 35.0;
      }
      final double noteStability;
      if (record.sampleCount == 1) {
        noteStability = math.min(60.0, rawStability);
      } else if (record.sampleCount == 2) {
        noteStability = math.min(80.0, rawStability);
      } else {
        noteStability = rawStability;
      }
      stabilitySum += noteStability;
    }

    final n = notes.length;
    final pitchScore = (pitchSum / n).round().clamp(0, 100);
    final timingScore = (timingSum / n).round().clamp(0, 100);
    final stabilityScore = (stabilitySum / n).round().clamp(0, 100);
    final totalScore =
        (pitchScore * 0.50 + timingScore * 0.25 + stabilityScore * 0.25)
            .round()
            .clamp(0, 100);

    String? weakestTab;
    NoteScoreStatus? weakestStatus;
    var worstCount = 0;
    var worstSeverity = -1.0;

    for (final entry in tabIssues.entries) {
      final list = entry.value;
      var severity = 0.0;
      var missed = 0;
      var flat = 0;
      var sharp = 0;
      for (final rec in list) {
        switch (rec.status) {
          case NoteScoreStatus.missed:
            missed++;
            severity += 60;
          case NoteScoreStatus.flat:
            flat++;
            severity += (rec.medianCents ?? -30).abs();
          case NoteScoreStatus.sharp:
            sharp++;
            severity += (rec.medianCents ?? 30).abs();
          case NoteScoreStatus.accurate:
            break;
        }
      }
      if (list.length > worstCount ||
          (list.length == worstCount && severity > worstSeverity)) {
        worstCount = list.length;
        worstSeverity = severity;
        weakestTab = entry.key;
        if (missed >= flat && missed >= sharp) {
          weakestStatus = NoteScoreStatus.missed;
        } else if (flat >= sharp) {
          weakestStatus = NoteScoreStatus.flat;
        } else {
          weakestStatus = NoteScoreStatus.sharp;
        }
      }
    }

    return SongScoreSummary(
      totalScore: totalScore,
      stars: starsForSongScore(totalScore),
      pitchScore: pitchScore,
      timingScore: timingScore,
      stabilityScore: stabilityScore,
      maxCombo: maxCombo ?? computedMaxCombo,
      hitCount: hitCount,
      notes: List.unmodifiable(notes),
      weakestTab: weakestTab,
      weakestStatus: weakestStatus,
    );
  }
}

/// 单次曲谱练习/评分的历史记录条目。
@immutable
class SongScoreAttempt {
  const SongScoreAttempt({
    required this.songId,
    required this.timestampMs,
    required this.totalScore,
    required this.pitchScore,
    required this.timingScore,
    required this.stabilityScore,
    required this.stars,
    required this.maxCombo,
    required this.hitCount,
    required this.totalNotes,
    required this.speed,
    required this.mode,
    this.weakestTab,
  });

  final String songId;
  final int timestampMs;
  final int totalScore;
  final int pitchScore;
  final int timingScore;
  final int stabilityScore;
  final int stars;
  final int maxCombo;
  final int hitCount;
  final int totalNotes;
  final double speed;
  final String mode;
  final String? weakestTab;

  SongScoreGrade get grade => gradeForSongScore(totalScore);

  Map<String, Object?> toJson() => {
    'songId': songId,
    'timestampMs': timestampMs,
    'totalScore': totalScore,
    'pitchScore': pitchScore,
    'timingScore': timingScore,
    'stabilityScore': stabilityScore,
    'stars': stars,
    'maxCombo': maxCombo,
    'hitCount': hitCount,
    'totalNotes': totalNotes,
    'speed': speed,
    'mode': mode,
    if (weakestTab != null) 'weakestTab': weakestTab,
  };

  static SongScoreAttempt? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, Object?>.from(raw);
    final songId = map['songId'];
    final timestampMs = map['timestampMs'];
    final totalScore = map['totalScore'];
    if (songId is! String ||
        songId.isEmpty ||
        timestampMs is! num ||
        totalScore is! num) {
      return null;
    }
    return SongScoreAttempt(
      songId: songId,
      timestampMs: timestampMs.toInt(),
      totalScore: totalScore.toInt().clamp(0, 100),
      pitchScore: (map['pitchScore'] as num?)?.toInt().clamp(0, 100) ?? 0,
      timingScore: (map['timingScore'] as num?)?.toInt().clamp(0, 100) ?? 0,
      stabilityScore:
          (map['stabilityScore'] as num?)?.toInt().clamp(0, 100) ?? 0,
      stars: (map['stars'] as num?)?.toInt().clamp(0, 3) ?? 0,
      maxCombo: (map['maxCombo'] as num?)?.toInt() ?? 0,
      hitCount: (map['hitCount'] as num?)?.toInt() ?? 0,
      totalNotes: (map['totalNotes'] as num?)?.toInt() ?? 0,
      speed: (map['speed'] as num?)?.toDouble() ?? 1.0,
      mode: map['mode'] as String? ?? 'score',
      weakestTab: map['weakestTab'] as String?,
    );
  }
}
