import 'dart:async';

import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../models/song.dart';
import '../services/haptics.dart';
import '../state/app_controller.dart';
import '../theme/app_theme.dart';
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
    final appController = AppScope.of(context);
    unawaited(AppHaptics.selection(context));

    final titleController = TextEditingController();
    final notationController = TextEditingController();
    String? validationMessage;
    final song = await showModalBottomSheet<Song>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
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
                    const SizedBox(height: 8),
                    Text(
                      context.strings.t('customSongHelp'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('custom-song-title'),
                      controller: titleController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: context.strings.t('songName'),
                        hintText: context.strings.t('songNameHint'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('custom-song-notation'),
                      controller: notationController,
                      minLines: 3,
                      maxLines: 5,
                      decoration: InputDecoration(
                        labelText: context.strings.t('numberNotation'),
                        hintText: '4↑ 4↑ 6↑ 6↑ 6↓ 6↓ 6↑',
                      ),
                    ),
                    if (validationMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        validationMessage!,
                        style: TextStyle(color: context.colors.danger),
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const Key('save-custom-song'),
                        onPressed: () async {
                          final title = titleController.text.trim();
                          if (title.isEmpty) {
                            setSheetState(() {
                              validationMessage = context.strings.t(
                                'enterSongName',
                              );
                            });
                            return;
                          }
                          try {
                            final created = await appController.addCustomSong(
                              title: title,
                              notation: notationController.text,
                            );
                            if (!sheetContext.mounted) return;
                            Navigator.of(sheetContext).pop(created);
                          } on HarmonicaTabFormatException catch (error) {
                            unawaited(AppHaptics.warning(context));
                            setSheetState(() {
                              validationMessage = context.strings.t(
                                error.code,
                                {
                                  if (error.token != null)
                                    'token': error.token!,
                                },
                              );
                            });
                          }
                        },
                        icon: const Icon(Icons.add_rounded),
                        label: Text(context.strings.t('saveAndPractice')),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (song == null || !mounted) return;
    unawaited(AppHaptics.success(context));
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => SongPracticeScreen(song: song)),
    );
  }

  Future<void> _deleteSong(Song song) async {
    final confirmed = await showDialog<bool>(
      context: context,
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
    await AppScope.of(context).removeCustomSong(song.id);
    if (!mounted) return;
    await AppHaptics.warning(context);
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final palette = context.colors;
    final visible = controller.allSongs.where((song) {
      final filterMatches =
          _filter == 'all' ||
          (_filter == 'easy' && song.level == '简单') ||
          (_filter == 'advanced' && song.level == '进阶');
      final query = _query.toLowerCase();
      final localizedTitle = context.strings
          .songTitle(song.id, song.title)
          .toLowerCase();
      final localizedSubtitle = context.strings
          .songSubtitle(song.id, song.subtitle)
          .toLowerCase();
      final queryMatches =
          song.title.toLowerCase().contains(query) ||
          song.subtitle.toLowerCase().contains(query) ||
          localizedTitle.contains(query) ||
          localizedSubtitle.contains(query);
      return filterMatches && queryMatches;
    }).toList();

    return CustomScrollView(
      key: const PageStorageKey('songs'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SectionLabel(context.strings.t('songsLibrary')),
                    ),
                    IconButton.filled(
                      key: const Key('add-custom-song'),
                      tooltip: context.strings.t('addCustomSong'),
                      onPressed: _createSong,
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  context.strings.t('songsHero'),
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 18),
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
                const SizedBox(height: 14),
                SegmentedButton<String>(
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
                const SizedBox(height: 18),
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
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            sliver: SliverList.separated(
              itemCount: visible.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final song = visible[index];
                return _SongTile(
                  song: song,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
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

class _SongTile extends StatelessWidget {
  const _SongTile({required this.song, required this.onTap, this.onDelete});

  final Song song;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 68,
                decoration: BoxDecoration(
                  color: song.color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.music_note_rounded,
                  color: Colors.white,
                  size: 29,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.strings.songTitle(song.id, song.title),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (song.isCustom)
                          Pill(
                            label: context.strings.t('custom'),
                            color: palette.surfaceHigh,
                            foreground: palette.accentInk,
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      song.isCustom
                          ? context.strings.t('customSongSubtitle')
                          : context.strings.songSubtitle(
                              song.id,
                              song.subtitle,
                            ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
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
              if (onDelete != null)
                IconButton(
                  tooltip: context.strings.t('deleteSongTooltip', {
                    'title': song.title,
                  }),
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: palette.danger,
                  ),
                )
              else
                Icon(Icons.chevron_right_rounded, color: palette.muted),
            ],
          ),
        ),
      ),
    );
  }
}
