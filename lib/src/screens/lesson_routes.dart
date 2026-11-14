import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../models/practice_note.dart';
import '../models/song.dart';
import '../theme/app_motion.dart';
import 'lesson_detail_screen.dart';
import 'practice_screen.dart';
import 'song_practice_screen.dart';

enum LessonKind { introduction, firstNote, clearNote, drawNote, firstSong }

@immutable
class LessonDefinition {
  const LessonDefinition({
    required this.id,
    required this.number,
    required this.minutes,
    required this.kind,
  });

  final String id;
  final String number;
  final int minutes;
  final LessonKind kind;
}

const lessons = [
  LessonDefinition(
    id: 'lesson_1',
    number: '01',
    minutes: 4,
    kind: LessonKind.introduction,
  ),
  LessonDefinition(
    id: 'lesson_2',
    number: '02',
    minutes: 6,
    kind: LessonKind.firstNote,
  ),
  LessonDefinition(
    id: 'lesson_3',
    number: '03',
    minutes: 8,
    kind: LessonKind.clearNote,
  ),
  LessonDefinition(
    id: 'lesson_4',
    number: '04',
    minutes: 5,
    kind: LessonKind.drawNote,
  ),
  LessonDefinition(
    id: 'lesson_5',
    number: '05',
    minutes: 8,
    kind: LessonKind.firstSong,
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
        LessonKind.firstNote => PracticeScreen(
          target: const PracticeNote(note: 'C', octave: 5, tab: '4↑'),
          lessonId: lesson.id,
          instruction: strings.lessonGuidance(lesson.id),
          step: 2,
        ),
        LessonKind.clearNote => PracticeScreen(
          target: const PracticeNote(note: 'E', octave: 5, tab: '5↑'),
          lessonId: lesson.id,
          instruction: strings.lessonGuidance(lesson.id),
          step: 3,
        ),
        LessonKind.drawNote => PracticeScreen(
          target: const PracticeNote(note: 'D', octave: 5, tab: '4↓'),
          lessonId: lesson.id,
          instruction: strings.lessonGuidance(lesson.id),
          step: 4,
        ),
        LessonKind.firstSong => SongPracticeScreen(
          song: songs.first,
          lessonId: lesson.id,
        ),
      };
    },
  );
}
