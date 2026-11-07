import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/pitch_reading.dart';
import '../models/song.dart';
import '../services/preferences_service.dart';

class AppController extends ChangeNotifier {
  AppController({PreferencesService? preferences})
    : _preferences = preferences ?? const PreferencesService();

  final PreferencesService _preferences;

  static const defaultDisplayName = '__default__';
  static const legacyDefaultDisplayName = '口琴练习者';

  String displayName = defaultDisplayName;
  String harmonicaKey = 'F';
  bool hapticsEnabled = true;
  bool highContrast = false;
  bool reduceMotion = false;
  ThemeMode themeMode = ThemeMode.system;
  String languageCode = 'zh';
  double microphoneSensitivity = 0.68;
  double textScale = 1;
  int practiceSeconds = 0;
  int bestScore = 0;
  bool isLoaded = false;
  final Set<String> practiceDates = {};
  final Set<String> completedLessons = {};
  final List<Song> customSongs = [];
  final List<PitchAttempt> pitchAttempts = [];

  static const _maxPitchAttempts = 400;

  List<Song> get allSongs => [...songs, ...customSongs];

  int get practiceMinutes => practiceSeconds ~/ 60;

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

  List<double?> weakNoteAccuracy({int days = 7}) {
    final cutoff = DateTime.now().subtract(Duration(days: days - 1));
    final grouped = <int, List<double>>{};
    for (final attempt in pitchAttempts) {
      if (attempt.timestamp.isBefore(
        DateTime(cutoff.year, cutoff.month, cutoff.day),
      )) {
        continue;
      }
      grouped.putIfAbsent(attempt.cell, () => []).add(attempt.absoluteCents);
    }
    return List.generate(20, (index) {
      final values = grouped[index];
      if (values == null || values.isEmpty) return null;
      final accurate = values.where((cents) => cents <= 25).length;
      return accurate / values.length;
    });
  }

