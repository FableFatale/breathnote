import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../theme/app_motion.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({this.initialSection = HelpSection.audio, super.key});

  final HelpSection initialSection;

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final _audioKey = GlobalKey();
  final _sensitivityKey = GlobalKey();
  final _chartsKey = GlobalKey();
  bool _scheduledInitialScroll = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scheduledInitialScroll) return;
    _scheduledInitialScroll = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = switch (widget.initialSection) {
        HelpSection.audio => _audioKey,
        HelpSection.sensitivity => _sensitivityKey,
        HelpSection.charts => _chartsKey,
      };
      final targetContext = target.currentContext;
      if (targetContext == null) return;
      Scrollable.ensureVisible(
        targetContext,
        duration: AppMotion.duration(context, AppMotion.fast),
        curve: AppMotion.standardCurve,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Scaffold(
      appBar: AppBar(title: Text(strings.t('help'))),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            _HelpSection(
              key: _audioKey,
              title: strings.t('helpAudioTitle'),
              body: strings.t('helpAudioBody'),
            ),
            const SizedBox(height: 24),
            _HelpSection(
              key: _sensitivityKey,
              title: strings.t('helpSensitivityTitle'),
              body: strings.t('helpSensitivityBody'),
            ),
            const SizedBox(height: 24),
            _HelpSection(
              key: _chartsKey,
              title: strings.t('helpChartsTitle'),
              body: strings.t('helpChartsBody'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpSection extends StatelessWidget {
  const _HelpSection({required this.title, required this.body, super.key});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Text(body, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

enum HelpSection { audio, sensitivity, charts }

Future<void> showHelpScreen(
  BuildContext context, {
  HelpSection section = HelpSection.audio,
}) {
  return Navigator.of(context).push(
    AppPageRoute<void>(
      reduceMotion: AppMotion.isReduced(context),
      builder: (_) => HelpScreen(initialSection: section),
    ),
  );
}
