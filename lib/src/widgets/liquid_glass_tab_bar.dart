import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/haptics.dart';
import '../state/app_controller.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';

/// Height of the floating Apple Liquid Glass capsule tab bar.
const double kFloatingNavBarHeight = 62;

/// Vertical lift between the floating capsule and the bottom safe area inset.
const double kFloatingNavBarBottomGap = 10;

/// Total bottom clearance required so content clears the floating Liquid Glass
/// capsule (plus system gesture inset and breathing room).
///
/// Inside [Scaffold] with `extendBody: true`, Flutter already sets
/// `MediaQuery.paddingOf(context).bottom` on the body to the measured height of
/// the floating bar (capsule + gap + system gesture inset). Taking the max
/// with the minimum bar height avoids both double-counting and under-padding.
double floatingNavBarClearance(BuildContext context, {double extra = 20}) {
  final mediaPaddingBottom = MediaQuery.paddingOf(context).bottom;
  final minBarHeight =
      kFloatingNavBarHeight +
      kFloatingNavBarBottomGap +
      MediaQuery.viewPaddingOf(context).bottom;
  return math.max(mediaPaddingBottom, minBarHeight) + extra;
}

@immutable
class LiquidGlassTabItem {
  const LiquidGlassTabItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Apple iOS 26-style Liquid Glass floating translucent capsule navigation bar
/// with real-time gliding frosted droplet indicator and direct horizontal
/// finger-scrubbing across tabs.
class LiquidGlassTabBar extends StatefulWidget {
  const LiquidGlassTabBar({
    required this.items,
    required this.selectedIndex,
    required this.pagePosition,
    required this.bounceAnimation,
    required this.onSelected,
    super.key,
  });

  final List<LiquidGlassTabItem> items;
  final int selectedIndex;
  final ValueListenable<double> pagePosition;
  final Animation<double> bounceAnimation;
  final void Function(int index, {bool emitHaptic}) onSelected;

  @override
  State<LiquidGlassTabBar> createState() => _LiquidGlassTabBarState();
}

class _LiquidGlassTabBarState extends State<LiquidGlassTabBar>
    with SingleTickerProviderStateMixin {
  static const double _innerPadding = 4;
  static const double _capsuleRadius = 32;
  static const double _pillRadius = 28;

  late final AnimationController _glideController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );

  double _glideFrom = 0;
  double _glideTo = 0;
  double _lastReportedPage = 0;

  bool _isScrubbing = false;
  double _scrubPosition = 0;
  int? _scrubHoveredIndex;

  @override
  void initState() {
    super.initState();
    _lastReportedPage = widget.pagePosition.value;
    _glideFrom = _lastReportedPage;
    _glideTo = _lastReportedPage;
    widget.pagePosition.addListener(_handlePagePositionChanged);
  }

