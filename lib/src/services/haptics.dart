import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_controller.dart';

abstract final class AppHaptics {
  static const _channel = MethodChannel('app.breathnote/audio_control');

  /// Notifies visual reed-resonance indicators whenever a haptic pulse fires.
  static final ValueNotifier<int> pulseTick = ValueNotifier<int>(0);

  static void _notifyVisualPulse() {
    pulseTick.value = (pulseTick.value + 1) & 0x3fffffff;
  }

  static Future<void> _invokeNative(
    String type,
    Future<void> Function() fallback,
  ) async {
    _notifyVisualPulse();
    try {
      await fallback();
    } on MissingPluginException {
      // Widget tests and unsupported platforms have no haptic channel.
    }
    try {
      await _channel.invokeMethod<void>('triggerHaptic', {'type': type});
    } on MissingPluginException {
      // Widget tests or non-Android platforms fallback to standard haptics.
    } on PlatformException {
      // Ignore platform channel errors.
    }
  }

  static bool _isEnabled(BuildContext context) {
    if (!context.mounted) return false;
    return AppScope.maybeRead(context)?.hapticsEnabled ?? false;
  }

  static Future<void> selection(BuildContext context) async {
    if (_isEnabled(context)) {
      await _invokeNative('selection', HapticFeedback.selectionClick);
    }
  }

  /// Simulates the tactile metallic reed resonance of a 10-hole harmonica
  /// when tapping a hole or holding an in-tune breath.
  static Future<void> reedResonance(BuildContext context) async {
    if (_isEnabled(context)) {
      await _invokeNative('reed', () async {
        await HapticFeedback.selectionClick();
        await HapticFeedback.lightImpact();
      });
    }
  }

  static Future<void> light(BuildContext context) async {
    if (_isEnabled(context)) {
      await _invokeNative('light', HapticFeedback.lightImpact);
    }
  }

  static Future<void> success(BuildContext context) async {
    if (_isEnabled(context)) {
      await _invokeNative('success', HapticFeedback.mediumImpact);
    }
  }

  static Future<void> warning(BuildContext context) async {
    if (_isEnabled(context)) {
      await _invokeNative('warning', HapticFeedback.heavyImpact);
    }
  }
}
