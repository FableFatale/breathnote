import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../localization/app_strings.dart';
import '../models/song.dart';
import '../services/haptics.dart';
import '../state/app_controller.dart';
import '../theme/app_adaptive.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';
import '../widgets/chuming_coach.dart';
import '../widgets/cute_illustrations.dart';
import '../widgets/harmonica_guide.dart' show showHarmonicaKeyPicker;
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
      builder: (_) => _CustomSongSheet(appController: appController),
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
          padding: EdgeInsets.fromLTRB(pagePadding, 20, pagePadding, 12),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    if (controller.seenCoachTips.contains('songs')) ...[
                      GestureDetector(
                        onTap: () {
                          unawaited(AppHaptics.reedResonance(context));
                          unawaited(controller.reopenCoachTip('songs'));
                        },
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: palette.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: palette.outline),
                          ),
                          alignment: Alignment.center,
                          child: const ChumingBird(
                            size: 28,
                            mood: ChumingMood.listening,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Text(
                        context.strings.t('songsLibrary'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontSize: 22),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      key: const Key('songs-key-chip'),
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => showHarmonicaKeyPicker(context),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 44),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: palette.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: palette.outline),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              context.strings.t('keyName', {
                                'key': controller.harmonicaKey,
                              }),
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: palette.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 16,
                              color: palette.muted,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    DecoratedBox(
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
                          minimumSize: const Size(44, 44),
                          fixedSize: const Size(44, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ),
                  ],
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
            child: EmptyState(
              icon: Icons.music_off_rounded,
              title: context.strings.t('noSongs'),
              detail: context.strings.t('noSongsDetail'),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pagePadding, 0, pagePadding, 28),
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
                  isFavorite: controller.isSongFavorite(song.id),
                  onPickIcon: () => _pickSongIcon(song),
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

class _CustomSongSheet extends StatefulWidget {
  const _CustomSongSheet({required this.appController});

  final AppController appController;

  @override
  State<_CustomSongSheet> createState() => _CustomSongSheetState();
}

class _CustomSongSheetState extends State<_CustomSongSheet> {
  final _titleController = TextEditingController();
  final _notationController = TextEditingController();
  var _titleValue = '';
  var _selectedHole = 4;
  var _selectedIconId = 'vinyl';
  String? _titleError;
  String? _notationError;

  @override
  void dispose() {
    _titleController.dispose();
    _notationController.dispose();
    super.dispose();
  }

  void _updateTitle(String value) {
    _titleValue = value;
    _titleController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    setState(() => _titleError = null);
  }

  void _updateNotation(String value) {
    _notationController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    setState(() => _notationError = null);
  }

  void _addTabToken(String tab) {
    final existing = _notationController.text.trim();
    _updateNotation(existing.isEmpty ? tab : '$existing $tab');
    unawaited(AppHaptics.selection(context));
  }

  void _addNote(String direction) {
    _addTabToken('$_selectedHole$direction');
  }

  void _convertInputText(String rawInput) {
    try {
      final parsed = parseSongShareOrJianpu(rawInput);
      if (parsed.title != null && _titleValue.trim().isEmpty) {
        _updateTitle(parsed.title!);
      }
      _updateNotation(parsed.tabs);
      unawaited(AppHaptics.success(context));
    } on HarmonicaTabFormatException catch (error) {
      unawaited(AppHaptics.warning(context));
      setState(() {
        _notationError = context.strings.t(error.code, {
          if (error.token != null) 'token': error.token!,
        });
      });
    }
  }

