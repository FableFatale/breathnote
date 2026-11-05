import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class SongsScreen extends StatefulWidget {
  const SongsScreen({super.key});

  @override
  State<SongsScreen> createState() => _SongsScreenState();
}

class _SongsScreenState extends State<SongsScreen> {
  final _controller = TextEditingController();
  String _filter = '全部';
  String _query = '';

  static const _songs = [
    _Song(
      title: '小星星',
      subtitle: '法国民谣 · 入门',
      notes: '4↑ 4↑ 6↑ 6↑ · 7↑ 7↑ 6↑',
      level: '简单',
      color: Color(0xFF344B66),
    ),
    _Song(
      title: '欢乐颂',
      subtitle: '贝多芬 · 入门',
      notes: '5↑ 5↑ 5↓ 6↑ · 6↑ 5↓ 5↑ 4↓',
      level: '简单',
      color: Color(0xFF57432F),
    ),
    _Song(
      title: '两只老虎',
      subtitle: '传统童谣 · 入门',
      notes: '4↑ 4↓ 5↑ 4↑ · 4↑ 4↓ 5↑ 4↑',
      level: '简单',
      color: Color(0xFF345045),
    ),
    _Song(
      title: '茉莉花',
      subtitle: '江苏民歌 · 进阶',
      notes: '5↑ 6↑ 5↓ 6↑ · 7↑ 6↑',
      level: '进阶',
      color: Color(0xFF4A3D5E),
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _songs.where((song) {
      final filterMatches = _filter == '全部' || song.level == _filter;
      final queryMatches = song.title.contains(_query);
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
                const SectionLabel('曲谱库'),
                const SizedBox(height: 6),
                Text(
                  '选一首，\n把旋律吹出来。',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 18),
                SearchBar(
                  controller: _controller,
                  hintText: '搜索曲目',
                  leading: const Icon(Icons.search_rounded),
                  trailing: _query.isEmpty
                      ? null
                      : [
                          IconButton(
                            onPressed: () {
                              _controller.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                  onChanged: (value) => setState(() => _query = value.trim()),
                  elevation: const WidgetStatePropertyAll(0),
                  backgroundColor: const WidgetStatePropertyAll(
                    AppColors.surface,
                  ),
                ),
                const SizedBox(height: 14),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: '全部', label: Text('全部')),
                    ButtonSegment(value: '简单', label: Text('简单')),
                    ButtonSegment(value: '进阶', label: Text('进阶')),
                  ],
                  selected: {_filter},
                  showSelectedIcon: false,
                  onSelectionChanged: (value) {
                    setState(() => _filter = value.first);
                  },
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ),
        if (visible.isEmpty)
          const SliverFillRemaining(
            child: EmptyState(
              icon: Icons.music_off_rounded,
              title: '没有找到匹配的曲目',
              detail: '试试更短的关键词，或切换难度。',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            sliver: SliverList.separated(
              itemCount: visible.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _SongTile(song: visible[index]),
            ),
          ),
      ],
    );
  }
}

class _SongTile extends StatelessWidget {
  const _SongTile({required this.song});

  final _Song song;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('${song.title} 练习将在音频版本开放')));
        },
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
                  color: AppColors.text,
                  size: 29,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      song.subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      song.notes,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _Song {
  const _Song({
    required this.title,
    required this.subtitle,
    required this.notes,
    required this.level,
    required this.color,
  });

  final String title;
  final String subtitle;
  final String notes;
  final String level;
  final Color color;
}
