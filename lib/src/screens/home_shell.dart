import 'dart:async';

import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../services/guide_tone_service.dart';
import '../services/haptics.dart';
import '../services/pitch_service.dart';
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

  @override
  Widget build(BuildContext context) {
    final screens = [
      const LearnScreen(),
      const SongsScreen(),
      TunerScreen(active: _index == 2),
      const ProfileScreen(),
    ];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _index, children: screens),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (value) {
            if (value == _index) return;
            setState(() => _index = value);
            unawaited(PitchService().stop());
            unawaited(GuideToneService().stop());
            unawaited(AppHaptics.selection(context));
          },
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
  }
}
