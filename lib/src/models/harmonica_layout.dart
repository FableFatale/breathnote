import 'dart:math' as math;

import 'pitch_reading.dart';
import 'practice_note.dart';

class HarmonicaTabMatch {
  const HarmonicaTabMatch({required this.hole, required this.isBlow});

  final int hole;
  final bool isBlow;
}

const List<int> kHarmonicaBlowMidi = [60, 64, 67, 72, 76, 79, 84, 88, 91, 96];
const List<int> kHarmonicaDrawMidi = [62, 67, 71, 74, 77, 81, 83, 86, 89, 93];

HarmonicaTabMatch? tabForReading(PitchReading reading, String key) {
  if (!reading.detected) return null;
  final offset = harmonicaKeyOffset(key);

  for (var index = 0; index < kHarmonicaBlowMidi.length; index++) {
    if (kHarmonicaBlowMidi[index] + offset == reading.midi) {
      return HarmonicaTabMatch(hole: index + 1, isBlow: true);
    }
    if (kHarmonicaDrawMidi[index] + offset == reading.midi) {
      return HarmonicaTabMatch(hole: index + 1, isBlow: false);
    }
  }
  return null;
}

/// 零乐理新手友好的口琴孔位详解数据模型
class HarmonicaHoleInfo {
  const HarmonicaHoleInfo({
    required this.hole,
    required this.isBlow,
    required this.solfege,
    required this.jianpu,
    required this.baseMidi,
  });

  final int hole;
  final bool isBlow;

  /// 唱名，例如 "Do"、"Re"、"Mi"
  final String solfege;

  /// 简谱数字标记，例如 "1"、"2"、"1̣"
  final String jianpu;

  /// C 调口琴下的基础 MIDI 音高
  final int baseMidi;

  String get tab => '$hole${isBlow ? '↑' : '↓'}';

  /// 所属音区：low (1-3), middle (4-7), high (8-10)
  String get zone => hole <= 3
      ? 'low'
      : hole <= 7
      ? 'middle'
      : 'high';

  String noteLabelForKey(String key) {
    return noteLabelForMidi(baseMidi + harmonicaKeyOffset(key));
  }

  double frequencyForKey(String key) {
    final targetMidi = baseMidi + harmonicaKeyOffset(key);
    return (440 * math.pow(2, (targetMidi - 69) / 12)).toDouble();
  }

  String zoneLabel(String lang) {
    return switch ((zone, lang)) {
      ('low', 'en') => 'Holes 1–3 · Low Bass Zone',
      ('middle', 'en') => 'Holes 4–7 · Middle Melody Zone (Start Here)',
      ('high', 'en') => 'Holes 8–10 · High Bright Zone',
      ('low', 'ja') => '1–3番穴・低音エリア',
      ('middle', 'ja') => '4–7番穴・中音メロディエリア（初心者の起点）',
      ('high', 'ja') => '8–10番穴・高音エリア',
      ('low', _) => '1–3 孔 · 浑厚低音区',
      ('middle', _) => '4–7 孔 · 中音旋律区（新手起点）',
      _ => '8–10 孔 · 清脆高音区',
    };
  }

  String roleTitle(String lang) {
    final actionZh = isBlow ? '吹气 ↑' : '吸气 ↓';
    final actionEn = isBlow ? 'Blow ↑' : 'Draw ↓';
    final actionJa = isBlow ? '吹く ↑' : '吸う ↓';
    return switch (lang) {
      'en' => 'Hole $hole · $actionEn ($solfege / $jianpu)',
      'ja' => '$hole番穴・$actionJa（$solfege / $jianpu）',
      _ => '第 $hole 孔 · $actionZh（唱 $solfege · 简谱 $jianpu）',
    };
  }

