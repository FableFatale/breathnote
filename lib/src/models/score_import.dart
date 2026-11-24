import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'harmonica_layout.dart';
import 'practice_note.dart';
import 'song.dart';

/// 从 MIDI / MusicXML / 文字谱提取出的原始旋律数据。
@immutable
class ParsedScoreSource {
  const ParsedScoreSource({
    required this.midis,
    this.title,
    this.sourceFormat = 'text',
  });

  final List<int> midis;
  final String? title;
  final String sourceFormat;
}

/// 单个音符在自动移调与同音异孔校对中的状态。
@immutable
class ImportedNoteChoice {
  const ImportedNoteChoice({
    required this.index,
    required this.sourceMidi,
    required this.transposedMidi,
    required this.relativeMidi,
    required this.selectedTab,
    required this.alternatives,
    required this.requiresBend,
  });

  final int index;
  final int sourceMidi;
  final int transposedMidi;

  /// 相对当前口琴调号换算回 C 调基准的 MIDI（用于构造 PracticeNote）。
  final int relativeMidi;
  final String selectedTab;

  /// 所有同音可选孔位（例如 `2↓` 与 `3↑`）。
  final List<String> alternatives;
  final bool requiresBend;

  bool get hasEnharmonicChoice => alternatives.length > 1;

  String get noteLabel => noteLabelForMidi(transposedMidi);

  int get holeNumber =>
      int.tryParse(selectedTab.replaceAll(RegExp(r'[^0-9]'), '')) ?? 4;

  ImportedNoteChoice copyWith({String? selectedTab}) {
    return ImportedNoteChoice(
      index: index,
      sourceMidi: sourceMidi,
      transposedMidi: transposedMidi,
      relativeMidi: relativeMidi,
      selectedTab: selectedTab ?? this.selectedTab,
      alternatives: alternatives,
      requiresBend: requiresBend,
    );
  }
}

/// 3 步式导谱引擎输出的移调、压音统计与同音异孔方案。
@immutable
class ScoreImportPlan {
  const ScoreImportPlan({
    required this.harmonicaKey,
    required this.sourceMidis,
    required this.recommendedTranspose,
    required this.appliedTranspose,
    required this.items,
    this.suggestedTitle,
  });

  final String harmonicaKey;
  final List<int> sourceMidis;
  final int recommendedTranspose;
  final int appliedTranspose;
  final List<ImportedNoteChoice> items;
  final String? suggestedTitle;

  int get directCount => items.where((item) => !item.requiresBend).length;
  int get bendCount => items.where((item) => item.requiresBend).length;
  int get enharmonicCount =>
      items.where((item) => item.hasEnharmonicChoice).length;

  /// 切换某个同音异孔音符（如 `2↓` ↔ `3↑`）。
  ScoreImportPlan withSelectedTab(int index, String tab) {
    final updated = List<ImportedNoteChoice>.of(items);
    if (index >= 0 && index < updated.length) {
      updated[index] = updated[index].copyWith(selectedTab: tab);
    }
    return ScoreImportPlan(
      harmonicaKey: harmonicaKey,
      sourceMidis: sourceMidis,
      recommendedTranspose: recommendedTranspose,
      appliedTranspose: appliedTranspose,
      items: List.unmodifiable(updated),
      suggestedTitle: suggestedTitle,
    );
  }

  /// 转为可持久化的 `PracticeNote` 列表（基准按 C 调存储，由 `harmonicaKey` 统一转调）。
  List<PracticeNote> toPracticeNotes() {
    const names = [
      'C',
      'C#',
      'D',
      'D#',
      'E',
      'F',
      'F#',
      'G',
      'G#',
      'A',
      'A#',
      'B',
    ];
    return items.map((item) {
      final midi = item.relativeMidi.clamp(36, 108);
      final name = names[((midi % 12) + 12) % 12];
      final octave = midi ~/ 12 - 1;
      return PracticeNote(
        note: name,
        octave: octave,
        tab: item.selectedTab,
        requiresBend: item.requiresBend,
      );
    }).toList();
  }
}

