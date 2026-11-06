import 'package:flutter/services.dart';

class PreferencesService {
  const PreferencesService();

  static const _channel = MethodChannel('app.breathnote/preferences');

  Future<Map<String, Object?>> getAll() async {
    final values = await _channel.invokeMapMethod<String, Object?>('getAll');
    return values ?? const {};
  }

  Future<void> setValue(String key, Object value) {
    return _channel.invokeMethod<void>('setValue', {
      'key': key,
      'value': value,
    });
  }

  Future<void> clear() => _channel.invokeMethod<void>('clear');
}
