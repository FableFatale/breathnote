import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../services/guide_tone_service.dart';
import '../services/haptics.dart';
import '../services/pitch_service.dart';
import '../state/app_controller.dart';
import '../theme/app_motion.dart';
import '../widgets/chuming_launch_splash.dart';
import '../widgets/liquid_glass_tab_bar.dart';
import 'harmonica_registration_screen.dart';
import 'learn_screen.dart';
import 'profile_screen.dart';
import 'songs_screen.dart';
import 'tuner_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  int? _programmaticTarget;
  late final PageController _pageController = PageController();
  late final ValueNotifier<double> _pagePosition = ValueNotifier<double>(0);
  late final AnimationController _tabBounceController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: 1,
  );

  @override
  void initState() {
    super.initState();
    _pageController.addListener(_syncPagePosition);
  }

  @override
  void dispose() {
    _pageController.removeListener(_syncPagePosition);
    _pagePosition.dispose();
    _tabBounceController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _syncPagePosition() {
    if (!_pageController.hasClients) return;
    final page = _pageController.page;
    if (page != null && (_pagePosition.value - page).abs() > 0.0005) {
      _pagePosition.value = page;
    }
  }

  void _triggerNavBounce() {
    if (!AppMotion.isReduced(context)) {
      _tabBounceController.forward(from: 0);
    }
  }

  void _handlePageChanged(int value) {
    if (_programmaticTarget != null) {
      if (value == _programmaticTarget) {
        _programmaticTarget = null;
      }
      return;
    }
    if (value == _index) return;
    setState(() => _index = value);
    _triggerNavBounce();
    _stopAudio();
    unawaited(AppHaptics.selection(context));
  }

  void _selectDestination(int value, {bool emitHaptic = true}) {
    if (value == _index) {
      if (emitHaptic) {
        unawaited(AppHaptics.selection(context));
      }
      _triggerNavBounce();
      return;
    }
    final previousIndex = _index;
    _programmaticTarget = value;
    setState(() => _index = value);
    _stopAudio();
    if (emitHaptic) {
      unawaited(AppHaptics.selection(context));
    }
    _triggerNavBounce();

    final shouldJump =
        AppMotion.isReduced(context) || (value - previousIndex).abs() > 1;
    if (shouldJump) {
      _pageController.jumpToPage(value);
      _pagePosition.value = value.toDouble();
      _programmaticTarget = null;
      return;
    }

    unawaited(
      _pageController
          .animateToPage(
            value,
            duration: AppMotion.base,
            curve: AppMotion.standardCurve,
          )
          .whenComplete(() {
            if (_programmaticTarget == value) {
              _programmaticTarget = null;
            }
          }),
    );
  }

  void _stopAudio() {
    unawaited(PitchService().stop());
    unawaited(GuideToneService().stop());
  }

  bool _handleScrollStart(ScrollStartNotification notification) {
    if (notification.dragDetails != null &&
        notification.metrics.axis == Axis.horizontal) {
      _programmaticTarget = null;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final showRegistration =
        controller.isLoaded && !controller.hasRegisteredHarmonica;
    final screens = [
      const LearnScreen(),
      const SongsScreen(),
      TunerScreen(active: _index == 2 && !showRegistration),
      const ProfileScreen(),
    ];
    final Widget mainContent = showRegistration
        ? const HarmonicaRegistrationScreen()
        : Scaffold(
            extendBody: true,
            body: Stack(
              children: [
                SafeArea(
                  bottom: false,
                  child: NotificationListener<ScrollStartNotification>(
                    onNotification: _handleScrollStart,
                    child: PageView(
                      key: const Key('main-tab-page-view'),
                      controller: _pageController,
                      onPageChanged: _handlePageChanged,
                      pageSnapping: false,
                      physics: AppMotion.isReduced(context)
                          ? const ReducedMotionPageScrollPhysics(
                              parent: ClampingScrollPhysics(),
                            )
                          : const PageScrollPhysics(
                              parent: ClampingScrollPhysics(),
                            ),
                      children: screens,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: LiquidGlassBottomScrim(
                    pagePosition: _pagePosition,
                    retractFadeOnPageIndex: 2,
                  ),
                ),
              ],
            ),
            bottomNavigationBar: LiquidGlassTabBar(
              selectedIndex: _index,
              pagePosition: _pagePosition,
              bounceAnimation: _tabBounceController,
              onSelected: _selectDestination,
              items: [
                LiquidGlassTabItem(
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home_rounded,
                  label: context.strings.t('navLearn'),
                ),
                LiquidGlassTabItem(
                  icon: Icons.library_music_outlined,
                  selectedIcon: Icons.library_music_rounded,
                  label: context.strings.t('navSongs'),
                ),
                LiquidGlassTabItem(
                  icon: Icons.speed_outlined,
                  selectedIcon: Icons.speed_rounded,
                  label: context.strings.t('navTuner'),
                ),
                LiquidGlassTabItem(
                  icon: Icons.person_outline_rounded,
                  selectedIcon: Icons.person_rounded,
                  label: context.strings.t('navProfile'),
                ),
              ],
            ),
          );
    final wrappedScaffold = ChumingLaunchSplashOverlay(child: mainContent);
    if (!kIsWeb) return wrappedScaffold;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= 760) return wrappedScaffold;
        return ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Center(child: SizedBox(width: 720, child: wrappedScaffold)),
        );
      },
    );
  }
}
