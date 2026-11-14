import 'dart:async';

import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../models/song.dart';
import '../services/haptics.dart';
import '../state/app_controller.dart';
import '../theme/app_adaptive.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';
import '../widgets/chuming_coach.dart';
import '../widgets/cute_illustrations.dart';
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
      final filterMatches =
          _filter == 'all' ||
          (_filter == 'easy' && song.level == 'easy') ||
          (_filter == 'advanced' && song.level == 'advanced');
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
                    GestureDetector(
                      onTap: () {
                        unawaited(AppHaptics.reedResonance(context));
                        unawaited(controller.reopenCoachTip('songs'));
                      },
                      child: const ChumingBird(
                        size: 36,
                        mood: ChumingMood.listening,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.strings.t('songsLibrary'),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontSize: 22),
                      ),
                    ),
                    IconButton.filled(
                      key: const Key('add-custom-song'),
                      tooltip: context.strings.t('addCustomSong'),
                      onPressed: _createSong,
                      icon: const Icon(Icons.add_rounded),
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
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'all',
                        label: Text(context.strings.t('all')),
                      ),
                      ButtonSegment(
                        value: 'easy',
                        label: Text(context.strings.t('easy')),
                      ),
                      ButtonSegment(
                        value: 'advanced',
                        label: Text(context.strings.t('advanced')),
                      ),
                    ],
                    selected: {_filter},
                    showSelectedIcon: false,
                    onSelectionChanged: (value) async {
                      setState(() => _filter = value.first);
                      await AppHaptics.selection(context);
                    },
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
                return _SongTile(
                  song: song,
                  iconId: controller.iconIdForSong(song),
                  onPickIcon: () => _pickSongIcon(song),
                  onTap: () {
                    unawaited(AppHaptics.selection(context));
                    Navigator.of(context).push(
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
  final _notationController = TextEditingController();
  var _titleValue = '';
  var _selectedHole = 4;
  var _selectedIconId = 'vinyl';
  String? _titleError;
  String? _notationError;

  @override
  void dispose() {
    _notationController.dispose();
    super.dispose();
  }

  void _updateNotation(String value) {
    _notationController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    setState(() => _notationError = null);
  }

  void _addNote(String direction) {
    final existing = _notationController.text.trim();
    final note = '$_selectedHole$direction';
    _updateNotation(existing.isEmpty ? note : '$existing $note');
    unawaited(AppHaptics.selection(context));
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
                hintText: '4↑ 4↑ 6↑ 6↑ 6↓ 6↓ 6↑',
                errorText: _notationError,
              ),
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
    required this.onTap,
    required this.onPickIcon,
    this.onDelete,
  });

  final Song song;
  final String iconId;
  final VoidCallback onTap;
  final VoidCallback onPickIcon;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final title = context.strings.songTitle(song.id, song.title);
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
                  padding: const EdgeInsets.all(16),
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
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                ),
                                if (song.isCustom)
                                  Pill(
                                    label: context.strings.t('custom'),
                                    color: palette.primary.withValues(
                                      alpha: 0.10,
                                    ),
                                    foreground: palette.primary,
                                  ),
                              ],
                            ),
                            if (song.isCustom) ...[
                              const SizedBox(height: 2),
                              Text(
                                context.strings.t('customSongSubtitle'),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                            const SizedBox(height: 6),
                            Text(
                              song.tabPreview,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.primary,
                                fontSize: 12,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (onDelete == null)
                        Icon(Icons.chevron_right_rounded, color: palette.muted),
                    ],
                  ),
                ),
              ),
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
            ),
        ],
      ),
    );
  }
}
