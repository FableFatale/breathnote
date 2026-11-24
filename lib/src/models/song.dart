import 'package:flutter/material.dart';

import 'practice_note.dart';

class HarmonicaTabFormatException extends FormatException {
  const HarmonicaTabFormatException(this.code, {this.token})
    : super(code, token);

  final String code;
  final String? token;
}

class SongIconPreset {
  const SongIconPreset({
    required this.id,
    required this.labelKey,
    required this.primaryColor,
    required this.secondaryColor,
  });

  final String id;
  final String labelKey;
  final Color primaryColor;
  final Color secondaryColor;
}

const songIconPresets = <SongIconPreset>[
  SongIconPreset(
    id: 'star',
    labelKey: 'songIconStar',
    primaryColor: Color(0xFF2554EB),
    secondaryColor: Color(0xFF4778FF),
  ),
  SongIconPreset(
    id: 'sunburst',
    labelKey: 'songIconSunburst',
    primaryColor: Color(0xFFE8590C),
    secondaryColor: Color(0xFFFF8B1A),
  ),
  SongIconPreset(
    id: 'tiger',
    labelKey: 'songIconTiger',
    primaryColor: Color(0xFF129A52),
    secondaryColor: Color(0xFF19C66B),
  ),
  SongIconPreset(
    id: 'flower',
    labelKey: 'songIconFlower',
    primaryColor: Color(0xFF6741D9),
    secondaryColor: Color(0xFF8A5CF6),
  ),
  SongIconPreset(
    id: 'moon',
    labelKey: 'songIconMoon',
    primaryColor: Color(0xFF0B7285),
    secondaryColor: Color(0xFF1098AD),
  ),
  SongIconPreset(
    id: 'campfire',
    labelKey: 'songIconCampfire',
    primaryColor: Color(0xFFC92A2A),
    secondaryColor: Color(0xFFF03E3E),
  ),
  SongIconPreset(
    id: 'wave',
    labelKey: 'songIconWave',
    primaryColor: Color(0xFF0077B6),
    secondaryColor: Color(0xFF00B4D8),
  ),
  SongIconPreset(
    id: 'vinyl',
    labelKey: 'songIconVinyl',
    primaryColor: Color(0xFF1E293B),
    secondaryColor: Color(0xFF334155),
  ),
];

String defaultIconIdForSong(String songId, {bool isCustom = false}) {
  switch (songId) {
    case 'twinkle':
      return 'star';
    case 'ode_to_joy':
      return 'sunburst';
    case 'two_tigers':
      return 'tiger';
    case 'jasmine':
      return 'flower';
    case 'amazing_grace':
      return 'moon';
    case 'happy_birthday':
      return 'campfire';
    case 'auld_lang_syne':
      return 'wave';
    case 'first_breeze':
      return 'vinyl';
    default:
      if (!isCustom) return 'star';
      return 'vinyl';
  }
}

SongIconPreset songIconPresetById(String? iconId, {String songId = ''}) {
  final targetId = (iconId != null &&
          songIconPresets.any((preset) => preset.id == iconId))
      ? iconId
      : defaultIconIdForSong(songId, isCustom: songId.startsWith('custom'));
  return songIconPresets.firstWhere(
    (preset) => preset.id == targetId,
    orElse: () => songIconPresets.first,
  );
}

class Song {
  const Song({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.level,
    required this.color,
    required this.notes,
    this.iconId,
    this.isCustom = false,
    this.isPro = false,
  });

  factory Song.fromJson(Map<String, Object?> json) {
    final rawNotes = json['notes'] as List<Object?>? ?? const [];
    final notes = rawNotes
        .map(
          (note) =>
              PracticeNote.fromJson(Map<String, Object?>.from(note! as Map)),
        )
        .toList();
    if (notes.isEmpty) {
      throw const HarmonicaTabFormatException('emptyNotation');
    }
    final id = json['id'] as String;
    final rawIconId = json['iconId'] as String?;
    return Song(
      id: id,
      title: json['title'] as String,
      subtitle: 'customSongSubtitle',
      level: 'custom',
      color: const Color(0xFF506A5D),
      notes: notes,
      iconId: rawIconId ?? defaultIconIdForSong(id, isCustom: true),
      isCustom: true,
    );
  }

