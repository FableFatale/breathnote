import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../models/practice_note.dart';
import '../models/song.dart';
import '../theme/app_motion.dart';
import 'breath_lesson_screen.dart';
import 'chord_rhythm_lesson_screen.dart';
import 'lesson_detail_screen.dart';
import 'practice_screen.dart';
import 'song_practice_screen.dart';

enum LessonKind {
  introduction,
  breathing,
  firstNote,
  clearNote,
  drawNote,
  firstSong,
  chordRhythm,
  lowRegister,
  highRegister,
  masterSong,
}

@immutable
class LessonDefinition {
  const LessonDefinition({
    required this.id,
    required this.number,
    required this.minutes,
    required this.kind,
    this.isPro = false,
  });

  final String id;
  final String number;
  final int minutes;
  final LessonKind kind;
  final bool isPro;
}

/// 10 节递进式系统课程（第 01–05 课永久免费，第 06–10 课由 Pro 买断解锁）。
const lessons = [
  LessonDefinition(
    id: 'lesson_1',
    number: '01',
    minutes: 4,
    kind: LessonKind.introduction,
  ),
  LessonDefinition(
    id: 'lesson_breath',
    number: '02',
    minutes: 4,
    kind: LessonKind.breathing,
  ),
  LessonDefinition(
    id: 'lesson_2',
    number: '03',
    minutes: 6,
    kind: LessonKind.firstNote,
  ),
  LessonDefinition(
    id: 'lesson_3',
    number: '04',
    minutes: 8,
    kind: LessonKind.clearNote,
  ),
  LessonDefinition(
    id: 'lesson_4',
    number: '05',
    minutes: 5,
    kind: LessonKind.drawNote,
  ),
  LessonDefinition(
    id: 'lesson_5',
    number: '06',
    minutes: 8,
    kind: LessonKind.firstSong,
    isPro: true,
  ),
  LessonDefinition(
    id: 'lesson_chord',
    number: '07',
    minutes: 6,
    kind: LessonKind.chordRhythm,
    isPro: true,
  ),
  LessonDefinition(
    id: 'lesson_6',
    number: '08',
    minutes: 6,
    kind: LessonKind.lowRegister,
    isPro: true,
  ),
  LessonDefinition(
    id: 'lesson_7',
    number: '09',
    minutes: 7,
    kind: LessonKind.highRegister,
    isPro: true,
  ),
  LessonDefinition(
    id: 'lesson_8',
    number: '10',
    minutes: 8,
    kind: LessonKind.masterSong,
    isPro: true,
  ),
];

LessonDefinition lessonById(String id) {
  return lessons.firstWhere((lesson) => lesson.id == id);
}

String? nextLessonId(String id) {
  final index = lessons.indexWhere((lesson) => lesson.id == id);
  if (index < 0 || index == lessons.length - 1) return null;
  return lessons[index + 1].id;
}

Route<void> lessonRoute(BuildContext context, LessonDefinition lesson) {
  final reduceMotion = AppMotion.isReduced(context);
  return AppPageRoute<void>(
    reduceMotion: reduceMotion,
    builder: (routeContext) {
      final strings = routeContext.strings;
      return switch (lesson.kind) {
        LessonKind.introduction => const LessonDetailScreen(),
        LessonKind.breathing => const BreathLessonScreen(),
        LessonKind.firstNote => PracticeScreen(
          target: const PracticeNote(note: 'C', octave: 5, tab: '4↑'),
          lessonId: lesson.id,
          instruction: strings.lessonGuidance(lesson.id),
          step: 3,
        ),
        LessonKind.clearNote => PracticeScreen(
          target: const PracticeNote(note: 'E', octave: 5, tab: '5↑'),
          lessonId: lesson.id,
          instruction: strings.lessonGuidance(lesson.id),
          step: 4,
        ),
        LessonKind.drawNote => PracticeScreen(
          target: const PracticeNote(note: 'D', octave: 5, tab: '4↓'),
          lessonId: lesson.id,
          instruction: strings.lessonGuidance(lesson.id),
          step: 5,
        ),
        LessonKind.firstSong => SongPracticeScreen(
          song: songs.first,
          lessonId: lesson.id,
        ),
        LessonKind.chordRhythm => const ChordRhythmLessonScreen(),
        LessonKind.lowRegister => PracticeScreen(
          target: const PracticeNote(note: 'G', octave: 4, tab: '3↑'),
          lessonId: lesson.id,
          instruction: strings.lessonGuidance(lesson.id),
          step: 8,
        ),
        LessonKind.highRegister => PracticeScreen(
          target: const PracticeNote(note: 'C', octave: 6, tab: '7↑'),
          lessonId: lesson.id,
          instruction: strings.lessonGuidance(lesson.id),
          step: 9,
        ),
        LessonKind.masterSong => SongPracticeScreen(
          song: songs.firstWhere((song) => song.id == 'first_breeze'),
          lessonId: lesson.id,
        ),
      };
    },
  );
}