  @override
  void didUpdateWidget(covariant LiquidGlassTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pagePosition != widget.pagePosition) {
      oldWidget.pagePosition.removeListener(_handlePagePositionChanged);
      _lastReportedPage = widget.pagePosition.value;
      widget.pagePosition.addListener(_handlePagePositionChanged);
    }
  }

  @override
  void dispose() {
    widget.pagePosition.removeListener(_handlePagePositionChanged);
    _glideController.dispose();
    super.dispose();
  }

  void _handlePagePositionChanged() {
    final next = widget.pagePosition.value;
    if (_isScrubbing) {
      _lastReportedPage = next;
      return;
    }

    final delta = (next - _lastReportedPage).abs();
    final visualNow = _currentPillPosition();
    _lastReportedPage = next;

    // Smoothly glide the glass droplet when jumping across non-adjacent tabs
    // via PageController.jumpToPage, while keeping 1:1 tracking for swipes
    // and adjacent page animations.
    if (delta > 0.65 && mounted && !AppMotion.isReduced(context)) {
      _glideFrom = visualNow;
      _glideTo = next;
      _glideController.duration = const Duration(milliseconds: 260);
      _glideController.forward(from: 0);
    } else if (_glideController.isAnimating) {
      _glideFrom = next;
      _glideTo = next;
      _glideController.value = 1;
    }
  }

  double _currentPillPosition() {
    final maxIndex = math.max(0, widget.items.length - 1).toDouble();
    if (_isScrubbing) {
      return _scrubPosition.clamp(0.0, maxIndex);
    }
    if (_glideController.isAnimating) {
      final t = Curves.easeOutCubic.transform(
        _glideController.value.clamp(0.0, 1.0),
      );
      return (_glideFrom + (_glideTo - _glideFrom) * t).clamp(0.0, maxIndex);
    }
    return widget.pagePosition.value.clamp(0.0, maxIndex);
  }

  void _startScrub(double localDx, double innerWidth) {
    if (innerWidth <= 0 || widget.items.isEmpty) return;
    _scrubHoveredIndex = widget.selectedIndex;
    _updateScrub(localDx, innerWidth, starting: true);
  }

  void _updateScrub(
    double localDx,
    double innerWidth, {
    bool starting = false,
  }) {
    if (innerWidth <= 0 || widget.items.isEmpty) return;
    final count = widget.items.length;
    final slotWidth = innerWidth / count;
    final pos = ((localDx - slotWidth / 2) / slotWidth).clamp(
      0.0,
      (count - 1).toDouble(),
    );
    final hovered = pos.round().clamp(0, count - 1);
    if (hovered != _scrubHoveredIndex) {
      _scrubHoveredIndex = hovered;
      unawaited(AppHaptics.selection(context));
    }
    if (starting || !_isScrubbing || (_scrubPosition - pos).abs() > 0.001) {
      setState(() {
        _isScrubbing = true;
        _scrubPosition = pos;
      });
    }
  }

  void _finishScrub({required bool commit}) {
    if (!_isScrubbing) return;
    final maxIndex = math.max(0, widget.items.length - 1);
    final target = commit
        ? (_scrubHoveredIndex ?? widget.selectedIndex).clamp(0, maxIndex)
        : widget.selectedIndex.clamp(0, maxIndex);
    final fromPos = _scrubPosition;

    setState(() {
      _isScrubbing = false;
      _scrubHoveredIndex = null;
    });

    if (!AppMotion.isReduced(context)) {
      _glideFrom = fromPos;
      _glideTo = target.toDouble();
      _glideController.duration = const Duration(milliseconds: 200);
      _glideController.forward(from: 0);
    }

    if (commit && target != widget.selectedIndex) {
      widget.onSelected(target, emitHaptic: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final highContrast = AppScope.maybeRead(context)?.highContrast ?? false;
    final reducedMotion = AppMotion.isReduced(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final horizontalMargin = screenWidth < 340 ? 12.0 : 20.0;

    final inactiveColor = highContrast
        ? palette.text.withValues(alpha: 0.78)
        : isDark
        ? const Color(0xFFB4B7C2)
        : const Color(0xFF5C606B);
    final activeColor = palette.primary;

    final glassTopColor = highContrast
        ? palette.surface.withValues(alpha: 0.96)
        : isDark
        ? const Color(0xFF33353D).withValues(alpha: 0.74)
        : Colors.white.withValues(alpha: 0.78);
    final glassMidColor = highContrast
        ? palette.surface.withValues(alpha: 0.96)
        : isDark
        ? const Color(0xFF23252A).withValues(alpha: 0.68)
        : const Color(0xFFF7FAFF).withValues(alpha: 0.66);
    final glassBottomColor = highContrast
        ? palette.surface.withValues(alpha: 0.96)
        : isDark
        ? const Color(0xFF1B1C20).withValues(alpha: 0.76)
        : const Color(0xFFEEF3FA).withValues(alpha: 0.74);

    final dropletTopColor = highContrast
        ? palette.primary.withValues(alpha: isDark ? 0.28 : 0.16)
        : isDark
        ? Color.alphaBlend(
            palette.primary.withValues(alpha: _isScrubbing ? 0.30 : 0.22),
            const Color(0xFF424652),
          ).withValues(alpha: 0.88)
        : Color.alphaBlend(
            palette.primary.withValues(alpha: _isScrubbing ? 0.16 : 0.11),
            Colors.white,
          ).withValues(alpha: 0.94);

    final dropletBottomColor = highContrast
        ? palette.primary.withValues(alpha: isDark ? 0.22 : 0.12)
        : isDark
        ? Color.alphaBlend(
            palette.primary.withValues(alpha: _isScrubbing ? 0.22 : 0.15),
            const Color(0xFF2C2F38),
          ).withValues(alpha: 0.80)
        : Color.alphaBlend(
            palette.primary.withValues(alpha: _isScrubbing ? 0.20 : 0.14),
            const Color(0xFFF3F7FF),
          ).withValues(alpha: 0.86);

    final capsuleShadows = isDark
        ? const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 28,
              spreadRadius: -2,
              offset: Offset(0, 10),
            ),
            BoxShadow(
              color: Color(0x3D000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ]
        : const [
            BoxShadow(
              color: Color(0x1A0F172A),
              blurRadius: 28,
              spreadRadius: -2,
              offset: Offset(0, 10),
            ),
            BoxShadow(
              color: Color(0x0D0F172A),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ];

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalMargin,
        0,
        horizontalMargin,
        kFloatingNavBarBottomGap + bottomInset,
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: DecoratedBox(
            key: const Key('floating-glass-tab-bar'),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_capsuleRadius),
              boxShadow: capsuleShadows,
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: highContrast ? 0.28 : 0.12)
                    : const Color(0xFF0F172A).withValues(
                        alpha: highContrast ? 0.22 : 0.08,
                      ),
                width: 0.8,
              ),
            ),
            child: SizedBox(
              height: kFloatingNavBarHeight,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_capsuleRadius),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(_capsuleRadius),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.45, 1.0],
                        colors: [
                          glassTopColor,
                          glassMidColor,
                          glassBottomColor,
                        ],
                      ),
                    ),
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(_innerPadding),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final innerWidth = constraints.maxWidth;
                              final innerHeight = constraints.maxHeight;
                              final count = widget.items.length;
                              final slotWidth = count > 0
                                  ? innerWidth / count
                                  : 0.0;

                              return GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onHorizontalDragStart: (details) => _startScrub(
                                  details.localPosition.dx,
                                  innerWidth,
                                ),
                                onHorizontalDragUpdate: (details) =>
                                    _updateScrub(
                                      details.localPosition.dx,
                                      innerWidth,
                                    ),
                                onHorizontalDragEnd: (_) =>
                                    _finishScrub(commit: true),
                                onHorizontalDragCancel: () =>
                                    _finishScrub(commit: false),
                                child: AnimatedBuilder(
                                  animation: Listenable.merge([
                                    widget.pagePosition,
                                    _glideController,
                                    widget.bounceAnimation,
                                  ]),
                                  builder: (context, _) {
                                    final pos = _currentPillPosition();
                                    final travelFraction = reducedMotion
                                        ? 0.0
                                        : (pos - pos.round()).abs() * 2.0;
                                    final liquidStretch = reducedMotion
                                        ? 0.0
                                        : (_isScrubbing ? 4.0 : 0.0) +
                                            travelFraction * 5.0;
                                    final pillWidth = math.min(
                                      innerWidth,
                                      slotWidth + liquidStretch,
                                    );
                                    final centerX = (pos + 0.5) * slotWidth;
                                    final pillLeft = (centerX - pillWidth / 2)
                                        .clamp(0.0, innerWidth - pillWidth);

                                    final bounceT = reducedMotion
                                        ? 1.0
                                        : Curves.easeOutBack.transform(
                                            widget.bounceAnimation.value.clamp(
                                              0.0,
                                              1.0,
                                            ),
                                          );
                                    final activeScale = 0.88 + 0.12 * bounceT;

                                    return Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Positioned(
                                          left: pillLeft,
                                          top: 0,
                                          width: pillWidth,
                                          height: innerHeight,
                                          child: IgnorePointer(
                                            child: DecoratedBox(
                                              key: const Key(
                                                'floating-glass-indicator',
                                              ),
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      _pillRadius,
                                                    ),
                                                gradient: LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: [
                                                    dropletTopColor,
                                                    dropletBottomColor,
                                                  ],
                                                ),
                                                border: Border.all(
                                                  color: isDark
                                                      ? Colors.white.withValues(
                                                          alpha: _isScrubbing
                                                              ? 0.28
                                                              : 0.18,
                                                        )
                                                      : Colors.white.withValues(
                                                          alpha: 0.96,
                                                        ),
                                                  width: 1,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: palette.primary
                                                        .withValues(
                                                          alpha: isDark
                                                              ? 0.20
                                                              : 0.12,
                                                        ),
                                                    blurRadius: _isScrubbing
                                                        ? 14
                                                        : 10,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withValues(
                                                          alpha: isDark
                                                              ? 0.24
                                                              : 0.05,
                                                        ),
                                                    blurRadius: 6,
                                                    offset: const Offset(0, 1),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            for (var i = 0; i < count; i++)
                                              Expanded(
                                                child: _GlassTabButton(
                                                  item: widget.items[i],
                                                  isSelected:
                                                      widget.selectedIndex == i,
                                                  selectionProgress:
                                                      (1.0 - (pos - i).abs())
                                                          .clamp(0.0, 1.0),
                                                  activeColor: activeColor,
                                                  inactiveColor: inactiveColor,
                                                  scale:
                                                      widget.selectedIndex == i
                                                      ? activeScale
                                                      : 1.0,
                                                  onTap: () => widget
                                                      .onSelected(
                                                        i,
                                                        emitHaptic: true,
                                                      ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _LiquidGlassRimPainter(
                                radius: _capsuleRadius,
                                isDark: isDark,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassTabButton extends StatelessWidget {
  const _GlassTabButton({
    required this.item,
    required this.isSelected,
    required this.selectionProgress,
    required this.activeColor,
    required this.inactiveColor,
    required this.scale,
    required this.onTap,
  });

  final LiquidGlassTabItem item;
  final bool isSelected;
  final double selectionProgress;
  final Color activeColor;
  final Color inactiveColor;
  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color.lerp(inactiveColor, activeColor, selectionProgress)!;
    final useSelectedIcon = selectionProgress >= 0.5;

    return Semantics(
      selected: isSelected,
      button: true,
      container: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Transform.scale(
                    scale: scale,
                    child: Icon(
                      useSelectedIcon ? item.selectedIcon : item.icon,
                      size: 22,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                    style: TextStyle(
                      color: color,
                      fontSize: 10.5,
                      height: 1.15,
                      fontWeight: useSelectedIcon
                          ? FontWeight.w700
                          : FontWeight.w500,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LiquidGlassRimPainter extends CustomPainter {
  const _LiquidGlassRimPainter({required this.radius, required this.isDark});

  final double radius;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(0.6),
      Radius.circular(radius),
    );
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0.0, 0.35, 1.0],
        colors: isDark
            ? [
                Colors.white.withValues(alpha: 0.28),
                Colors.white.withValues(alpha: 0.08),
                Colors.white.withValues(alpha: 0.12),
              ]
            : [
                Colors.white.withValues(alpha: 0.96),
                Colors.white.withValues(alpha: 0.40),
                const Color(0xFF94A3B8).withValues(alpha: 0.22),
              ],
      ).createShader(rect);
    canvas.drawRRect(rrect, rimPaint);
  }

  @override
  bool shouldRepaint(covariant _LiquidGlassRimPainter oldDelegate) {
    return oldDelegate.radius != radius || oldDelegate.isDark != isDark;
  }
}