  Future<void> load() async {
    try {
      final values = await _preferences.getAll();
      final savedDisplayName = values['displayName'] as String?;
      displayName =
          savedDisplayName == null ||
              savedDisplayName == legacyDefaultDisplayName
          ? defaultDisplayName
          : savedDisplayName;
      harmonicaKey = values['harmonicaKey'] as String? ?? harmonicaKey;
      hapticsEnabled = values['hapticsEnabled'] as bool? ?? hapticsEnabled;
      highContrast = values['highContrast'] as bool? ?? highContrast;
      reduceMotion = values['reduceMotion'] as bool? ?? reduceMotion;
      final savedThemeMode = values['themeMode'];
      if (savedThemeMode != null) {
        themeMode = _decodeThemeMode(savedThemeMode);
      }
      final savedLanguage = values['languageCode'] as String?;
      if (const {'zh', 'en', 'ja'}.contains(savedLanguage)) {
        languageCode = savedLanguage!;
      }
      final savedSensitivity = values['microphoneSensitivity'] as num?;
      if (savedSensitivity != null) {
        microphoneSensitivity = savedSensitivity.toDouble().clamp(0.0, 1.0);
      }
      final savedTextScale = values['textScale'] as num?;
      if (savedTextScale != null) textScale = savedTextScale.toDouble();
      practiceSeconds =
          (values['practiceSeconds'] as num?)?.toInt() ?? practiceSeconds;
      bestScore = (values['bestScore'] as num?)?.toInt() ?? bestScore;
      practiceDates.addAll(_decodeStringList(values['practiceDates']));
      completedLessons.addAll(_decodeStringList(values['completedLessons']));
      pitchAttempts.addAll(_decodePitchAttempts(values['pitchAttempts']));
      final rawSongs = values['customSongs'];
      if (rawSongs is String && rawSongs.isNotEmpty) {
        final decoded = jsonDecode(rawSongs) as List<Object?>;
        var shouldRewriteSongs = false;
        for (final entry in decoded) {
          try {
            customSongs.add(
              Song.fromJson(Map<String, Object?>.from(entry! as Map)),
            );
          } catch (_) {
            // Skip one unreadable local song so the remaining songs still load.
            shouldRewriteSongs = true;
          }
        }
        if (shouldRewriteSongs) await _persistCustomSongs();
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

  Future<void> setThemeMode(ThemeMode value) async {
    if (value == themeMode) return;
    themeMode = value;
    notifyListeners();
    await _persist('themeMode', value.name);
  }

  Future<void> setLanguageCode(String value) async {
    if (!const {'zh', 'en', 'ja'}.contains(value) || value == languageCode) {
      return;
    }
    languageCode = value;
    notifyListeners();
    await _persist('languageCode', value);
  }

  Future<void> setMicrophoneSensitivity(double value) async {
    final next = value.clamp(0.0, 1.0).toDouble();
    if ((next - microphoneSensitivity).abs() < 0.001) return;
    microphoneSensitivity = next;
    notifyListeners();
    await _persist('microphoneSensitivity', next);
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

  Future<void> recordPitchAttempt({
    required String tab,
    required PitchReading reading,
    required double cents,
  }) async {
    if (!reading.detected || !cents.isFinite) return;
    final clampedCents = cents.clamp(-50.0, 50.0).toDouble();
    pitchAttempts.add(
      PitchAttempt(
        tab: tab,
        absoluteCents: clampedCents.abs(),
        timestamp: DateTime.now(),
      ),
    );
    if (pitchAttempts.length > _maxPitchAttempts) {
      pitchAttempts.removeRange(0, pitchAttempts.length - _maxPitchAttempts);
    }
    await _persist(
      'pitchAttempts',
      jsonEncode(pitchAttempts.map((item) => item.toJson()).toList()),
    );
  }

  Future<Song> addCustomSong({
    required String title,
    required String notation,
  }) async {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw const HarmonicaTabFormatException('enterSongName');
    }
    final song = Song(
      id: 'custom_${DateTime.now().microsecondsSinceEpoch}',
      title: normalizedTitle,
      subtitle: 'customSongSubtitle',
      level: 'custom',
      color: const Color(0xFF506A5D),
      notes: parseHarmonicaTabs(notation),
      isCustom: true,
    );
    customSongs.add(song);
    notifyListeners();
    await _persistCustomSongs();
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
    displayName = defaultDisplayName;
    harmonicaKey = 'F';
    hapticsEnabled = true;
    highContrast = false;
    reduceMotion = false;
    themeMode = ThemeMode.system;
    languageCode = 'zh';
    microphoneSensitivity = 0.68;
    textScale = 1;
    practiceSeconds = 0;
    bestScore = 0;
    practiceDates.clear();
    completedLessons.clear();
    customSongs.clear();
    pitchAttempts.clear();
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

  static List<PitchAttempt> _decodePitchAttempts(Object? value) {
    if (value is! String || value.isEmpty) return [];
    try {
      return (jsonDecode(value) as List<Object?>)
          .map(
            (item) =>
                PitchAttempt.fromJson(Map<String, Object?>.from(item! as Map)),
          )
          .where((item) => item.absoluteCents.isFinite)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  static ThemeMode _decodeThemeMode(Object? value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }
}

class PitchAttempt {
  const PitchAttempt({
    required this.tab,
    required this.absoluteCents,
    required this.timestamp,
  });

  factory PitchAttempt.fromJson(Map<String, Object?> json) {
    return PitchAttempt(
      tab: json['tab'] as String? ?? '4↑',
      absoluteCents: (json['cents'] as num?)?.toDouble().abs() ?? 50,
      timestamp:
          DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
    );
  }

  final String tab;
  final double absoluteCents;
  final DateTime timestamp;

  int get cell {
    final hole = int.tryParse(tab.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
    final clampedHole = hole.clamp(1, 10).toInt();
    final row = tab.contains('↓') ? 1 : 0;
    return row * 10 + clampedHole - 1;
  }

  Map<String, Object> toJson() {
    return {
      'tab': tab,
      'cents': absoluteCents,
      'date': timestamp.toIso8601String(),
    };
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
