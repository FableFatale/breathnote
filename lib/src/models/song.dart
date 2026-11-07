import 'package:flutter/material.dart';

import 'practice_note.dart';

class HarmonicaTabFormatException extends FormatException {
  const HarmonicaTabFormatException(this.code, {this.token})
    : super(code, token);

  final String code;
  final String? token;
}

class Song {
  const Song({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.level,
    required this.color,
    required this.notes,
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
    return Song(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: 'customSongSubtitle',
      level: 'custom',
      color: const Color(0xFF506A5D),
      notes: notes,
      isCustom: true,
    );
  }

  final String id;
  final String title;
  final String subtitle;
  final String level;
  final Color color;
  final List<PracticeNote> notes;
  final bool isCustom;

  String get tabPreview => notes.map((note) => note.tab).join(' ');

  Map<String, Object> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'level': level,
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
