import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/harmonica_layout.dart';
import '../models/pitch_reading.dart';
import '../models/practice_note.dart';
import '../models/song.dart';
import '../models/song_score.dart';
import '../services/preferences_service.dart';
import '../services/purchase_service.dart';
import '../version.dart';

class AppController extends ChangeNotifier {
  AppController({
    PreferencesService? preferences,
    PurchaseService? purchaseService,
  }) : _preferences = preferences ?? const PreferencesService(),
       _purchaseService = purchaseService ?? const PurchaseService();

  final PreferencesService _preferences;
  final PurchaseService _purchaseService;

  static const defaultDisplayName = '__default__';
  static const legacyDefaultDisplayName = '口琴练习者';
  static const sawHarmonicaGuideKey = 'sawHarmonicaGuide';
  static const hasRegisteredHarmonicaKey = 'hasRegisteredHarmonica';
  static const isProUnlockedKey = 'isProUnlocked';
  static const firstInstallAtKey = 'firstInstallAt';
  static const introOfferDuration = Duration(hours: 48);
  static const totalLessonCount = 10;

  String displayName = defaultDisplayName;
  String harmonicaKey = 'C';
  String? activePresetId;
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
  bool sawHarmonicaGuide = false;
  bool hasRegisteredHarmonica = false;
  bool isProUnlocked = false;
  DateTime? firstInstallAt;
  String appVersionLabel = kAppDisplayVersion;
  final Set<String> practiceDates = {};
  final Set<String> completedLessons = {};
  final Set<String> seenCoachTips = {};
  final Set<String> favoriteSongs = {};
  final Map<String, String> songIconOverrides = {};
  final Map<String, int> songBestScores = {};
  final Map<String, int> songBestStars = {};
  final List<SongScoreAttempt> songScoreHistory = [];
  final List<HarmonicaPreset> harmonicaPresets = [];
  final List<Song> customSongs = [];
  final List<PitchAttempt> pitchAttempts = [];

  static const _maxPitchAttempts = 400;
  static const _maxSongScoreHistory = 60;

  List<Song> get allSongs => [...customSongs, ...songs];

  /// 真实按设备首次安装时间计算的 48 小时新手首单立减剩余时长（绝不伪造倒计时）。
  Duration get introOfferRemaining {
    if (isProUnlocked) return Duration.zero;
    final start = firstInstallAt;
    if (start == null) return introOfferDuration;
    final left = introOfferDuration - DateTime.now().difference(start);
    return left.isNegative ? Duration.zero : left;
  }

  bool get hasActiveIntroOffer =>
      !isProUnlocked && introOfferRemaining > Duration.zero;

  HarmonicaPreset? get activePreset {
    final id = activePresetId;
    if (id == null) return null;
    for (final preset in harmonicaPresets) {
      if (preset.id == id) return preset;
    }
    return null;
  }

  int bestScoreForSong(String songId) => songBestScores[songId] ?? 0;

  int bestStarsForSong(String songId) => songBestStars[songId] ?? 0;

  List<SongScoreAttempt> songHistoryFor(String songId) {
    return songScoreHistory
        .where((attempt) => attempt.songId == songId)
        .toList()
        .reversed
        .toList();
  }

  SongScoreAttempt? latestScoredAttempt(String songId) {
    for (var i = songScoreHistory.length - 1; i >= 0; i--) {
      final attempt = songScoreHistory[i];
      if (attempt.songId == songId && attempt.mode == 'score') {
        return attempt;
      }
    }
    return null;
  }

  bool isSongCompleted(String songId) =>
      bestStarsForSong(songId) > 0 || bestScoreForSong(songId) > 0;

  bool isSongFavorite(String songId) => favoriteSongs.contains(songId);

  String iconIdForSong(Song song) {
    final override = songIconOverrides[song.id];
    if (override != null &&
        songIconPresets.any((preset) => preset.id == override)) {
      return override;
    }
    return song.defaultIconId;
  }

  bool hasSongIconOverride(Song song) {
    final current = iconIdForSong(song);
    final defaultId = defaultIconIdForSong(song.id, isCustom: song.isCustom);
    return current != defaultId;
  }

  int get practiceMinutes => practiceSeconds ~/ 60;

  double get lessonProgress =>
      (completedLessons.length / totalLessonCount).clamp(0.0, 1.0).toDouble();

