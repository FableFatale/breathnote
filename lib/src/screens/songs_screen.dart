import 'dart:async';

import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../models/song.dart';
import '../models/song_score.dart';
import '../services/haptics.dart';
import '../state/app_controller.dart';
import '../theme/app_adaptive.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';
import '../widgets/chuming_coach.dart';
import '../widgets/custom_song_import_sheet.dart';
import '../widgets/cute_illustrations.dart';
import '../widgets/harmonica_guide.dart' show showHarmonicaKeyPicker;
import '../widgets/liquid_glass_tab_bar.dart';
import '../widgets/pro_paywall_sheet.dart';
import '../widgets/shared_widgets.dart';
import 'song_practice_screen.dart';

class SongsScreen extends StatefulWidget {
  const SongsScreen({super.key});

  @override
  State<SongsScreen> createState() => _SongsScreenState();
}

class _SongsScreenState extends State<SongsScreen> {
  final _searchController = TextEditingController();
  String _filter = 'all';
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _createSong() async {
    final appController = AppScope.read(context);
    unawaited(AppHaptics.selection(context));
    if (!appController.isProUnlocked) {
      final unlocked = await showProPaywallSheet(context);
      if (!unlocked || !mounted) return;
    }

    final createdSong = await showModalBottomSheet<Song>(
      context: context,
      isScrollControlled: true,
      sheetAnimationStyle: AppMotion.sheetAnimationStyle(context),
      builder: (_) => CustomSongImportSheet(appController: appController),
    );
    if (createdSong == null || !mounted) return;
    unawaited(AppHaptics.success(context));
    Navigator.of(context).push(
      AppPageRoute<void>(
        reduceMotion: AppMotion.isReduced(context),
        builder: (_) => SongPracticeScreen(song: createdSong),
      ),
    );
  }