  Future<void> _pasteShareCode() async {
    final data = await Clipboard.getData('text/plain');
    if (!mounted) return;
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      setState(() {
        _notationError = context.strings.t('shareCodeEmptyClipboard');
      });
      return;
    }
    _convertInputText(text);
  }

  void _removeLastNote() {
    final notes = _notationController.text
        .trim()
        .split(RegExp(r'\s+'))
        .where((note) => note.isNotEmpty)
        .toList();
    if (notes.isEmpty) return;
    notes.removeLast();
    _updateNotation(notes.join(' '));
    unawaited(AppHaptics.selection(context));
  }

  Future<void> _save() async {
    final title = _titleValue.trim();
    if (title.isEmpty) {
      setState(() => _titleError = context.strings.t('enterSongName'));
      return;
    }
    try {
      final created = await widget.appController.addCustomSong(
        title: title,
        notation: _notationController.text,
        iconId: _selectedIconId,
      );
      if (!mounted) return;
      Navigator.of(context).pop(created);
    } on HarmonicaTabFormatException catch (error) {
      unawaited(AppHaptics.warning(context));
      setState(() {
        _notationError = context.strings.t(error.code, {
          if (error.token != null) 'token': error.token!,
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.strings.t('addCustomSong'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _titleController,
              key: const Key('custom-song-title'),
              textInputAction: TextInputAction.next,
              onChanged: (value) {
                _titleValue = value;
                if (_titleError != null) {
                  setState(() => _titleError = null);
                }
              },
              decoration: InputDecoration(
                labelText: context.strings.t('songName'),
                hintText: context.strings.t('songNameHint'),
                errorText: _titleError,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.strings.t('chooseHole'),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var hole = 1; hole <= 10; hole++)
                  Semantics(
                    label: context.strings.t('holeNumber', {'hole': hole}),
                    button: true,
                    selected: _selectedHole == hole,
                    child: ExcludeSemantics(
                      child: ChoiceChip(
                        key: Key('custom-song-hole-$hole'),
                        label: SizedBox(
                          width: 24,
                          child: Text('$hole', textAlign: TextAlign.center),
                        ),
                        selected: _selectedHole == hole,
                        onSelected: (_) {
                          setState(() => _selectedHole = hole);
                          unawaited(AppHaptics.selection(context));
                        },
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('custom-song-blow'),
                    onPressed: () => _addNote('↑'),
                    icon: const Icon(Icons.north_rounded),
                    label: Text(context.strings.t('blow')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('custom-song-draw'),
                    onPressed: () => _addNote('↓'),
                    icon: const Icon(Icons.south_rounded),
                    label: Text(context.strings.t('draw')),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  key: const Key('custom-song-remove-note'),
                  tooltip: context.strings.t('removeLastNote'),
                  onPressed: _notationController.text.trim().isEmpty
                      ? null
                      : _removeLastNote,
                  icon: const Icon(Icons.backspace_outlined),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notationController,
              key: const Key('custom-song-notation'),
              minLines: 2,
              maxLines: 4,
              onChanged: (_) {
                setState(() => _notationError = null);
              },
              decoration: InputDecoration(
                labelText: context.strings.t('numberNotation'),
                hintText: '4↑ 4↑ 6↑ 6↑ 6↓ 6↓ 6↑ / 1 1 5 5 6 6 5',
                errorText: _notationError,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              context.strings.t('jianpuQuickTitle'),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final item in jianpuQuickNotes)
                  ActionChip(
                    key: Key('jianpu-chip-${item.jianpu}'),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _addTabToken(item.tab),
                    label: Text(
                      '${item.jianpu} ${item.solfege} (${item.tab})',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ActionChip(
                  key: const Key('convert-jianpu-button'),
                  avatar: const Icon(Icons.auto_fix_high_rounded, size: 16),
                  label: Text(context.strings.t('jianpuConvertAction')),
                  onPressed: () => _convertInputText(_notationController.text),
                ),
                ActionChip(
                  key: const Key('paste-share-code-button'),
                  avatar: const Icon(Icons.content_paste_rounded, size: 16),
                  label: Text(context.strings.t('pasteShareCodeAction')),
                  onPressed: _pasteShareCode,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              context.strings.t('chooseSongIcon'),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: songIconPresets.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final preset = songIconPresets[index];
                  final selected = _selectedIconId == preset.id;
                  return SongArtworkBadge(
                    key: Key('custom-song-icon-${preset.id}'),
                    iconId: preset.id,
                    size: 46,
                    selected: selected,
                    onTap: () {
                      setState(() => _selectedIconId = preset.id);
                      unawaited(AppHaptics.selection(context));
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('save-custom-song'),
                onPressed: _save,
                icon: const Icon(Icons.add_rounded),
                label: Text(context.strings.t('saveAndPractice')),
              ),
            ),
          ],
        ),
      ),
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
    required this.isFavorite,
    required this.onTap,
    required this.onPickIcon,
    required this.onToggleFavorite,
    this.onDelete,
  });

  final Song song;
  final String iconId;
  final bool proLocked;
  final int bestStars;
  final int bestScore;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onPickIcon;
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
