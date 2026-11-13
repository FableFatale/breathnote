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

  String get defaultIconId =>
      iconId ?? defaultIconIdForSong(id, isCustom: isCustom);

  String get tabPreview => notes.map((note) => note.tab).join(' ');

  Map<String, Object> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'level': level,
      if (iconId != null) 'iconId': iconId!,
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
    notes: [
      PracticeNote(note: 'E', octave: 5, tab: '5↑'),
      PracticeNote(note: 'G', octave: 5, tab: '6↑'),
      PracticeNote(note: 'F', octave: 5, tab: '5↓'),
      PracticeNote(note: 'G', octave: 5, tab: '6↑'),
      PracticeNote(note: 'C', octave: 6, tab: '7↑'),
      PracticeNote(note: 'G', octave: 5, tab: '6↑'),
    ],
  ),
];