/// 常见十孔口琴相对 MIDI 到压音参考记号映射（C 调基准）。
const Map<int, String> _kBendTabMap = {
  61: "1↓'",
  63: "1↑'",
  65: "2↓''",
  66: "2↓'",
  68: "3↓'''",
  69: "3↓''",
  70: "3↓'",
  73: "4↓'",
  75: "4↑'",
  78: "6↓'",
  80: "6↑'",
  82: "7↑'",
  85: "8↑'",
  87: "9↑'",
  90: "9↑'",
  92: "10↑'",
  94: "10↑''",
  95: "10↑'",
};

List<String> _directTabsForRelativeMidi(int relativeMidi) {
  final result = <String>[];
  for (var i = 0; i < kHarmonicaBlowMidi.length; i++) {
    if (kHarmonicaBlowMidi[i] == relativeMidi) {
      result.add('${i + 1}↑');
    }
    if (kHarmonicaDrawMidi[i] == relativeMidi) {
      result.add('${i + 1}↓');
    }
  }
  return result;
}

String _fallbackBendTab(int relativeMidi) {
  final exact = _kBendTabMap[relativeMidi];
  if (exact != null) return exact;
  if (relativeMidi < 60) return "1↑'";
  if (relativeMidi > 96) return "10↑'";
  // 找到最近的孔位作为提示
  var bestHole = 4;
  var bestBlow = true;
  var bestDist = 999;
  for (var i = 0; i < 10; i++) {
    final blowDist = (kHarmonicaBlowMidi[i] - relativeMidi).abs();
    if (blowDist < bestDist) {
      bestDist = blowDist;
      bestHole = i + 1;
      bestBlow = true;
    }
    final drawDist = (kHarmonicaDrawMidi[i] - relativeMidi).abs();
    if (drawDist < bestDist) {
      bestDist = drawDist;
      bestHole = i + 1;
      bestBlow = false;
    }
  }
  return "$bestHole${bestBlow ? '↑' : '↓'}'";
}

int _holeFromTab(String tab) {
  return int.tryParse(tab.replaceAll(RegExp(r'[^0-9]'), '')) ?? 4;
}

/// 根据原始 MIDI 序列与目标口琴调号，自动寻找压音最少的最佳移调并生成同音异孔最小移动推荐。
ScoreImportPlan buildScoreImportPlan({
  required List<int> sourceMidis,
  required String harmonicaKey,
  int? transposeOverride,
  String? suggestedTitle,
}) {
  if (sourceMidis.isEmpty) {
    throw const HarmonicaTabFormatException('emptyNotation');
  }

  final keyOffset = harmonicaKeyOffset(harmonicaKey);
  final sorted = [...sourceMidis]..sort();
  final medianMidi = sorted[sorted.length ~/ 2];
  // 先对齐到当前口琴中音区中心（相对 MIDI ~76）的八度范围
  final targetCenter = 76 + keyOffset;
  final baseOctaveShift = ((targetCenter - medianMidi) / 12).round() * 12;

  var bestShift = baseOctaveShift;
  var bestPenalty = 1 << 30;

  for (var delta = -12; delta <= 12; delta++) {
    final candidateShift = baseOctaveShift + delta;
    var bends = 0;
    var outOfRange = 0;
    var comfortPenalty = 0;
    for (final raw in sourceMidis) {
      final rel = raw + candidateShift - keyOffset;
      final direct = _directTabsForRelativeMidi(rel);
      if (direct.isEmpty) {
        bends++;
      }
      if (rel < 60 || rel > 96) {
        outOfRange++;
      }
      if (rel < 67 || rel > 84) {
        comfortPenalty++;
      }
    }
    // 权重优先级：压音最少 > 不超十孔音域 > 靠近中音区 > 移调幅度小
    final penalty =
        bends * 10000 +
        outOfRange * 2000 +
        comfortPenalty * 20 +
        delta.abs();
    if (penalty < bestPenalty) {
      bestPenalty = penalty;
      bestShift = candidateShift;
    }
  }

  final appliedShift = transposeOverride ?? bestShift;
  final items = <ImportedNoteChoice>[];
  var previousHole = 4;

  for (var i = 0; i < sourceMidis.length; i++) {
    final sourceMidi = sourceMidis[i];
    final transposedMidi = sourceMidi + appliedShift;
    final relativeMidi = transposedMidi - keyOffset;
    final directTabs = _directTabsForRelativeMidi(relativeMidi);
    final requiresBend = directTabs.isEmpty;
    final alternatives = requiresBend
        ? [_fallbackBendTab(relativeMidi)]
        : directTabs;

    // 同音异孔时，默认推荐距前一个音手部移动最少的孔位
    var selected = alternatives.first;
    if (alternatives.length > 1) {
      var minMove = 999;
      for (final candidate in alternatives) {
        final dist = (_holeFromTab(candidate) - previousHole).abs();
        if (dist < minMove) {
          minMove = dist;
          selected = candidate;
        }
      }
    }
    previousHole = _holeFromTab(selected);

    items.add(
      ImportedNoteChoice(
        index: i,
        sourceMidi: sourceMidi,
        transposedMidi: transposedMidi,
        relativeMidi: relativeMidi,
        selectedTab: selected,
        alternatives: List.unmodifiable(alternatives),
        requiresBend: requiresBend,
      ),
    );
  }

  return ScoreImportPlan(
    harmonicaKey: harmonicaKey,
    sourceMidis: List.unmodifiable(sourceMidis),
    recommendedTranspose: bestShift,
    appliedTranspose: appliedShift,
    items: List.unmodifiable(items),
    suggestedTitle: suggestedTitle,
  );
}

