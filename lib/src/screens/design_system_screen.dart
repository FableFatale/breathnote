import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/palermo_tokens.dart';
import '../widgets/cute_illustrations.dart';
import '../widgets/gesture_guide.dart';
import '../widgets/shared_widgets.dart';

/// Palermo × 初鸣 (Breathnote) 交互式设计规范与组件展示馆
/// 复刻自 https://palermo.tryprofound.com/docs/get-started
class DesignSystemScreen extends StatefulWidget {
  const DesignSystemScreen({super.key});

  @override
  State<DesignSystemScreen> createState() => _DesignSystemScreenState();
}

class _DesignSystemScreenState extends State<DesignSystemScreen> {
  int _selectedHole = 4;
  bool _isBlow = true;
  ChumingMood _selectedMood = ChumingMood.celebrating;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeTab = '$_selectedHole${_isBlow ? '↑' : '↓'}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Palermo × 初鸣设计系统'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Pill(
                        label: 'Palermo Design System v2.0',
                        color: PalermoTokens.blue(isDark).mutedFill,
                        foreground: PalermoTokens.blue(isDark).emphasis,
                      ),
                      Pill(
                        label: isDark ? 'Dark Mode' : 'Light Mode',
                        color: PalermoTokens.green(isDark).mutedFill,
                        foreground: PalermoTokens.green(isDark).emphasis,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Foundations & Breathnote Components',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '基于 palermo.tryprofound.com 规范提炼的纯净中性 Surface 层级、4 阶语义色板、现代几何无衬线排版及口琴专属交互组件。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const SectionLabel('1. SURFACE & NEUTRAL HIERARCHY (中性层级)'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _SurfaceSwatch(
                    name: 'background',
                    hex: isDark ? '#18181A' : '#FAFAFA',
                    color: palette.background,
                  ),
                  _SurfaceSwatch(
                    name: 'surface',
                    hex: isDark ? '#222224' : '#FFFFFF',
                    color: palette.surface,
                  ),
                  _SurfaceSwatch(
                    name: 'surfaceHigh',
                    hex: isDark ? '#2C2C30' : '#F5F5F5',
                    color: palette.surfaceHigh,
                  ),
                  _SurfaceSwatch(
                    name: 'outline',
                    hex: isDark ? '#323236' : '#EBEBEB',
                    color: palette.outline,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const SectionLabel('2. PALERMO 4-TIER SEMANTIC COLORS (四阶语义色)'),
          const SizedBox(height: 8),
          _SemanticFamilyCard(
            title: 'Palermo Blue · 吹气 (Blow ↑) & 主操作',
            colorSet: PalermoTokens.blue(isDark),
            hexLabel: isDark ? '#5E9EFF' : '#376CFF',
          ),
          const SizedBox(height: 10),
          _SemanticFamilyCard(
            title: 'Palermo Emerald · 音准锁定 (±10¢) & 完成态',
            colorSet: PalermoTokens.green(isDark),
            hexLabel: isDark ? '#60F178' : '#15B462',
          ),
          const SizedBox(height: 10),
          _SemanticFamilyCard(
            title: 'Palermo Orange · 吸气 (Draw ↓) & 连胜徽章',
            colorSet: PalermoTokens.orange(isDark),
            hexLabel: isDark ? '#FF8940' : '#FE6E00',
          ),
          const SizedBox(height: 10),
          _SemanticFamilyCard(
            title: 'Palermo Coral Red · 音准偏差过大警告',
            colorSet: PalermoTokens.red(isDark),
            hexLabel: isDark ? '#FF6369' : '#FF5F57',
          ),
          const SizedBox(height: 24),
          const SectionLabel('3. BRAND ICON & CHUMING MASCOT (品牌图标与小鸟)'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: palette.primary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: const HarmonicaBrandIcon(
                          size: 36,
                          color: Colors.white,
                          accentColor: Color(0xFF60F178),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '对称双护板口琴图标 (无角设计)',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '上下对称圆角金属护板 + 5 枚竖向音簧格栅 + 第 4 孔翡翠绿高亮。',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 28),
                  Row(
                    children: [
                      ChumingBird(
                        size: 64,
                        mood: _selectedMood,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '初鸣小鸟吉祥物 (点击切换 5 种情绪)',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: ChumingMood.values.map((mood) {
                                return ChoiceChip(
                                  label: Text(mood.name),
                                  selected: _selectedMood == mood,
                                  onSelected: (_) {
                                    setState(() => _selectedMood = mood);
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const SectionLabel('4. INTERACTIVE 10-HOLE DIAGRAM (十孔口琴组件)'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Pill(
                        label: '当前口谱: $activeTab',
                        color: _isBlow
                            ? PalermoTokens.blue(isDark).mutedFill
                            : PalermoTokens.orange(isDark).mutedFill,
                        foreground: _isBlow
                            ? PalermoTokens.blue(isDark).emphasis
                            : PalermoTokens.orange(isDark).emphasis,
                      ),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: true, label: Text('↑ 吹气')),
                          ButtonSegment(value: false, label: Text('↓ 吸气')),
                        ],
                        selected: {_isBlow},
                        showSelectedIcon: false,
                        onSelectionChanged: (v) {
                          setState(() => _isBlow = v.first);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  HarmonicaDiagram(activeTab: activeTab),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: List.generate(10, (index) {
                      final hole = index + 1;
                      return ChoiceChip(
                        label: Text('$hole孔'),
                        selected: _selectedHole == hole,
                        onSelected: (_) => setState(() => _selectedHole = hole),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const SectionLabel('5. REPLAYABLE GESTURE GUIDES (首次引导 + 点击重播)'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  const SwipeGestureGuide(
                    label: '左右滑动切换孔位 (点击可多次重播)',
                  ),
                  BreathGestureGuide(
                    isBlow: _isBlow,
                    label: _isBlow ? '平稳吹气引导 (点击重播)' : '轻柔吸气引导 (点击重播)',
                  ),
                  const CuteStreakBadge(
                    streakDays: 7,
                    label: '连续练习 7 天',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SurfaceSwatch extends StatelessWidget {
  const _SurfaceSwatch({
    required this.name,
    required this.hex,
    required this.color,
  });

  final String name;
  final String hex;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = context.colors;
    return Container(
      width: 140,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.outline),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: palette.outline),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  hex,
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: palette.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SemanticFamilyCard extends StatelessWidget {
  const _SemanticFamilyCard({
    required this.title,
    required this.colorSet,
    required this.hexLabel,
  });

  final String title;
  final PalermoSemanticFamily colorSet;
  final String hexLabel;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  hexLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: colorSet.emphasis,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _TierChip(
                  label: 'base',
                  bg: colorSet.base,
                  fg: Colors.white,
                ),
                const SizedBox(width: 6),
                _TierChip(
                  label: 'border',
                  bg: colorSet.border,
                  fg: const Color(0xFF18181A),
                ),
                const SizedBox(width: 6),
                _TierChip(
                  label: 'mutedFill',
                  bg: colorSet.mutedFill,
                  fg: colorSet.emphasis,
                  borderColor: colorSet.border,
                ),
                const SizedBox(width: 6),
                _TierChip(
                  label: 'emphasis',
                  bg: colorSet.emphasis,
                  fg: Colors.white,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TierChip extends StatelessWidget {
  const _TierChip({
    required this.label,
    required this.bg,
    required this.fg,
    this.borderColor,
  });

  final String label;
  final Color bg;
  final Color fg;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: borderColor != null ? Border.all(color: borderColor!) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }
}