  int get streakDays => currentStreak;

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
      final runtimeVersion = values['__runtimeAppVersion'] as String?;
      if (runtimeVersion != null && runtimeVersion.isNotEmpty) {
        appVersionLabel = runtimeVersion;
      }
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
      sawHarmonicaGuide =
          values[sawHarmonicaGuideKey] as bool? ?? sawHarmonicaGuide;
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
      seenCoachTips.addAll(_decodeStringList(values['seenCoachTips']));
      favoriteSongs.addAll(_decodeStringList(values['favoriteSongs']));
      songIconOverrides.addAll(_decodeStringMap(values['songIconOverrides']));
      songBestScores.addAll(_decodeIntMap(values['songBestScores']));
      songBestStars.addAll(_decodeIntMap(values['songBestStars']));
      songScoreHistory.addAll(_decodeSongScoreHistory(values['songScoreHistory']));
      if (songScoreHistory.length > _maxSongScoreHistory) {
        songScoreHistory.removeRange(
          0,
          songScoreHistory.length - _maxSongScoreHistory,
        );
      }
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
      final savedPro = values[isProUnlockedKey] as bool?;
      if (savedPro != null) {
        isProUnlocked = savedPro;
      }
      final savedFirstInstall = values[firstInstallAtKey] as String?;
      final parsedInstall = savedFirstInstall == null
          ? null
          : DateTime.tryParse(savedFirstInstall);
      if (parsedInstall != null) {
        firstInstallAt = parsedInstall;
      } else {
        firstInstallAt = DateTime.now();
        unawaited(_persist(firstInstallAtKey, firstInstallAt!.toIso8601String()));
      }
      activePresetId = values['activePresetId'] as String?;
      final rawPresets = values['harmonicaPresets'];
      if (rawPresets is String && rawPresets.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawPresets) as List<Object?>;
          for (final entry in decoded) {
            if (entry is Map) {
              harmonicaPresets.add(
                HarmonicaPreset.fromJson(Map<String, Object?>.from(entry)),
              );
            }
          }
        } catch (_) {}
      }
      final savedRegistered = values[hasRegisteredHarmonicaKey] as bool?;
      if (savedRegistered != null) {
        hasRegisteredHarmonica = savedRegistered;
      } else if (values['harmonicaKey'] != null ||
          completedLessons.isNotEmpty ||
          practiceSeconds > 0 ||
          customSongs.isNotEmpty ||
          values[sawHarmonicaGuideKey] == true) {
        hasRegisteredHarmonica = true;
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
    if (value == harmonicaKey && activePresetId == null) return;
    harmonicaKey = value;
    if (activePreset != null && activePreset!.key != value) {
      activePresetId = null;
    }
    notifyListeners();
    await Future.wait([
      _persist('harmonicaKey', value),
      if (activePresetId == null) _persist('activePresetId', ''),
    ]);
  }

  Future<HarmonicaPreset> addHarmonicaPreset({
    required String name,
    required String key,
  }) async {
    final trimmed = name.trim();
    final preset = HarmonicaPreset(
      id: 'harp_${DateTime.now().microsecondsSinceEpoch}',
      name: trimmed.isEmpty ? '$key 调口琴' : trimmed,
      key: key,
    );
    harmonicaPresets.add(preset);
    activePresetId = preset.id;
    harmonicaKey = key;
    notifyListeners();
    await Future.wait([
      _persist(
        'harmonicaPresets',
        jsonEncode(harmonicaPresets.map((item) => item.toJson()).toList()),
      ),
      _persist('activePresetId', preset.id),
      _persist('harmonicaKey', key),
    ]);
    return preset;
  }

  Future<void> selectHarmonicaPreset(String id) async {
    HarmonicaPreset? target;
    for (final preset in harmonicaPresets) {
      if (preset.id == id) {
        target = preset;
        break;
      }
    }
    if (target == null) return;
    activePresetId = target.id;
    harmonicaKey = target.key;
    notifyListeners();
    await Future.wait([
      _persist('activePresetId', target.id),
      _persist('harmonicaKey', target.key),
    ]);
  }

  Future<void> removeHarmonicaPreset(String id) async {
    harmonicaPresets.removeWhere((preset) => preset.id == id);
    if (activePresetId == id) {
      activePresetId = null;
    }
    notifyListeners();
    await Future.wait([
      _persist(
        'harmonicaPresets',
        jsonEncode(harmonicaPresets.map((item) => item.toJson()).toList()),
      ),
      _persist('activePresetId', activePresetId ?? ''),
    ]);
  }

  Future<void> completeHarmonicaRegistration({String? key}) async {
    final targetKey = key ?? harmonicaKey;
    final keyChanged = targetKey != harmonicaKey;
    harmonicaKey = targetKey;
    hasRegisteredHarmonica = true;
    notifyListeners();
    await Future.wait([
      _persist(hasRegisteredHarmonicaKey, true),
      if (keyChanged || key != null) _persist('harmonicaKey', targetKey),
    ]);
  }

  Future<PurchaseResult> purchasePro() async {
    final result = await _purchaseService.purchaseProLifetime();
    if (result.unlocked && !isProUnlocked) {
      isProUnlocked = true;
      notifyListeners();
      await _persist(isProUnlockedKey, true);
    }
    return result;
  }

  Future<PurchaseResult> restorePro() async {
    final result = await _purchaseService.restorePurchases();
    if (result.unlocked && !isProUnlocked) {
      isProUnlocked = true;
      notifyListeners();
      await _persist(isProUnlockedKey, true);
    }
    return result;
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

  Future<void> markHarmonicaGuideSeen() async {
    if (sawHarmonicaGuide) return;
    sawHarmonicaGuide = true;
    notifyListeners();
    await _persist(sawHarmonicaGuideKey, true);
  }

  Future<void> dismissCoachTip(String featureId) async {
    if (!seenCoachTips.add(featureId)) return;
    notifyListeners();
    await _persist('seenCoachTips', jsonEncode(seenCoachTips.toList()));
  }

  Future<void> reopenCoachTip(String featureId) async {
    if (!seenCoachTips.remove(featureId)) return;
    notifyListeners();
    await _persist('seenCoachTips', jsonEncode(seenCoachTips.toList()));
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
    bool updateBestScore = true,
  }) async {
    final safeSeconds = seconds.clamp(1, 3600);
    final safeScore = score.clamp(0, 100);
    practiceSeconds += safeSeconds;
    final bestChanged = updateBestScore && safeScore > bestScore;
    if (bestChanged) {
      bestScore = safeScore;
    }
    practiceDates.add(_dateKey(DateTime.now()));
    notifyListeners();
    await Future.wait([
      _persist('practiceSeconds', practiceSeconds),
      if (bestChanged) _persist('bestScore', bestScore),
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
    String? iconId,
    bool skipBendNotes = false,
  }) async {
    return addCustomSongFromNotes(
      title: title,
      notes: parseHarmonicaTabs(notation),
      iconId: iconId,
      skipBendNotes: skipBendNotes,
    );
  }

  Future<Song> addCustomSongFromNotes({
    required String title,
    required List<PracticeNote> notes,
    String? iconId,
    bool skipBendNotes = false,
  }) async {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw const HarmonicaTabFormatException('enterSongName');
    }
    if (notes.isEmpty) {
      throw const HarmonicaTabFormatException('emptyNotation');
    }
    final validIconId =
        (iconId != null && songIconPresets.any((preset) => preset.id == iconId))
        ? iconId
        : 'vinyl';
    final song = Song(
      id: 'custom_${DateTime.now().microsecondsSinceEpoch}',
      title: normalizedTitle,
      subtitle: 'customSongSubtitle',
      level: 'custom',
      color: const Color(0xFF506A5D),
      notes: List.unmodifiable(notes),
      iconId: validIconId,
      isCustom: true,
      skipBendNotes: skipBendNotes,
    );
    customSongs.add(song);
    notifyListeners();
    await _persistCustomSongs();
    return song;
  }

  Future<void> setSongIcon(String songId, String? iconId) async {
    final isCustom = customSongs.any((s) => s.id == songId);
    final defaultId = defaultIconIdForSong(songId, isCustom: isCustom);
    final validIconId =
        (iconId != null && songIconPresets.any((preset) => preset.id == iconId))
        ? iconId
        : null;

    if (validIconId == null || (!isCustom && validIconId == defaultId)) {
      songIconOverrides.remove(songId);
    } else {
      songIconOverrides[songId] = validIconId;
    }

    var updatedCustom = false;
    for (var i = 0; i < customSongs.length; i++) {
      final current = customSongs[i];
      if (current.id == songId) {
        customSongs[i] = Song(
          id: current.id,
          title: current.title,
          subtitle: current.subtitle,
          level: current.level,
          color: current.color,
          notes: current.notes,
          iconId: validIconId ?? defaultId,
          isCustom: true,
          skipBendNotes: current.skipBendNotes,
        );
        updatedCustom = true;
      }
    }

    notifyListeners();
    await Future.wait([
      _persist('songIconOverrides', jsonEncode(songIconOverrides)),
      if (updatedCustom) _persistCustomSongs(),
    ]);
  }

  Future<void> toggleFavoriteSong(String songId) async {
    if (!favoriteSongs.add(songId)) {
      favoriteSongs.remove(songId);
    }
    notifyListeners();
    await _persist('favoriteSongs', jsonEncode(favoriteSongs.toList()));
  }

  Future<void> recordSongResult({
    required String songId,
    required int score,
    required int stars,
    SongScoreAttempt? attempt,
  }) async {
    final safeScore = score.clamp(0, 100);
    final safeStars = stars.clamp(0, 3);
    var bestScoreChanged = false;
    var bestStarsChanged = false;
    if (safeScore > (songBestScores[songId] ?? 0)) {
      songBestScores[songId] = safeScore;
      bestScoreChanged = true;
    }
    if (safeStars > (songBestStars[songId] ?? 0)) {
      songBestStars[songId] = safeStars;
      bestStarsChanged = true;
    }
    var historyChanged = false;
    if (attempt != null) {
      songScoreHistory.add(attempt);
      if (songScoreHistory.length > _maxSongScoreHistory) {
        songScoreHistory.removeRange(
          0,
          songScoreHistory.length - _maxSongScoreHistory,
        );
      }
      historyChanged = true;
    }
    if (!bestScoreChanged && !bestStarsChanged && !historyChanged) return;
    notifyListeners();
    await Future.wait([
      if (bestScoreChanged)
        _persist('songBestScores', jsonEncode(songBestScores)),
      if (bestStarsChanged)
        _persist('songBestStars', jsonEncode(songBestStars)),
      if (historyChanged)
        _persist(
          'songScoreHistory',
          jsonEncode(songScoreHistory.map((item) => item.toJson()).toList()),
        ),
    ]);
  }

  Future<void> removeCustomSong(String id) async {
    customSongs.removeWhere((song) => song.id == id);
    final removedOverride = songIconOverrides.remove(id) != null;
    final removedFavorite = favoriteSongs.remove(id);
    final removedScore = songBestScores.remove(id) != null;
    final removedStars = songBestStars.remove(id) != null;
    final beforeHistory = songScoreHistory.length;
    songScoreHistory.removeWhere((attempt) => attempt.songId == id);
    final removedHistory = songScoreHistory.length != beforeHistory;
    notifyListeners();
    await Future.wait([
      _persistCustomSongs(),
      if (removedOverride)
        _persist('songIconOverrides', jsonEncode(songIconOverrides)),
      if (removedFavorite)
        _persist('favoriteSongs', jsonEncode(favoriteSongs.toList())),
      if (removedScore)
        _persist('songBestScores', jsonEncode(songBestScores)),
      if (removedStars)
        _persist('songBestStars', jsonEncode(songBestStars)),
      if (removedHistory)
        _persist(
          'songScoreHistory',
          jsonEncode(songScoreHistory.map((item) => item.toJson()).toList()),
        ),
    ]);
  }

  Future<void> reset() async {
    try {
      await _preferences.clear();
    } catch (_) {
      // The visible state still resets when no platform channel is available.
    }
    displayName = defaultDisplayName;
    harmonicaKey = 'C';
    activePresetId = null;
    harmonicaPresets.clear();
    hapticsEnabled = true;
    highContrast = false;
    reduceMotion = false;
    sawHarmonicaGuide = false;
    hasRegisteredHarmonica = false;
    themeMode = ThemeMode.system;
    languageCode = 'zh';
    microphoneSensitivity = 0.68;
    textScale = 1;
    practiceSeconds = 0;
    bestScore = 0;
    practiceDates.clear();
    completedLessons.clear();
    seenCoachTips.clear();
    favoriteSongs.clear();
    songIconOverrides.clear();
    songBestScores.clear();
    songBestStars.clear();
    songScoreHistory.clear();
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

  static Map<String, String> _decodeStringMap(Object? value) {
    if (value is! String || value.isEmpty) return {};
    try {
      final raw = jsonDecode(value);
      if (raw is! Map) return {};
      final result = <String, String>{};
      for (final entry in raw.entries) {
        final key = entry.key;
        final val = entry.value;
        if (key is String && val is String) {
          result[key] = val;
        }
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  static Map<String, int> _decodeIntMap(Object? value) {
    if (value is! String || value.isEmpty) return {};
    try {
      final raw = jsonDecode(value);
      if (raw is! Map) return {};
      final result = <String, int>{};
      for (final entry in raw.entries) {
        final key = entry.key;
        final val = entry.value;
        if (key is String && val is num) {
          result[key] = val.toInt();
        }
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  static List<SongScoreAttempt> _decodeSongScoreHistory(Object? value) {
    if (value is! String || value.isEmpty) return [];
    try {
      final raw = jsonDecode(value);
      if (raw is! List) return [];
      final result = <SongScoreAttempt>[];
      for (final item in raw) {
        final attempt = SongScoreAttempt.fromJson(item);
        if (attempt != null) result.add(attempt);
      }
      return result;
    } catch (_) {
      return [];
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

  /// Non-subscribing read for imperative callbacks, timers, and stream listeners.
  /// Never modifies `_dependents` on the `InheritedElement`.
  static AppController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing above this context.');
    return scope!.notifier!;
  }

  static AppController? maybeRead(BuildContext context) {
    return context.getInheritedWidgetOfExactType<AppScope>()?.notifier;
  }
}
