import 'package:flutter/material.dart';

abstract final class AppAdaptive {
  static const compactWidth = 360;
  static const veryCompactWidth = 320;
  static const largeTextScale = 1.3;

  static bool isCompact(BuildContext context) {
    final media = MediaQuery.maybeOf(context);
    if (media == null) return false;
    return media.size.width <= compactWidth ||
        media.textScaler.scale(1) >= largeTextScale;
  }

  static bool isVeryCompact(BuildContext context) {
    final media = MediaQuery.maybeOf(context);
    if (media == null) return false;
    return media.size.width <= veryCompactWidth ||
        media.textScaler.scale(1) >= 1.5;
  }

  static double pagePadding(BuildContext context) => isVeryCompact(context)
      ? 12
      : isCompact(context)
      ? 16
      : 20;

  static double cardPadding(BuildContext context) =>
      isCompact(context) ? 14 : 18;

  static double groupGap(BuildContext context) => isCompact(context) ? 20 : 32;

  static double relatedGap(BuildContext context) => isCompact(context) ? 8 : 12;

  static double compactValue(
    BuildContext context, {
    required double compact,
    required double regular,
  }) => isCompact(context) ? compact : regular;
}
