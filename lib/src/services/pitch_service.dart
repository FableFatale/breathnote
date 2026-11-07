import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/pitch_reading.dart';

enum MicrophonePermission { granted, denied, permanentlyDenied }

class PitchService {
  factory PitchService() => _instance;

  PitchService._();

  static final PitchService _instance = PitchService._();
  static const _methods = MethodChannel('app.breathnote/audio_control');
  static const _events = EventChannel('app.breathnote/pitch_events');

  Stream<PitchReading>? _readings;

  @visibleForTesting
  static void resetForTesting() {
    _instance._readings = null;
  }

  Stream<PitchReading> get readings {
    return _readings ??= _events
        .receiveBroadcastStream()
        .map((event) => PitchReading.fromMap(event as Map<Object?, Object?>))
        .asBroadcastStream();
  }

  Future<MicrophonePermission> requestPermission() async {
    final value = await _methods.invokeMethod<String>(
      'requestMicrophonePermission',
    );
    return switch (value) {
      'granted' => MicrophonePermission.granted,
      'permanentlyDenied' => MicrophonePermission.permanentlyDenied,
      _ => MicrophonePermission.denied,
    };
  }

  Future<bool> hasPermission() async {
    return await _methods.invokeMethod<bool>('hasMicrophonePermission') ??
        false;
  }

  Future<void> openAppSettings() {
    return _methods.invokeMethod<void>('openAppSettings');
  }

  Future<bool> start({double sensitivity = 0.68}) async {
    return await _methods.invokeMethod<bool>('startPitchDetection', {
          'sensitivity': sensitivity,
        }) ??
        false;
  }

  Future<void> setSensitivity(double value) {
    return _methods.invokeMethod<void>('setSensitivity', {'value': value});
  }

  Future<void> stop() async {
    try {
      await _methods.invokeMethod<void>('stopPitchDetection');
    } on MissingPluginException {
      // Widget tests and unsupported platforms have no native audio channel.
    }
  }
}
