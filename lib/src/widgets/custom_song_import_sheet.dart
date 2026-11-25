import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../localization/app_strings.dart';
import '../models/score_import.dart';
import '../models/song.dart';
import '../services/haptics.dart';
import '../services/score_file_picker.dart';
import '../state/app_controller.dart';
import '../theme/app_theme.dart';
import 'cute_illustrations.dart';

/// 3 步式自定义曲谱导入与创建弹窗：
/// Step 1: 曲谱来源（文字/简谱输入 或 MIDI/MusicXML 本地文件导入）
/// Step 2: 自动最优移调 + 手动半音微调 + 压音预览与跳过开关
/// Step 3: 同音异孔校对（如 2↓ vs 3↑，默认最小手部移动推荐）+ 封面选择 + 保存
class CustomSongImportSheet extends StatefulWidget {
  const CustomSongImportSheet({
    required this.appController,
    this.filePicker = const ScoreFilePickerService(),
    super.key,
  });

  final AppController appController;
  final ScoreFilePickerService filePicker;

  @override
  State<CustomSongImportSheet> createState() => _CustomSongImportSheetState();
}

enum _ImportSourceTab { text, file }

class _CustomSongImportSheetState extends State<CustomSongImportSheet> {
  final _titleController = TextEditingController();
  final _notationController = TextEditingController();

  var _step = 0; // 0: Source, 1: Transpose/Bend, 2: Enharmonic check
  var _sourceTab = _ImportSourceTab.text;
  var _titleValue = '';
  var _selectedHole = 4;
  var _selectedIconId = 'vinyl';
  var _skipBendNotes = true;
  String? _titleError;
  String? _notationError;
  String? _fileError;
  String? _loadedFileName;
  ScoreImportPlan? _plan;

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

  Future<void> _pickScoreFile() async {
    unawaited(AppHaptics.selection(context));
    setState(() => _fileError = null);
    final picked = await widget.filePicker.pickScoreFile();
    if (!mounted || picked == null) return;
    try {
      final fallbackTitle = picked.name.replaceAll(
        RegExp(r'\.(mid|midi|xml|musicxml)$', caseSensitive: false),
        '',
      );
      final ParsedScoreSource source;
      if (picked.isMidi ||
          (picked.bytes.length >= 4 &&
              picked.bytes[0] == 0x4D &&
              picked.bytes[1] == 0x54 &&
              picked.bytes[2] == 0x68 &&
              picked.bytes[3] == 0x64)) {
        source = parseMidiBytes(picked.bytes, fallbackTitle: fallbackTitle);
      } else {
        final xml = utf8.decode(picked.bytes, allowMalformed: true);
        source = parseMusicXml(xml, fallbackTitle: fallbackTitle);
      }
      final plan = buildScoreImportPlan(
        sourceMidis: source.midis,
        harmonicaKey: widget.appController.harmonicaKey,
        sourceBeats: source.beats,
        suggestedTitle: source.title ?? fallbackTitle,
      );
      if (_titleValue.trim().isEmpty &&
          (plan.suggestedTitle?.trim().isNotEmpty ?? false)) {
        _updateTitle(plan.suggestedTitle!.trim());
      }
      unawaited(AppHaptics.success(context));
      setState(() {
        _loadedFileName = picked.name;
        _plan = plan;
        _step = 1;
      });
    } on HarmonicaTabFormatException catch (error) {
      unawaited(AppHaptics.warning(context));
      setState(() {
        _fileError = context.strings.t(error.code, {
          if (error.token != null) 'token': error.token!,
        });
      });
    }
  }

  void _advanceFromTextToStep2() {
    try {
      final source = parseTextOrJianpuSource(
        _notationController.text,
        harmonicaKey: widget.appController.harmonicaKey,
      );
      if (_titleValue.trim().isEmpty &&
          (source.title?.trim().isNotEmpty ?? false)) {
        _updateTitle(source.title!.trim());
      }
      final plan = buildScoreImportPlan(
        sourceMidis: source.midis,
        harmonicaKey: widget.appController.harmonicaKey,
        sourceBeats: source.beats,
        suggestedTitle: source.title,
      );
      unawaited(AppHaptics.selection(context));
      setState(() {
        _plan = plan;
        _step = 1;
      });
    } on HarmonicaTabFormatException catch (error) {
      unawaited(AppHaptics.warning(context));
      setState(() {
        _notationError = context.strings.t(error.code, {
          if (error.token != null) 'token': error.token!,
        });
      });
    }
  }

  void _adjustTranspose(int delta) {
    final current = _plan;
    if (current == null) return;
    final nextShift = (current.appliedTranspose + delta).clamp(-24, 24);
    unawaited(AppHaptics.selection(context));
    setState(() {
      _plan = buildScoreImportPlan(
        sourceMidis: current.sourceMidis,
        harmonicaKey: current.harmonicaKey,
        sourceBeats: current.items.map((item) => item.beats).toList(),
        transposeOverride: nextShift,
        suggestedTitle: current.suggestedTitle,
      );
    });
  }

