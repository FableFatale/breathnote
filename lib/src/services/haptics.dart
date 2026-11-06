import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_controller.dart';

abstract final class AppHaptics {
  static Future<void> selection(BuildContext context) async {
    if (AppScope.of(context).hapticsEnabled) {
      try {
        await HapticFeedback.selectionClick();
      } on MissingPluginException {
        // Widget tests and unsupported platforms have no haptic channel.
      }
    }
  }

  static Future<void> light(BuildContext context) async {
    if (AppScope.of(context).hapticsEnabled) {
      try {
        await HapticFeedback.lightImpact();
      } on MissingPluginException {
        // Widget tests and unsupported platforms have no haptic channel.
      }
    }
  }

  static Future<void> success(BuildContext context) async {
    if (AppScope.of(context).hapticsEnabled) {
      try {
        await HapticFeedback.mediumImpact();
      } on MissingPluginException {
        // Widget tests and unsupported platforms have no haptic channel.
      }
    }
  }

  static Future<void> warning(BuildContext context) async {
    if (AppScope.of(context).hapticsEnabled) {
      try {
        await HapticFeedback.heavyImpact();
      } on MissingPluginException {
        // Widget tests and unsupported platforms have no haptic channel.
      }
    }
  }
}
