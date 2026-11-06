import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/song.dart';
import '../services/preferences_service.dart';

class AppController extends ChangeNotifier {
  AppController({PreferencesService? preferences})
    : _preferences = preferences ?? const PreferencesService();

  final PreferencesService _preferences;

  String displayName = '口琴练习者';
  String harmonicaKey = 'F';
  bool hapticsEnabled = true;
  bool highContrast = false;
  bool reduceMotion = false;
  double textScale = 1;
  int practiceSeconds = 0;
  int bestScore = 0;
  bool isLoaded = false;
  final Set<String> practiceDates = {};
  final Set<String> completedLessons = {};
  final List<Song> customSongs = [];

  List<Song> get allSongs => [...songs, ...customSongs];

  int get practiceMinutes => (practiceSeconds / 60).ceil();

  double get lessonProgress =>
      (completedLessons.length / 5).clamp(0.0, 1.0).toDouble();

  int get currentStreak {
    if (practiceDates.isEmpty) return 0;
    final now = DateTime.now();
    var day = DateTime(now.year, now.month, now.day);
    if (!practiceDates.contains(_dateKey(day))) {
      day = day.subtract(const Duration(days: 1));
    }
    var count = 0;
    while (practiceDates.contains(_dateKey(day))) {
      count++;
      day = day.subtract(const Duration(days: 1));
    }
    return count;
  }

  Future<void> load() async {
    try {
      final values = await _preferences.getAll();
      displayName = values['displayName'] as String? ?? displayName;
      harmonicaKey = values['harmonicaKey'] as String? ?? harmonicaKey;
      hapticsEnabled = values['hapticsEnabled'] as bool? ?? hapticsEnabled;
      highContrast = values['highContrast'] as bool? ?? highContrast;
      reduceMotion = values['reduceMotion'] as bool? ?? reduceMotion;
      textScale = (values['textScale'] as num?)?.toDouble() ?? textScale;
      practiceSeconds =
          (values['practiceSeconds'] as num?)?.toInt() ?? practiceSeconds;
      bestScore = (values['bestScore'] as num?)?.toInt() ?? bestScore;
      practiceDates.addAll(_decodeStringList(values['practiceDates']));
      completedLessons.addAll(_decodeStringList(values['completedLessons']));
      final rawSongs = values['customSongs'];
      if (rawSongs is String && rawSongs.isNotEmpty) {
        final decoded = jsonDecode(rawSongs) as List<Object?>;
        customSongs.addAll(
          decoded.map(
            (song) => Song.fromJson(Map<String, Object?>.from(song! as Map)),
          ),
        );
      }
    } catch (_) {
      // Widget tests and unsupported platforms keep the in-memory defaults.
    } finally {
      isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> setDisplayName(String value) async {
    final next = value.trim();
    if (next.isEmpty || next == displayName) return;
    displayName = next;
    notifyListeners();
    await _persist('displayName', next);
  }

  Future<void> setHarmonicaKey(String value) async {
    if (value == harmonicaKey) return;
    harmonicaKey = value;
    notifyListeners();
    await _persist('harmonicaKey', value);
  }

  Future<void> setHapticsEnabled(bool value) async {
    if (value == hapticsEnabled) return;
    hapticsEnabled = value;
    notifyListeners();
    await _persist('hapticsEnabled', value);
  }

  Future<void> setHighContrast(bool value) async {
    if (value == highContrast) return;
    highContrast = value;
    notifyListeners();
    await _persist('highContrast', value);
  }

  Future<void> setReduceMotion(bool value) async {
    if (value == reduceMotion) return;
    reduceMotion = value;
    notifyListeners();
    await _persist('reduceMotion', value);
  }

  Future<void> setTextScale(double value) async {
    final next = value.clamp(0.9, 1.2).toDouble();
    if (next == textScale) return;
    textScale = next;
    notifyListeners();
    await _persist('textScale', next);
  }

  Future<void> markLessonComplete(String lessonId) async {
    if (!completedLessons.add(lessonId)) return;
    notifyListeners();
    await _persist('completedLessons', jsonEncode(completedLessons.toList()));
  }

  Future<void> recordPractice({
    required int seconds,
    required int score,
  }) async {
    final safeSeconds = seconds.clamp(1, 3600);
    final safeScore = score.clamp(0, 100);
    practiceSeconds += safeSeconds;
    bestScore = safeScore > bestScore ? safeScore : bestScore;
    practiceDates.add(_dateKey(DateTime.now()));
    notifyListeners();
    await Future.wait([
      _persist('practiceSeconds', practiceSeconds),
      _persist('bestScore', bestScore),
      _persist('practiceDates', jsonEncode(practiceDates.toList())),
    ]);
  }

  Future<Song> addCustomSong({
    required String title,
    required String notation,
  }) async {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw const FormatException('请输入曲名。');
    }
    final song = Song(
      id: 'custom_${DateTime.now().microsecondsSinceEpoch}',
      title: normalizedTitle,
      subtitle: '自定义曲谱',
      level: '自定义',
      color: const Color(0xFF506A5D),
      notes: parseHarmonicaTabs(notation),
      isCustom: true,
    );
    customSongs.add(song);
    notifyListeners();
    unawaited(_persistCustomSongs());
    return song;
  }

  Future<void> removeCustomSong(String id) async {
    customSongs.removeWhere((song) => song.id == id);
    notifyListeners();
    await _persistCustomSongs();
  }

  Future<void> reset() async {
    try {
      await _preferences.clear();
    } catch (_) {
      // The visible state still resets when no platform channel is available.
    }
    displayName = '口琴练习者';
    harmonicaKey = 'F';
    hapticsEnabled = true;
    highContrast = false;
    reduceMotion = false;
    textScale = 1;
    practiceSeconds = 0;
    bestScore = 0;
    practiceDates.clear();
    completedLessons.clear();
    customSongs.clear();
    notifyListeners();
  }

  Future<void> _persistCustomSongs() {
    return _persist(
      'customSongs',
      jsonEncode(customSongs.map((song) => song.toJson()).toList()),
    );
  }

  Future<void> _persist(String key, Object value) async {
    try {
      await _preferences.setValue(key, value);
    } catch (_) {
      // Keep the in-memory update if native persistence is unavailable.
    }
  }

  static Set<String> _decodeStringList(Object? value) {
    if (value is! String || value.isEmpty) return {};
    try {
      return (jsonDecode(value) as List<Object?>).whereType<String>().toSet();
    } catch (_) {
      return {};
    }
  }

  static String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

class AppScope extends InheritedNotifier<AppController> {
  const AppScope({
    required AppController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static AppController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing above this context.');
    return scope!.notifier!;
  }
}