  Future<void> _deleteSong(Song song) async {
    final confirmed = await showDialog<bool>(
      context: context,
      animationStyle: AppMotion.animationStyle(context),
      builder: (context) => AlertDialog(
        title: Text(context.strings.t('deleteCustomSong')),
        content: Text(
          context.strings.t('deleteCustomSongBody', {'title': song.title}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.strings.t('commonCancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.strings.t('commonDelete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await AppScope.read(context).removeCustomSong(song.id);
    if (!mounted) return;
    await AppHaptics.warning(context);
  }

  Future<void> _pickSongIcon(Song song) async {
    final appController = AppScope.read(context);
    unawaited(AppHaptics.selection(context));
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      sheetAnimationStyle: AppMotion.sheetAnimationStyle(context),
      builder: (_) => _SongIconPickerSheet(
        song: song,
        appController: appController,
      ),
    );
  }

  Future<void> _showSongHistory(Song song) async {
    final appController = AppScope.read(context);
    unawaited(AppHaptics.selection(context));
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      sheetAnimationStyle: AppMotion.sheetAnimationStyle(context),
      builder: (_) => _SongScoreHistorySheet(
        song: song,
        attempts: appController.songHistoryFor(song.id),
        isProUnlocked: appController.isProUnlocked,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final palette = context.colors;
    final visible = controller.allSongs.where((song) {
      final filterMatches = switch (_filter) {
        'easy' => song.level == 'easy',
        'completed' => controller.isSongCompleted(song.id),
        'favorites' => controller.isSongFavorite(song.id),
        _ => true,
      };
      final query = _query.toLowerCase();
      final localizedTitle = context.strings
          .songTitle(song.id, song.title)
          .toLowerCase();
      final localizedSubtitle = context.strings.t(song.subtitle).toLowerCase();
      final queryMatches =
          song.title.toLowerCase().contains(query) ||
          song.subtitle.toLowerCase().contains(query) ||
          localizedTitle.contains(query) ||
          localizedSubtitle.contains(query);
      return filterMatches && queryMatches;
    }).toList();

    final pagePadding = AppAdaptive.pagePadding(context);

    return CustomScrollView(
      key: const PageStorageKey('songs'),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(pagePadding, 16, pagePadding, 12),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TabPageHeader(
                  title: context.strings.t('songsLibrary'),
                  harmonicaKey: controller.harmonicaKey,
                  keyPillKey: const Key('songs-key-chip'),
                  showCoachTrigger: controller.seenCoachTips.contains('songs'),
                  birdMood: ChumingMood.listening,
                  onReopenCoach: () {
                    unawaited(AppHaptics.reedResonance(context));
                    unawaited(controller.reopenCoachTip('songs'));
                  },
                  onChooseKey: () => showHarmonicaKeyPicker(context),
                  trailingAction: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF5B93FF),
                          palette.primary,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: palette.primary.withValues(alpha: 0.24),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: IconButton(
                      key: const Key('add-custom-song'),
                      tooltip: context.strings.t('addCustomSong'),
                      onPressed: _createSong,
                      style: IconButton.styleFrom(
                        foregroundColor: palette.onPrimary,
                        minimumSize: const Size(40, 40),
                        fixedSize: const Size(40, 40),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const ChumingCoachBanner(
                  featureId: 'songs',
                  messageKey: 'coachSongs',
                  mood: ChumingMood.listening,
                ),
                SearchBar(
                  controller: _searchController,
                  hintText: context.strings.t('searchSongs'),
                  leading: const Icon(Icons.search_rounded),
                  trailing: _query.isEmpty
                      ? null
                      : [
                          IconButton(
                            tooltip: context.strings.t('clearSearch'),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                  onChanged: (value) => setState(() => _query = value.trim()),
                  elevation: const WidgetStatePropertyAll(0),
                  backgroundColor: WidgetStatePropertyAll(palette.surface),
                  side: WidgetStatePropertyAll(
                    BorderSide(color: palette.outline),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final option in [
                        ('all', context.strings.t('all')),
                        ('easy', context.strings.t('easy')),
                        ('completed', context.strings.t('filterCompleted')),
                        ('favorites', context.strings.t('filterFavorites')),
                      ]) ...[
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            key: Key('songs-filter-${option.$1}'),
                            label: Text(option.$2),
                            selected: _filter == option.$1,
                            showCheckmark: false,
                            onSelected: (selected) {
                              if (!selected) return;
                              setState(() => _filter = option.$1);
                              unawaited(AppHaptics.selection(context));
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        if (visible.isEmpty)
          SliverFillRemaining(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: floatingNavBarClearance(context, extra: 12),
              ),
              child: EmptyState(
                icon: Icons.music_off_rounded,
                title: context.strings.t('noSongs'),
                detail: context.strings.t('noSongsDetail'),
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              pagePadding,
              0,
              pagePadding,
              floatingNavBarClearance(context, extra: 40),
            ),
            sliver: SliverList.separated(
              itemCount: visible.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final song = visible[index];
                final proLocked = song.isPro && !controller.isProUnlocked;
                return _SongTile(
                  song: song,
                  iconId: controller.iconIdForSong(song),
                  proLocked: proLocked,
                  bestStars: controller.bestStarsForSong(song.id),
                  bestScore: controller.bestScoreForSong(song.id),
                  attemptCount: controller.songHistoryFor(song.id).length,
                  isFavorite: controller.isSongFavorite(song.id),
                  onPickIcon: () => _pickSongIcon(song),
                  onShowHistory: () => _showSongHistory(song),
                  onToggleFavorite: () {
                    unawaited(AppHaptics.selection(context));
                    unawaited(controller.toggleFavoriteSong(song.id));
                  },
                  onTap: () async {
                    unawaited(AppHaptics.selection(context));
                    if (proLocked) {
                      final unlocked = await showProPaywallSheet(context);
                      if (!unlocked || !context.mounted) return;
                    }
                    if (!context.mounted) return;
                    await Navigator.of(context).push(
                      AppPageRoute<void>(
                        reduceMotion: AppMotion.isReduced(context),
                        builder: (_) => SongPracticeScreen(song: song),
                      ),
                    );
                  },
                  onDelete: song.isCustom ? () => _deleteSong(song) : null,
                );
              },
            ),
          ),
      ],
    );
  }
}


class _SongIconPickerSheet extends StatelessWidget {
  const _SongIconPickerSheet({
    required this.song,
    required this.appController,
  });

  final Song song;
  final AppController appController;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final title = context.strings.songTitle(song.id, song.title);
    final currentIconId = appController.iconIdForSong(song);
    final hasOverride = appController.hasSongIconOverride(song);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const ChumingBird(size: 32, mood: ChumingMood.idle),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.strings.t('changeSongIcon'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              context.strings.t('changeSongIconHint', {'title': title}),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: palette.muted,
                  ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 14,
              alignment: WrapAlignment.spaceBetween,
              children: [
                for (final preset in songIconPresets)
                  SizedBox(
                    width: 72,
                    child: InkWell(
                      key: Key('pick-song-icon-${preset.id}'),
                      borderRadius: BorderRadius.circular(14),
                      onTap: () async {
                        unawaited(AppHaptics.reedResonance(context));
                        await appController.setSongIcon(song.id, preset.id);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SongArtworkBadge(
                              iconId: preset.id,
                              size: 52,
                              selected: currentIconId == preset.id,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              context.strings.t(preset.labelKey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: currentIconId == preset.id
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                color: currentIconId == preset.id
                                    ? palette.primary
                                    : palette.text,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (hasOverride) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                key: const Key('reset-song-icon'),
                onPressed: () async {
                  unawaited(AppHaptics.selection(context));
                  await appController.setSongIcon(song.id, null);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                icon: const Icon(Icons.restore_rounded, size: 18),
                label: Text(context.strings.t('resetDefaultIcon')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SongTile extends StatelessWidget {
  const _SongTile({
    required this.song,
    required this.iconId,
    required this.proLocked,
    required this.bestStars,
    required this.bestScore,
    required this.attemptCount,
    required this.isFavorite,
    required this.onTap,
    required this.onPickIcon,
    required this.onShowHistory,
    required this.onToggleFavorite,
    this.onDelete,
  });

  final Song song;
  final String iconId;
  final bool proLocked;
  final int bestStars;
  final int bestScore;
  final int attemptCount;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onPickIcon;
  final VoidCallback onShowHistory;
  final VoidCallback onToggleFavorite;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final title = context.strings.songTitle(song.id, song.title);
    final played = bestStars > 0 || bestScore > 0;
    return Card(
      semanticContainer: false,
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: context.strings.t('openSong', {'title': title}),
              excludeSemantics: true,
              onTap: onTap,
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                  child: Row(
                    children: [
                      SongArtworkBadge(
                        key: Key('song-icon-${song.id}'),
                        iconId: iconId,
                        songId: song.id,
                        size: 52,
                        showEditBadge: true,
                        onTap: onPickIcon,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                ),
                                if (proLocked) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    key: Key('song-pro-badge-${song.id}'),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: palette.accent.withValues(
                                        alpha: 0.14,
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      context.strings.t('proBadge'),
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        color: palette.accent,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              context.strings.t(song.subtitle),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 7),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: palette.primary.withValues(
                                      alpha: 0.08,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    song.tabPreview,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: palette.primary,
                                      fontSize: 12,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (played)
                                  Row(
                                    key: Key('song-stars-${song.id}'),
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      for (var i = 0; i < 3; i++)
                                        Icon(
                                          i < bestStars
                                              ? Icons.star_rounded
                                              : Icons.star_outline_rounded,
                                          size: 14,
                                          color: i < bestStars
                                              ? const Color(0xFFF59E0B)
                                              : palette.outline,
                                        ),
                                      if (bestScore > 0) ...[
                                        const SizedBox(width: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: palette.primary.withValues(
                                              alpha: 0.12,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            gradeForSongScore(bestScore).label,
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w900,
                                              color: palette.primary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          context.strings.t('songBestBadge', {
                                            'score': bestScore,
                                          }),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: palette.muted,
                                          ),
                                        ),
                                      ],
                                    ],
                                  )
                                else
                                  Text(
                                    context.strings.t('songUnplayed'),
                                    key: Key('song-unplayed-${song.id}'),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: palette.muted,
                                    ),
                                  ),
                                if (attemptCount > 0)
                                  InkWell(
                                    key: Key('song-history-${song.id}'),
                                    borderRadius: BorderRadius.circular(999),
                                    onTap: onShowHistory,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: palette.surfaceHigh,
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(
                                          color: palette.outline,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.history_rounded,
                                            size: 12,
                                            color: palette.primary,
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            '${context.strings.t('scoreHistoryBtn')} ($attemptCount)',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                              color: palette.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            key: Key('song-favorite-${song.id}'),
            tooltip: context.strings.t(
              isFavorite ? 'favoriteSongRemove' : 'favoriteSongAdd',
            ),
            onPressed: onToggleFavorite,
            style: IconButton.styleFrom(
              minimumSize: const Size(44, 44),
            ),
            icon: Icon(
              isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              size: 20,
              color: isFavorite ? palette.accent : palette.muted,
            ),
          ),
          if (onDelete != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Semantics(
                button: true,
                label: context.strings.t('deleteSongTooltip', {
                  'title': song.title,
                }),
                excludeSemantics: true,
                onTap: onDelete,
                child: IconButton(
                  tooltip: context.strings.t('deleteSongTooltip', {
                    'title': song.title,
                  }),
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: palette.muted,
                  ),
                ),
              ),
            )
          else
            const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _SongScoreHistorySheet extends StatelessWidget {
  const _SongScoreHistorySheet({
    required this.song,
    required this.attempts,
    required this.isProUnlocked,
  });

  final Song song;
  final List<SongScoreAttempt> attempts;
  final bool isProUnlocked;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final strings = context.strings;
    final title = strings.songTitle(song.id, song.title);
    final sorted = [...attempts]
      ..sort((a, b) => b.timestampMs.compareTo(a.timestampMs));

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              strings.t('scoreHistoryTitle', {'title': title}),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 14),
            if (sorted.isEmpty)
              Text(
                strings.t('scoreHistoryEmpty'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: palette.muted,
                ),
              )
            else
              for (var i = 0; i < sorted.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: palette.surfaceHigh.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: palette.outline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: palette.primary.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              sorted[i].grade.label,
                              style: TextStyle(
                                color: palette.primary,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${sorted[i].totalScore}',
                            style: TextStyle(
                              color: palette.text,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          for (var s = 0; s < 3; s++)
                            Icon(
                              s < sorted[i].stars
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              size: 15,
                              color: s < sorted[i].stars
                                  ? const Color(0xFFF59E0B)
                                  : palette.outline,
                            ),
                          const Spacer(),
                          Text(
                            sorted[i].speed <= 0.6 ? '0.5×' : '1×',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: palette.muted,
                            ),
                          ),
                        ],
                      ),
                      if (isProUnlocked && sorted[i].mode == 'score') ...[
                        const SizedBox(height: 6),
                        Text(
                          '${strings.t('scoringDimPitch')} ${sorted[i].pitchScore} · '
                          '${strings.t('scoringDimTiming')} ${sorted[i].timingScore} · '
                          '${strings.t('scoringDimStability')} ${sorted[i].stabilityScore}',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: palette.muted),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
          ],
        ),
      ),
    );
  }
}