/// 零外部依赖的标准 MIDI（SMF Format 0 / 1）主旋律提取器。
/// 自动跳过打击乐通道（Channel 10 / index 9），同一拍多音时提取最高旋律音。
ParsedScoreSource parseMidiBytes(Uint8List bytes, {String? fallbackTitle}) {
  if (bytes.length < 14 ||
      bytes[0] != 0x4D ||
      bytes[1] != 0x54 ||
      bytes[2] != 0x68 ||
      bytes[3] != 0x64) {
    throw const HarmonicaTabFormatException('invalidMidiFile');
  }

  final data = ByteData.sublistView(bytes);
  final headerLength = data.getUint32(4);
  final trackCount = data.getUint16(10);
  var offset = 8 + headerLength;

  String? trackTitle;
  final noteByTick = <int, int>{};

  for (var t = 0; t < trackCount && offset + 8 <= bytes.length; t++) {
    if (bytes[offset] != 0x4D ||
        bytes[offset + 1] != 0x54 ||
        bytes[offset + 2] != 0x72 ||
        bytes[offset + 3] != 0x6B) {
      break;
    }
    final trackLen = data.getUint32(offset + 4);
    offset += 8;
    final trackEnd = (offset + trackLen).clamp(0, bytes.length);

    var tick = 0;
    var runningStatus = 0;

    while (offset < trackEnd) {
      // Read VLQ delta-time
      var delta = 0;
      while (offset < trackEnd) {
        final b = bytes[offset++];
        delta = (delta << 7) | (b & 0x7F);
        if ((b & 0x80) == 0) break;
      }
      tick += delta;
      if (offset >= trackEnd) break;

      var status = bytes[offset];
      if (status < 0x80) {
        status = runningStatus;
      } else {
        offset++;
        if (status < 0xF0) {
          runningStatus = status;
        }
      }

      if (status == 0xFF) {
        if (offset >= trackEnd) break;
        final metaType = bytes[offset++];
        var metaLen = 0;
        while (offset < trackEnd) {
          final b = bytes[offset++];
          metaLen = (metaLen << 7) | (b & 0x7F);
          if ((b & 0x80) == 0) break;
        }
        if (metaType == 0x03 &&
            trackTitle == null &&
            offset + metaLen <= trackEnd &&
            metaLen > 0) {
          final decoded = utf8
              .decode(
                bytes.sublist(offset, offset + metaLen),
                allowMalformed: true,
              )
              .trim();
          if (decoded.isNotEmpty) trackTitle = decoded;
        }
        offset = (offset + metaLen).clamp(0, trackEnd);
      } else if (status == 0xF0 || status == 0xF7) {
        var sysexLen = 0;
        while (offset < trackEnd) {
          final b = bytes[offset++];
          sysexLen = (sysexLen << 7) | (b & 0x7F);
          if ((b & 0x80) == 0) break;
        }
        offset = (offset + sysexLen).clamp(0, trackEnd);
      } else {
        final eventType = status & 0xF0;
        final channel = status & 0x0F;
        if (eventType == 0xC0 || eventType == 0xD0) {
          offset = (offset + 1).clamp(0, trackEnd);
        } else if (offset + 2 <= trackEnd) {
          final data1 = bytes[offset++];
          final data2 = bytes[offset++];
          // Note On with velocity > 0 on non-percussion channel
          if (eventType == 0x90 && data2 > 0 && channel != 9) {
            final existing = noteByTick[tick];
            if (existing == null || data1 > existing) {
              noteByTick[tick] = data1;
            }
          }
        } else {
          offset = trackEnd;
        }
      }
    }
    offset = trackEnd;
  }

  if (noteByTick.isEmpty) {
    throw const HarmonicaTabFormatException('emptyNotation');
  }

  final sortedTicks = noteByTick.keys.toList()..sort();
  final midis = sortedTicks
      .take(128)
      .map((tick) => noteByTick[tick]!)
      .toList();

  return ParsedScoreSource(
    midis: midis,
    title: trackTitle ?? fallbackTitle,
    sourceFormat: 'midi',
  );
}

