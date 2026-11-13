import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  const PreferencesService();

  static const _channel = MethodChannel('app.breathnote/preferences');
  static const _keys = <String>{
    'displayName',
    'harmonicaKey',
    'hapticsEnabled',
    'highContrast',
    'reduceMotion',
    'themeMode',
    'languageCode',
    'microphoneSensitivity',
    'textScale',
    'practiceSeconds',
    'bestScore',
    'practiceDates',
    'completedLessons',
    'customSongs',
    'pitchAttempts',
    'sawHarmonicaGuide',
  };

  Future<Map<String, Object?>> getAll() async {
    if (kIsWeb) {
      final preferences = await SharedPreferences.getInstance();
      return {for (final key in _keys) key: ?preferences.get(key)};
    }
    final values = await _channel.invokeMapMethod<String, Object?>('getAll');
    return values ?? const {};
  }

  Future<void> setValue(String key, Object value) async {
    if (kIsWeb) {
      final preferences = await SharedPreferences.getInstance();
      switch (value) {
        case String():
          await preferences.setString(key, value);
        case bool():
          await preferences.setBool(key, value);
        case int():
          await preferences.setInt(key, value);
        case double():
          await preferences.setDouble(key, value);
        default:
          throw ArgumentError.value(value, key, 'Unsupported preference type');
      }
      return;
    }
    await _channel.invokeMethod<void>('setValue', {'key': key, 'value': value});
  }

  Future<void> clear() async {
    if (kIsWeb) {
      final preferences = await SharedPreferences.getInstance();
      for (final key in _keys) {
        await preferences.remove(key);
      }
      return;
    }
    await _channel.invokeMethod<void>('clear');
  }
}
