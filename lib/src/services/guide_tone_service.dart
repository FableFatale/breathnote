import 'package:flutter/services.dart';

class GuideToneService {
  factory GuideToneService() => _instance;

  GuideToneService._();

  static final GuideToneService _instance = GuideToneService._();
  static const _channel = MethodChannel('app.breathnote/audio_control');

  Future<int> play({
    required List<double> frequencies,
    required double speed,
    required bool repeat,
  }) async {
    return await _channel.invokeMethod<int>('playGuideSequence', {
          'frequencies': frequencies,
          'speed': speed,
          'repeat': repeat,
        }) ??
        0;
  }

  Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stopGuideSequence');
    } on MissingPluginException {
      // Widget tests and unsupported platforms have no native audio channel.
    }
  }
}
