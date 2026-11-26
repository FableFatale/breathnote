import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../services/haptics.dart';
import '../theme/app_adaptive.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';

enum LegalDocumentType { privacyPolicy, termsOfService }

Future<void> showLegalDocumentScreen(
  BuildContext context, {
  LegalDocumentType initialTab = LegalDocumentType.privacyPolicy,
}) {
  return Navigator.of(context).push(
    AppPageRoute<void>(
      reduceMotion: AppMotion.isReduced(context),
      builder: (_) => LegalDocumentScreen(initialTab: initialTab),
    ),
  );
}

class LegalDocumentScreen extends StatefulWidget {
  const LegalDocumentScreen({
    this.initialTab = LegalDocumentType.privacyPolicy,
    super.key,
  });

  final LegalDocumentType initialTab;

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  late LegalDocumentType _selectedTab;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final palette = context.colors;
    final pagePadding = AppAdaptive.pagePadding(context);

    final sections = _selectedTab == LegalDocumentType.privacyPolicy
        ? [
            (strings.t('legalPrivacySec1Title'), strings.t('legalPrivacySec1Body')),
            (strings.t('legalPrivacySec2Title'), strings.t('legalPrivacySec2Body')),
            (strings.t('legalPrivacySec3Title'), strings.t('legalPrivacySec3Body')),
            (strings.t('legalPrivacySec4Title'), strings.t('legalPrivacySec4Body')),
            (strings.t('legalPrivacySec5Title'), strings.t('legalPrivacySec5Body')),
            (strings.t('legalPrivacySec6Title'), strings.t('legalPrivacySec6Body')),
          ]
        : [
            (strings.t('legalTermsSec1Title'), strings.t('legalTermsSec1Body')),
            (strings.t('legalTermsSec2Title'), strings.t('legalTermsSec2Body')),
            (strings.t('legalTermsSec3Title'), strings.t('legalTermsSec3Body')),
            (strings.t('legalTermsSec4Title'), strings.t('legalTermsSec4Body')),
            (strings.t('legalTermsSec5Title'), strings.t('legalTermsSec5Body')),
          ];

    return Scaffold(
      appBar: AppBar(title: Text(strings.t('legalPrivacyTermsTitle'))),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(pagePadding, 8, pagePadding, 32),
          children: [
            SegmentedButton<LegalDocumentType>(
              key: const Key('legal-document-segment'),
              segments: [
                ButtonSegment<LegalDocumentType>(
                  value: LegalDocumentType.privacyPolicy,
                  icon: const Icon(Icons.privacy_tip_outlined),
                  label: Text(strings.t('legalTabPrivacy')),
                ),
                ButtonSegment<LegalDocumentType>(
                  value: LegalDocumentType.termsOfService,
                  icon: const Icon(Icons.description_outlined),
                  label: Text(strings.t('legalTabTerms')),
                ),
              ],
              selected: {_selectedTab},
              showSelectedIcon: false,
              onSelectionChanged: (next) {
                setState(() => _selectedTab = next.first);
                AppHaptics.selection(context);
              },
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: palette.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: palette.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  strings.t('legalEffectiveDate'),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: palette.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < sections.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sections[i].$1,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        sections[i].$2,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.55,
                          color: palette.text,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