  String beginnerMeaning(String lang) {
    if (lang == 'en') {
      return switch ((hole, isBlow)) {
        (1, true) =>
          'Lowest note on the harmonica (Low Do). The reed is long and deep—exhale slowly and gently without forcing air.',
        (1, false) =>
          'Low Re. Relax your jaw and inhale naturally as if breathing in fresh air.',
        (2, true) =>
          'Low Mi. A warm bass note often used in chords and gentle accompaniment.',
        (2, false) =>
          'Low Sol (same pitch as Hole 3 Blow). Keep your throat open so the long reed vibrates freely.',
        (3, true) =>
          'Low Sol. Bridges the bass zone and middle zone with a full, steady tone.',
        (3, false) =>
          'Low Si. A rich transition note right before the beginner-friendly middle zone.',
        (4, true) =>
          '★ Beginner Starting Point (Middle Do / 1). The easiest hole to sound! Most songs and Lesson 2 start right here.',
        (4, false) =>
          'Middle Re (2). Just inhale gently on Hole 4 without moving the harmonica!',
        (5, true) =>
          'Middle Mi (3). Very responsive reed—paired with Hole 4, you can already play simple melodies.',
        (5, false) =>
          'Middle Fa (4). Softly inhale on Hole 5; great for stepping up and down a scale.',
        (6, true) =>
          'Middle Sol (5). Used with Hole 4 Blow to play the opening of "Twinkle, Twinkle, Little Star" (4↑ 4↑ 6↑ 6↑)!',
        (6, false) =>
          'Middle La (6). The highest note in "Twinkle, Twinkle"—inhale lightly on Hole 6.',
        (7, true) =>
          'High Do (1̇). Completes the full Do-Re-Mi-Fa-Sol-La-Si-Do scale in the middle zone!',
        (7, false) =>
          'Middle Si (7). Note that on Hole 7, drawing is slightly lower than blowing so the 7-note scale fits in Holes 4–7.',
        (8, true) =>
          'High Mi (3̇). Enters the bright high zone; use a thin, gentle stream of air.',
        (8, false) =>
          'High Re (2̇). Like Hole 7, high holes draw the lower note and blow the higher note.',
        (9, true) =>
          'High Sol (5̇). Crisp and bright—never blow hard, a soft breath makes it ring.',
        (9, false) =>
          'High Fa (4̇). Gentle inhale in the upper register.',
        (10, true) =>
          'Top Do (1̈). The highest note on the right end with the tiniest reed.',
        _ =>
          'High La (6̇). Delivers a clear, bird-like high note when inhaled softly.',
      };
    }
    if (lang == 'ja') {
      return switch ((hole, isBlow)) {
        (4, true) =>
          '★ 初心者のスタート地点（中音のド / 1）。最も軽く息を入れるだけで鳴りやすい黄金の穴です。',
        (4, false) =>
          '中音のレ（2）。4番穴のまま自然に息を吸うだけで次の音になります。',
        (5, true) =>
          '中音のミ（3）。4番穴と組み合わせるだけで簡単なメロディが吹けます。',
        (5, false) =>
          '中音のファ（4）。やさしく息を吸って鳴らす中音エリアの音です。',
        (6, true) =>
          '中音のソ（5）。『きらきら星』の冒頭（4↑ 4↑ 6↑ 6↑）で活躍する大切な穴です。',
        (6, false) =>
          '中音のラ（6）。6番穴を軽く吸うと『きらきら星』の一番高い音が出ます。',
        (7, true) =>
          '高音のド（1̇）。4〜7番穴で「ドレミファソラシド」の1オクターブが完成します。',
        (7, false) =>
          '中音のシ（7）。7番穴からは吸う音が下で吹く音が上になります。',
        _ when hole <= 3 =>
          '低音エリア（1〜3番穴）。リードが長く低い音が出るため、最初は位置を知るだけでOKです。',
        _ =>
          '高音エリア（8〜10番穴）。リードが短く明るい音が出ます。強く吹かず細い息で鳴らします。',
      };
    }
    return switch ((hole, isBlow)) {
      (1, true) =>
        '整把口琴最低沉的音（低音 Do）。内部铜簧片最长，就像大提琴一样浑厚，新手只需认识位置，不必急着吹它。',
      (1, false) =>
        '低音 Re。对着第 1 孔自然往回吸气即可发声，下巴保持放松。',
      (2, true) =>
        '低音 Mi。声音温暖厚实，常用于低音伴奏或和弦铺底。',
      (2, false) =>
        '低音 Sol（和第 3 孔吹气是同一个音）。这是布鲁斯口琴的经典设计，方便低音和弦伴奏。',
      (3, true) =>
        '低音 Sol。连接低音区与中音区的桥梁，声音饱满稳定。',
      (3, false) =>
        '低音 Si。需要放松口腔自然吸气，再往右一格就是最适合新手的第 4 孔了！',
      (4, true) =>
        '★ 新手黄金起点（中音 Do）！不需要懂五线谱，第 4 孔吹气就是大家最熟悉的「1 (Do)」，最省力、最容易吹响，所有入门第一课都从这里开始。',
      (4, false) =>
        '中音 Re（简谱 2）。嘴唇不用挪动位置，直接在第 4 孔轻轻往回吸气，就从 Do 变成了 Re！',
      (5, true) =>
        '中音 Mi（简谱 3）。从第 4 孔往右挪一格吹气就是 Mi，配合第 4 孔就能吹出《两只老虎》的开头（4↑ 4↓ 5↑ 4↑）。',
      (5, false) =>
        '中音 Fa（简谱 4）。在第 5 孔轻轻吸气就是 Fa，簧片反应灵敏，轻轻呼吸即可共鸣。',
      (6, true) =>
        '中音 Sol（简谱 5）。最常用的旋律孔之一！《小星星》第一句「一闪一闪亮晶晶」（4↑ 4↑ 6↑ 6↑ 6↓ 6↓ 6↑）就靠 4 孔和 6 孔完成。',
      (6, false) =>
        '中音 La（简谱 6）。在第 6 孔自然吸气就是 La，也是《小星星》里的最高音位置。',
      (7, true) =>
        '高八度 Do（简谱 1̇）。在 4–7 这四个孔里，正好凑齐完整的「Do Re Mi Fa Sol La Si Do」，学会这 4 个孔就能吹奏大多数入门歌曲！',
      (7, false) =>
        '中音 Si（简谱 7）。注意一个小秘密：唯独从第 7 孔开始，吸气（Si）比吹气（Do）低半音，这是为了让 4–7 孔刚好装下完整音阶。',
      (8, true) =>
        '高音 Mi（简谱 3̇）。从第 8 孔进入右侧高音区，簧片变短，声音清脆明亮，吹气时像吹蒲公英一样轻柔即可。',
      (8, false) =>
        '高音 Re（简谱 2̇）。高音区吸气音，保持细而稳的气流，切忌猛吸。',
      (9, true) =>
        '高音 Sol（简谱 5̇）。清亮的高音孔位，常用于乐曲高潮华彩段，新手前期只需了解位置。',
      (9, false) =>
        '高音 Fa（简谱 4̇）。第 9 孔轻柔吸气，声音穿透力强。',
      (10, true) =>
        '最高音 Do（简谱 1̈）。口琴最右端的第 10 孔，内部簧片最短小，声音像鸟鸣般清脆。',
      _ =>
        '高音 La（简谱 6̇）。第 10 孔吸气音，入门阶段先认识它的位置，熟练中音区后再来挑战。',
    };
  }
}