  void _resetTranspose() {
    final current = _plan;
    if (current == null) return;
    unawaited(AppHaptics.selection(context));
    setState(() {
      _plan = buildScoreImportPlan(
        sourceMidis: current.sourceMidis,
        harmonicaKey: current.harmonicaKey,
        sourceBeats: current.items.map((item) => item.beats).toList(),
        suggestedTitle: current.suggestedTitle,
      );
    });
  }

  Future<void> _saveQuickText() async {
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

  Future<void> _saveFromPlan() async {
    final plan = _plan;
    if (plan == null) return;
    final title = _titleValue.trim().isNotEmpty
        ? _titleValue.trim()
        : (plan.suggestedTitle?.trim() ?? '');
    if (title.isEmpty) {
      setState(() {
        _step = 0;
        _titleError = context.strings.t('enterSongName');
      });
      return;
    }
    final created = await widget.appController.addCustomSongFromNotes(
      title: title,
      notes: plan.toPracticeNotes(),
      iconId: _selectedIconId,
      skipBendNotes: _skipBendNotes,
    );
    if (!mounted) return;
    Navigator.of(context).pop(created);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final palette = context.colors;

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
              strings.t('addCustomSong'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            // 3 步式进度导航条
            Row(
              key: const Key('import-step-bar'),
              children: [
                for (final (idx, keyName) in [
                  (0, 'importStep1'),
                  (1, 'importStep2'),
                  (2, 'importStep3'),
                ]) ...[
                  if (idx > 0) const SizedBox(width: 6),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: idx == 0 || _plan != null
                          ? () => setState(() => _step = idx)
                          : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _step == idx
                              ? palette.primary.withValues(alpha: 0.14)
                              : palette.surfaceHigh,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _step == idx
                                ? palette.primary
                                : palette.outline,
                          ),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            strings.t(keyName),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: _step == idx
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: _step == idx
                                  ? palette.primary
                                  : palette.muted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            if (_step == 0) _buildStep1Source(context),
            if (_step == 1 && _plan != null) _buildStep2Transpose(context),
            if (_step == 2 && _plan != null) _buildStep3Enharmonic(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1Source(BuildContext context) {
    final strings = context.strings;
    final palette = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<_ImportSourceTab>(
            key: const Key('import-source-switcher'),
            segments: [
              ButtonSegment(
                value: _ImportSourceTab.text,
                icon: const Icon(Icons.edit_note_rounded, size: 16),
                label: Text(strings.t('importSourceText')),
              ),
              ButtonSegment(
                value: _ImportSourceTab.file,
                icon: const Icon(Icons.upload_file_rounded, size: 16),
                label: Text(strings.t('importSourceFile')),
              ),
            ],
            selected: {_sourceTab},
            showSelectedIcon: false,
            onSelectionChanged: (selection) {
              setState(() => _sourceTab = selection.first);
              unawaited(AppHaptics.selection(context));
            },
          ),
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
            labelText: strings.t('songName'),
            hintText: strings.t('songNameHint'),
            errorText: _titleError,
          ),
        ),
        const SizedBox(height: 14),
        if (_sourceTab == _ImportSourceTab.file) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.surfaceHigh.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: palette.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  strings.t('importFileHint'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: palette.muted,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const Key('import-pick-file-btn'),
                  onPressed: _pickScoreFile,
                  icon: const Icon(Icons.folder_open_rounded),
                  label: Text(strings.t('importPickFileBtn')),
                ),
                if (_loadedFileName != null && _plan != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    strings.t('importFileLoaded', {
                      'name': _loadedFileName!,
                      'count': _plan!.items.length,
                    }),
                    key: const Key('import-file-loaded-badge'),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: palette.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (_fileError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _fileError!,
                    style: TextStyle(color: palette.danger, fontSize: 12.5),
                  ),
                ],
              ],
            ),
          ),
        ] else ...[
          Text(
            strings.t('chooseHole'),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var hole = 1; hole <= 10; hole++)
                Semantics(
                  label: strings.t('holeNumber', {'hole': hole}),
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
                  label: Text(strings.t('blow')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('custom-song-draw'),
                  onPressed: () => _addNote('↓'),
                  icon: const Icon(Icons.south_rounded),
                  label: Text(strings.t('draw')),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                key: const Key('custom-song-remove-note'),
                tooltip: strings.t('removeLastNote'),
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
              labelText: strings.t('numberNotation'),
              hintText: '4↑ 4↑ 6↑ 6↑ 6↓ 6↓ 6↑ / 1 1 5 5 6 6 5',
              errorText: _notationError,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            strings.t('jianpuQuickTitle'),
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
                label: Text(strings.t('jianpuConvertAction')),
                onPressed: () => _convertInputText(_notationController.text),
              ),
              ActionChip(
                key: const Key('paste-share-code-button'),
                avatar: const Icon(Icons.content_paste_rounded, size: 16),
                label: Text(strings.t('pasteShareCodeAction')),
                onPressed: _pasteShareCode,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildIconSelector(context),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('import-next-to-step2'),
                  onPressed: _advanceFromTextToStep2,
                  child: Text(strings.t('importStep2')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  key: const Key('save-custom-song'),
                  onPressed: _saveQuickText,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(strings.t('saveAndPractice')),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildStep2Transpose(BuildContext context) {
    final strings = context.strings;
    final palette = context.colors;
    final plan = _plan!;
    final shiftText = plan.appliedTranspose >= 0
        ? '+${plan.appliedTranspose}'
        : '${plan.appliedTranspose}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const Key('import-transpose-summary'),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.primary.withValues(alpha: 0.28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.t('importTransposeTitle'),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: palette.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                strings.t('importTransposeSummary', {
                  'key': plan.harmonicaKey,
                  'shift': shiftText,
                  'direct': plan.directCount,
                  'bend': plan.bendCount,
                }),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    key: const Key('import-transpose-minus'),
                    onPressed: () => _adjustTranspose(-1),
                    icon: const Icon(Icons.remove_rounded, size: 16),
                    label: const Text('-1'),
                  ),
                  Text(
                    shiftText,
                    key: const Key('import-transpose-value'),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: palette.primary,
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const Key('import-transpose-plus'),
                    onPressed: () => _adjustTranspose(1),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('+1'),
                  ),
                  if (plan.appliedTranspose != plan.recommendedTranspose)
                    TextButton(
                      key: const Key('import-transpose-reset'),
                      onPressed: _resetTranspose,
                      child: Text(strings.t('importTransposeReset')),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            _LegendDot(
              color: palette.success,
              label: strings.t('importDirectLegend'),
            ),
            _LegendDot(
              color: palette.warning,
              label: strings.t('importBendLegend'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          key: const Key('import-note-preview'),
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final item in plan.items.take(36))
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: (item.requiresBend ? palette.warning : palette.success)
                      .withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: item.requiresBend
                        ? palette.warning
                        : palette.success,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.selectedTab,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: palette.text,
                      ),
                    ),
                    Text(
                      item.noteLabel,
                      style: TextStyle(
                        fontSize: 10,
                        color: item.requiresBend
                            ? palette.warning
                            : palette.success,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          key: const Key('import-skip-bend-switch'),
          contentPadding: EdgeInsets.zero,
          title: Text(
            strings.t('importSkipBendSwitch'),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            strings.t('importSkipBendSub'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          value: _skipBendNotes,
          onChanged: (value) {
            setState(() => _skipBendNotes = value);
            unawaited(AppHaptics.selection(context));
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            OutlinedButton(
              key: const Key('import-back-btn'),
              onPressed: () => setState(() => _step = 0),
              child: Text(strings.t('importPrevStep')),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                key: const Key('import-skip-step3-save'),
                onPressed: _saveFromPlan,
                child: Text(strings.t('importSkipAndSave')),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                key: const Key('import-next-to-step3'),
                onPressed: () {
                  unawaited(AppHaptics.selection(context));
                  setState(() => _step = 2);
                },
                child: Text(strings.t('importNextStep')),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep3Enharmonic(BuildContext context) {
    final strings = context.strings;
    final palette = context.colors;
    final plan = _plan!;
    final ambiguous = plan.items
        .where((item) => item.hasEnharmonicChoice)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          strings.t('importEnharmonicTitle'),
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        if (ambiguous.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.success.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: palette.success.withValues(alpha: 0.35)),
            ),
            child: Text(
              strings.t('importEnharmonicNone'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: palette.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else ...[
          Text(
            strings.t('importEnharmonicSub'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: palette.muted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          for (final item in ambiguous.take(12))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: palette.surfaceHigh.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: palette.outline),
                ),
                child: Row(
                  children: [
                    Text(
                      '#${item.index + 1} · ${item.noteLabel}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final alt in item.alternatives)
                          ChoiceChip(
                            key: Key('enharmonic-choice-${item.index}-$alt'),
                            label: Text(alt),
                            selected: item.selectedTab == alt,
                            showCheckmark: false,
                            onSelected: (_) {
                              unawaited(AppHaptics.selection(context));
                              setState(() {
                                _plan = plan.withSelectedTab(item.index, alt);
                              });
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
        const SizedBox(height: 14),
        _buildIconSelector(context),
        const SizedBox(height: 16),
        Row(
          children: [
            OutlinedButton(
              onPressed: () => setState(() => _step = 1),
              child: Text(strings.t('importPrevStep')),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                key: const Key('import-final-save'),
                onPressed: _saveFromPlan,
                icon: const Icon(Icons.check_rounded),
                label: Text(strings.t('importSaveSong')),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIconSelector(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: color),
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
