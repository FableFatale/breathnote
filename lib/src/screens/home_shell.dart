import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../services/guide_tone_service.dart';
import '../services/haptics.dart';
import '../services/pitch_service.dart';
import '../theme/app_motion.dart';
import 'learn_screen.dart';
import 'profile_screen.dart';
import 'songs_screen.dart';
import 'tuner_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  int? _programmaticTarget;
  late final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _handlePageChanged(int value) {
    if (value == _index) return;
    final isProgrammatic = _programmaticTarget == value;
    if (isProgrammatic) _programmaticTarget = null;
    setState(() => _index = value);
    _stopAudio();
    if (!isProgrammatic) {
      unawaited(AppHaptics.selection(context));
    }
  }

  void _selectDestination(int value) {
    if (value == _index) return;
    _programmaticTarget = value;
    _stopAudio();
    unawaited(AppHaptics.selection(context));

    final shouldJump =
        AppMotion.isReduced(context) || (value - _index).abs() > 1;
    if (shouldJump) {
      _pageController.jumpToPage(value);
      return;
    }

    unawaited(
      _pageController.animateToPage(
        value,
        duration: AppMotion.base,
        curve: AppMotion.standardCurve,
      ),
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
    final screens = [
      const LearnScreen(),
      const SongsScreen(),
      TunerScreen(active: _index == 2),
      const ProfileScreen(),
    ];
    final scaffold = Scaffold(
      body: SafeArea(
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
                : const PageScrollPhysics(parent: ClampingScrollPhysics()),
            children: screens,
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _selectDestination,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home_rounded),
              label: context.strings.t('navLearn'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.library_music_outlined),
              selectedIcon: const Icon(Icons.library_music_rounded),
              label: context.strings.t('navSongs'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.speed_outlined),
              selectedIcon: const Icon(Icons.speed_rounded),
              label: context.strings.t('navTuner'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline_rounded),
              selectedIcon: const Icon(Icons.person_rounded),
              label: context.strings.t('navProfile'),
            ),
          ],
        ),
      ),
    );
    if (!kIsWeb) return scaffold;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= 760) return scaffold;
        return ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Center(child: SizedBox(width: 720, child: scaffold)),
        );
      },
    );
  }
}