const List<HarmonicaHoleInfo> _blowHoleInfos = [
  HarmonicaHoleInfo(hole: 1, isBlow: true, solfege: 'Do', jianpu: '1̣', baseMidi: 60),
  HarmonicaHoleInfo(hole: 2, isBlow: true, solfege: 'Mi', jianpu: '3̣', baseMidi: 64),
  HarmonicaHoleInfo(hole: 3, isBlow: true, solfege: 'Sol', jianpu: '5̣', baseMidi: 67),
  HarmonicaHoleInfo(hole: 4, isBlow: true, solfege: 'Do', jianpu: '1', baseMidi: 72),
  HarmonicaHoleInfo(hole: 5, isBlow: true, solfege: 'Mi', jianpu: '3', baseMidi: 76),
  HarmonicaHoleInfo(hole: 6, isBlow: true, solfege: 'Sol', jianpu: '5', baseMidi: 79),
  HarmonicaHoleInfo(hole: 7, isBlow: true, solfege: 'Do', jianpu: '1̇', baseMidi: 84),
  HarmonicaHoleInfo(hole: 8, isBlow: true, solfege: 'Mi', jianpu: '3̇', baseMidi: 88),
  HarmonicaHoleInfo(hole: 9, isBlow: true, solfege: 'Sol', jianpu: '5̇', baseMidi: 91),
  HarmonicaHoleInfo(hole: 10, isBlow: true, solfege: 'Do', jianpu: '1̈', baseMidi: 96),
];

const List<HarmonicaHoleInfo> _drawHoleInfos = [
  HarmonicaHoleInfo(hole: 1, isBlow: false, solfege: 'Re', jianpu: '2̣', baseMidi: 62),
  HarmonicaHoleInfo(hole: 2, isBlow: false, solfege: 'Sol', jianpu: '5̣', baseMidi: 67),
  HarmonicaHoleInfo(hole: 3, isBlow: false, solfege: 'Si', jianpu: '7̣', baseMidi: 71),
  HarmonicaHoleInfo(hole: 4, isBlow: false, solfege: 'Re', jianpu: '2', baseMidi: 74),
  HarmonicaHoleInfo(hole: 5, isBlow: false, solfege: 'Fa', jianpu: '4', baseMidi: 77),
  HarmonicaHoleInfo(hole: 6, isBlow: false, solfege: 'La', jianpu: '6', baseMidi: 81),
  HarmonicaHoleInfo(hole: 7, isBlow: false, solfege: 'Si', jianpu: '7', baseMidi: 83),
  HarmonicaHoleInfo(hole: 8, isBlow: false, solfege: 'Re', jianpu: '2̇', baseMidi: 86),
  HarmonicaHoleInfo(hole: 9, isBlow: false, solfege: 'Fa', jianpu: '4̇', baseMidi: 89),
  HarmonicaHoleInfo(hole: 10, isBlow: false, solfege: 'La', jianpu: '6̇', baseMidi: 93),
];

HarmonicaHoleInfo harmonicaHoleInfo(int hole, {required bool isBlow}) {
  final safeIndex = (hole - 1).clamp(0, 9);
  return isBlow ? _blowHoleInfos[safeIndex] : _drawHoleInfos[safeIndex];
}