  final String id;
  final String title;
  final String subtitle;
  final String level;
  final Color color;
  final List<PracticeNote> notes;
  final String? iconId;
  final bool isCustom;
  final bool isPro;

  String get defaultIconId =>
      iconId ?? defaultIconIdForSong(id, isCustom: isCustom);

  String get tabPreview => notes.map((note) => note.tab).join(' ');

  Map<String, Object> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'level': level,
      'iconId': defaultIconId,
      'notes': notes.map((note) => note.toJson()).toList(),
    };
  }
}

List<PracticeNote> parseHarmonicaTabs(String input) {
  const blow = [60, 64, 67, 72, 76, 79, 84, 88, 91, 96];
  const draw = [62, 67, 71, 74, 77, 81, 83, 86, 89, 93];
  final normalized = input.replaceAll(RegExp(r'[|｜,，;；]+'), ' ');
  final tokens = normalized
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty && token != '-' && token != '—');
  final notes = <PracticeNote>[];

  for (final token in tokens) {
    final match = RegExp(r'^(10|[1-9])([↑↓])$').firstMatch(token);
    if (match == null) {
      throw HarmonicaTabFormatException('invalidNotation', token: token);
    }
    final hole = int.parse(match.group(1)!);
    final direction = match.group(2)!;
    final midi = direction == '↑' ? blow[hole - 1] : draw[hole - 1];
    final label = noteLabelForMidi(midi);
    final noteName = label.substring(0, label.length - 1);
    final octave = int.parse(label.substring(label.length - 1));
    notes.add(
      PracticeNote(note: noteName, octave: octave, tab: '$hole$direction'),
    );
  }

  if (notes.isEmpty) {
    throw const HarmonicaTabFormatException('emptyNotation');
  }
  return notes;
}

const jianpuQuickNotes = <({String jianpu, String solfege, String tab})>[
  (jianpu: '1', solfege: 'Do', tab: '4↑'),
  (jianpu: '2', solfege: 'Re', tab: '4↓'),
  (jianpu: '3', solfege: 'Mi', tab: '5↑'),
  (jianpu: '4', solfege: 'Fa', tab: '5↓'),
  (jianpu: '5', solfege: 'Sol', tab: '6↑'),
  (jianpu: '6', solfege: 'La', tab: '6↓'),
  (jianpu: '7', solfege: 'Si', tab: '7↓'),
  (jianpu: "1'", solfege: 'Do⁺', tab: '7↑'),
];

/// Converts numbered musical notation (Jianpu 1–7, low `.1`/`1.`, high `1'`/`1+`)
/// or mixed tab input into space-separated 10-hole harmonica tabs.
String convertJianpuToTabs(String input) {
  const middleMap = <String, String>{
    '1': '4↑',
    '2': '4↓',
    '3': '5↑',
    '4': '5↓',
    '5': '6↑',
    '6': '6↓',
    '7': '7↓',
  };
  const highMap = <String, String>{
    '1': '7↑',
    '2': '8↓',
    '3': '8↑',
    '4': '9↓',
    '5': '9↑',
    '6': '10↓',
    '7': '10↑',
  };
  const lowMap = <String, String>{
    '1': '1↑',
    '2': '1↓',
    '3': '2↑',
    '4': '2↓',
    '5': '3↑',
    '6': '3↓',
    '7': '3↓',
  };

  final rawTokens = input
      .replaceAll(RegExp(r'[|｜,，;；/]+'), ' ')
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty && token != '-' && token != '—' && token != '0');

  final converted = <String>[];
  for (final token in rawTokens) {
    if (RegExp(r'^(10|[1-9])([↑↓])$').hasMatch(token)) {
      converted.add(token);
      continue;
    }
    final highMatch = RegExp(r"^([1-7])['’⁺\^]$|^\+([1-7])$").firstMatch(token);
    if (highMatch != null) {
      final digit = highMatch.group(1) ?? highMatch.group(2)!;
      converted.add(highMap[digit]!);
      continue;
    }
    final lowMatch = RegExp(r'^\.([1-7])$|^([1-7])\.$|^_([1-7])$').firstMatch(token);
    if (lowMatch != null) {
      final digit = lowMatch.group(1) ?? lowMatch.group(2) ?? lowMatch.group(3)!;
      converted.add(lowMap[digit]!);
      continue;
    }
    if (RegExp(r'^[1-7]+$').hasMatch(token)) {
      for (final rune in token.runes) {
        final char = String.fromCharCode(rune);
        if (middleMap.containsKey(char)) {
          converted.add(middleMap[char]!);
        }
      }
      continue;
    }
    throw HarmonicaTabFormatException('invalidNotation', token: token);
  }

  if (converted.isEmpty) {
    throw const HarmonicaTabFormatException('emptyNotation');
  }
  return converted.join(' ');
}

