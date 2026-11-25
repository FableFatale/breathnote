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
    List<double>? beats,
  }) async {
    try {
      return await _channel.invokeMethod<int>('playGuideSequence', {
            'frequencies': frequencies,
            'speed': speed,
            'repeat': repeat,
            'beats': ?beats,
          }) ??
          0;
    } on MissingPluginException {
      throw PlatformException(
        code: 'unsupported',
        message: 'featureUnavailable',
      );
    }
  }

  Future<void> playMetronomeClick({bool accent = false}) async {
    try {
      await _channel.invokeMethod<void>('playMetronomeClick', {
        'accent': accent,
      });
    } on MissingPluginException {
      // Widget tests and unsupported platforms have no native audio channel.
    } on PlatformException {
      // Ignore transient audio focus errors while playing a metronome click.
    }
  }

  Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stopGuideSequence');
    } on MissingPluginException {
      // Widget tests and unsupported platforms have no native audio channel.
    }
  }
}
