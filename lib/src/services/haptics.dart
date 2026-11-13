import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_controller.dart';

abstract final class AppHaptics {
  /// Notifies visual reed-resonance indicators whenever a haptic pulse fires.
  static final ValueNotifier<int> pulseTick = ValueNotifier<int>(0);

  static void _notifyVisualPulse() {
    pulseTick.value = (pulseTick.value + 1) & 0x3fffffff;
  }

  static Future<void> selection(BuildContext context) async {
    if (AppScope.of(context).hapticsEnabled) {
      _notifyVisualPulse();
      try {
        await HapticFeedback.selectionClick();
      } on MissingPluginException {
        // Widget tests and unsupported platforms have no haptic channel.
      }
    }
  }

  /// Simulates the tactile metallic reed resonance of a 10-hole harmonica
  /// when tapping a hole or holding an in-tune breath.
  static Future<void> reedResonance(BuildContext context) async {
    if (AppScope.of(context).hapticsEnabled) {
      _notifyVisualPulse();
      try {
        await HapticFeedback.selectionClick();
        await HapticFeedback.lightImpact();
      } on MissingPluginException {
        // Widget tests and unsupported platforms have no haptic channel.
      }
    }
  }

  static Future<void> light(BuildContext context) async {
    if (AppScope.of(context).hapticsEnabled) {
      _notifyVisualPulse();
      try {
        await HapticFeedback.lightImpact();
      } on MissingPluginException {
        // Widget tests and unsupported platforms have no haptic channel.
      }
    }
  }

  static Future<void> success(BuildContext context) async {
    if (AppScope.of(context).hapticsEnabled) {
      _notifyVisualPulse();
      try {
        await HapticFeedback.mediumImpact();
      } on MissingPluginException {
        // Widget tests and unsupported platforms have no haptic channel.
      }
    }
  }

  static Future<void> warning(BuildContext context) async {
    if (AppScope.of(context).hapticsEnabled) {
      _notifyVisualPulse();
      try {
        await HapticFeedback.heavyImpact();
      } on MissingPluginException {
        // Widget tests and unsupported platforms have no haptic channel.
      }
    }
  }
}