/// 零外部依赖的 MusicXML（`.xml` / `.musicxml`）主旋律提取器。
/// 自动跳过休止符与和弦伴音，提取 `<pitch><step><alter><octave>` 音高序列。
ParsedScoreSource parseMusicXml(String xmlText, {String? fallbackTitle}) {
  if (!xmlText.contains('<note') && !xmlText.contains('<pitch')) {
    throw const HarmonicaTabFormatException('invalidMusicXmlFile');
  }

  String? extractTag(String input, String tag) {
    final match = RegExp(
      '<$tag[^>]*>([^<]+)</$tag>',
      caseSensitive: false,
    ).firstMatch(input);
    return match?.group(1)?.trim();
  }

  final title =
      extractTag(xmlText, 'work-title') ??
      extractTag(xmlText, 'movement-title') ??
      fallbackTitle;

  const stepOffsets = <String, int>{
    'C': 0,
    'D': 2,
    'E': 4,
    'F': 5,
    'G': 7,
    'A': 9,
    'B': 11,
  };

  final noteMatches = RegExp(
    r'<note\b[^>]*>([\s\S]*?)</note>',
    caseSensitive: false,
  ).allMatches(xmlText);

  final midis = <int>[];
  for (final match in noteMatches) {
    if (midis.length >= 128) break;
    final body = match.group(1) ?? '';
    if (RegExp(r'<rest\b', caseSensitive: false).hasMatch(body)) continue;
    if (RegExp(r'<chord\b', caseSensitive: false).hasMatch(body)) continue;

    final step = extractTag(body, 'step')?.toUpperCase();
    final octaveStr = extractTag(body, 'octave');
    if (step == null || octaveStr == null) continue;
    final stepOffset = stepOffsets[step];
    final octave = int.tryParse(octaveStr);
    if (stepOffset == null || octave == null) continue;

    final alter = double.tryParse(extractTag(body, 'alter') ?? '0')?.round() ?? 0;
    final midi = (octave + 1) * 12 + stepOffset + alter;
    if (midi >= 24 && midi <= 108) {
      midis.add(midi);
    }
  }

  if (midis.isEmpty) {
    throw const HarmonicaTabFormatException('emptyNotation');
  }

  return ParsedScoreSource(
    midis: midis,
    title: title,
    sourceFormat: 'musicxml',
  );
}

/// 将用户输入的口琴文字谱 / 简谱 / 分享码解析为统一 `ParsedScoreSource`（用于 3 步导谱流）。
ParsedScoreSource parseTextOrJianpuSource(
  String rawInput, {
  required String harmonicaKey,
}) {
  final parsed = parseSongShareOrJianpu(rawInput);
  final notes = parseHarmonicaTabs(parsed.tabs);
  final offset = harmonicaKeyOffset(harmonicaKey);
  final midis = notes.map((note) => note.midi + offset).toList();
  return ParsedScoreSource(
    midis: midis,
    title: parsed.title,
    sourceFormat: 'text',
  );
}