String formatSongShareCode({required String title, required String tabs}) {
  return '【初鸣曲谱】${title.trim()}｜${tabs.trim()}';
}

({String? title, String tabs}) parseSongShareOrJianpu(String rawInput) {
  final trimmed = rawInput.trim();
  if (trimmed.isEmpty) {
    throw const HarmonicaTabFormatException('emptyNotation');
  }
  final shareMatch = RegExp(
    r'^(?:【[^】]+】)?\s*([^|｜\n]{1,32})\s*[|｜]\s*(.+)$',
    dotAll: true,
  ).firstMatch(trimmed);
  if (shareMatch != null) {
    final extractedTitle = shareMatch.group(1)!.trim();
    final rawBody = shareMatch.group(2)!.trim();
    final tabs = convertJianpuToTabs(rawBody);
    return (title: extractedTitle.isEmpty ? null : extractedTitle, tabs: tabs);
  }
  final tabs = convertJianpuToTabs(trimmed);
  return (title: null, tabs: tabs);
}

const songs = [
  Song(
    id: 'twinkle',
    title: '小星星',
    subtitle: 'song_twinkle_subtitle',
    level: 'easy',
    color: Color(0xFF344B66),
    iconId: 'star',
    notes: [
      PracticeNote(note: 'C', octave: 5, tab: '4↑'),
      PracticeNote(note: 'C', octave: 5, tab: '4↑'),
      PracticeNote(note: 'G', octave: 5, tab: '6↑'),
      PracticeNote(note: 'G', octave: 5, tab: '6↑'),
      PracticeNote(note: 'A', octave: 5, tab: '6↓'),
      PracticeNote(note: 'A', octave: 5, tab: '6↓'),
      PracticeNote(note: 'G', octave: 5, tab: '6↑'),
    ],
  ),
  Song(
    id: 'ode_to_joy',
    title: '欢乐颂',
    subtitle: 'song_ode_to_joy_subtitle',
    level: 'easy',
    color: Color(0xFF57432F),
    iconId: 'sunburst',
    notes: [
      PracticeNote(note: 'E', octave: 5, tab: '5↑'),
      PracticeNote(note: 'E', octave: 5, tab: '5↑'),
      PracticeNote(note: 'F', octave: 5, tab: '5↓'),
      PracticeNote(note: 'G', octave: 5, tab: '6↑'),
      PracticeNote(note: 'G', octave: 5, tab: '6↑'),
      PracticeNote(note: 'F', octave: 5, tab: '5↓'),
      PracticeNote(note: 'E', octave: 5, tab: '5↑'),
      PracticeNote(note: 'D', octave: 5, tab: '4↓'),
    ],
  ),
  Song(
    id: 'two_tigers',
    title: '两只老虎',
    subtitle: 'song_two_tigers_subtitle',
    level: 'easy',
    color: Color(0xFF345045),
    iconId: 'tiger',
    notes: [
      PracticeNote(note: 'C', octave: 5, tab: '4↑'),
      PracticeNote(note: 'D', octave: 5, tab: '4↓'),
      PracticeNote(note: 'E', octave: 5, tab: '5↑'),
      PracticeNote(note: 'C', octave: 5, tab: '4↑'),
      PracticeNote(note: 'C', octave: 5, tab: '4↑'),
      PracticeNote(note: 'D', octave: 5, tab: '4↓'),
      PracticeNote(note: 'E', octave: 5, tab: '5↑'),
      PracticeNote(note: 'C', octave: 5, tab: '4↑'),
    ],
  ),
  Song(
    id: 'jasmine',
    title: '茉莉花',
    subtitle: 'song_jasmine_subtitle',
    level: 'advanced',
    color: Color(0xFF4A3D5E),
    iconId: 'flower',
    isPro: true,
    notes: [
      // 传统五声调式校对版（好一朵美丽的茉莉花：3 3 5 6 1̇ 1̇ 6 5）
      PracticeNote(note: 'E', octave: 5, tab: '5↑'),
      PracticeNote(note: 'E', octave: 5, tab: '5↑'),
      PracticeNote(note: 'G', octave: 5, tab: '6↑'),
      PracticeNote(note: 'A', octave: 5, tab: '6↓'),
      PracticeNote(note: 'C', octave: 6, tab: '7↑'),
      PracticeNote(note: 'C', octave: 6, tab: '7↑'),
      PracticeNote(note: 'A', octave: 5, tab: '6↓'),
      PracticeNote(note: 'G', octave: 5, tab: '6↑'),
    ],
  ),
  Song(
    id: 'amazing_grace',
    title: '奇异恩典',
    subtitle: 'song_amazing_grace_subtitle',
    level: 'advanced',
    color: Color(0xFF0B7285),
    iconId: 'moon',
    isPro: true,
    notes: [
      // 公版圣咏旋律（5̣ 1 3 1 3 2 1）
      PracticeNote(note: 'G', octave: 4, tab: '3↑'),
      PracticeNote(note: 'C', octave: 5, tab: '4↑'),
      PracticeNote(note: 'E', octave: 5, tab: '5↑'),
      PracticeNote(note: 'C', octave: 5, tab: '4↑'),
      PracticeNote(note: 'E', octave: 5, tab: '5↑'),
      PracticeNote(note: 'D', octave: 5, tab: '4↓'),
      PracticeNote(note: 'C', octave: 5, tab: '4↑'),
    ],
  ),
  Song(
    id: 'happy_birthday',
    title: '生日快乐',
    subtitle: 'song_happy_birthday_subtitle',
    level: 'easy',
    color: Color(0xFFC92A2A),
    iconId: 'campfire',
    isPro: true,
    notes: [
      PracticeNote(note: 'G', octave: 5, tab: '6↑'),
      PracticeNote(note: 'G', octave: 5, tab: '6↑'),
      PracticeNote(note: 'A', octave: 5, tab: '6↓'),
      PracticeNote(note: 'G', octave: 5, tab: '6↑'),
      PracticeNote(note: 'C', octave: 6, tab: '7↑'),
      PracticeNote(note: 'B', octave: 5, tab: '7↓'),
    ],
  ),
  Song(
    id: 'auld_lang_syne',
    title: '送别',
    subtitle: 'song_auld_lang_syne_subtitle',
    level: 'easy',
    color: Color(0xFF0077B6),
    iconId: 'wave',
    isPro: true,
    notes: [
      PracticeNote(note: 'G', octave: 5, tab: '6↑'),
      PracticeNote(note: 'E', octave: 5, tab: '5↑'),
      PracticeNote(note: 'G', octave: 5, tab: '6↑'),
      PracticeNote(note: 'C', octave: 6, tab: '7↑'),
      PracticeNote(note: 'A', octave: 5, tab: '6↓'),
      PracticeNote(note: 'C', octave: 6, tab: '7↑'),
      PracticeNote(note: 'G', octave: 5, tab: '6↑'),
    ],
  ),
  Song(
    id: 'first_breeze',
    title: '初鸣微风',
    subtitle: 'song_first_breeze_subtitle',
    level: 'advanced',
    color: Color(0xFF1E293B),
    iconId: 'vinyl',
    isPro: true,
    notes: [
      // 初鸣原创中音区连奏练习曲（4–7 孔自然音阶起伏）
      PracticeNote(note: 'C', octave: 5, tab: '4↑'),
      PracticeNote(note: 'E', octave: 5, tab: '5↑'),
      PracticeNote(note: 'G', octave: 5, tab: '6↑'),
      PracticeNote(note: 'A', octave: 5, tab: '6↓'),
      PracticeNote(note: 'G', octave: 5, tab: '6↑'),
      PracticeNote(note: 'F', octave: 5, tab: '5↓'),
      PracticeNote(note: 'E', octave: 5, tab: '5↑'),
      PracticeNote(note: 'D', octave: 5, tab: '4↓'),
      PracticeNote(note: 'C', octave: 5, tab: '4↑'),
    ],
  ),
];
