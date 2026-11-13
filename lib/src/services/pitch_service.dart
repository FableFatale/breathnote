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
    final String? value;
    try {
      value = await _methods.invokeMethod<String>(
        'requestMicrophonePermission',
      );
    } on MissingPluginException {
      throw PlatformException(
        code: 'unsupported',
        message: 'featureUnavailable',
      );
    }
    return switch (value) {
      'granted' => MicrophonePermission.granted,
      'permanentlyDenied' => MicrophonePermission.permanentlyDenied,
      _ => MicrophonePermission.denied,
    };
  }

  Future<bool> hasPermission() async {
    try {
      return await _methods.invokeMethod<bool>('hasMicrophonePermission') ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> openAppSettings() async {
    try {
      await _methods.invokeMethod<void>('openAppSettings');
    } on MissingPluginException {
      // Unsupported platforms have no native app settings page.
    }
  }

  Future<bool> start({double sensitivity = 0.68}) async {
    try {
      return await _methods.invokeMethod<bool>('startPitchDetection', {
            'sensitivity': sensitivity,
          }) ??
          false;
    } on MissingPluginException {
      throw PlatformException(
        code: 'unsupported',
        message: 'featureUnavailable',
      );
    }
  }

  Future<void> setSensitivity(double value) async {
    try {
      await _methods.invokeMethod<void>('setSensitivity', {'value': value});
    } on MissingPluginException {
      // The preference still updates in memory on unsupported platforms.
    }
  }

  Future<void> stop() async {
    try {
      await _methods.invokeMethod<void>('stopPitchDetection');
    } on MissingPluginException {
      // Widget tests and unsupported platforms have no native audio channel.
    }
  }
}
