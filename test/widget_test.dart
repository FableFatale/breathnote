import 'dart:async';
import 'dart:convert';

import 'package:breathnote/src/app.dart';
import 'package:breathnote/src/localization/app_strings.dart';
import 'package:breathnote/src/models/harmonica_layout.dart';
import 'package:breathnote/src/models/pitch_reading.dart';
import 'package:breathnote/src/models/practice_note.dart';
import 'package:breathnote/src/models/score_import.dart';
import 'package:breathnote/src/models/song.dart';
import 'package:breathnote/src/models/song_score.dart';
import 'package:breathnote/src/services/preferences_service.dart';
import 'package:breathnote/src/services/pitch_service.dart';
import 'package:breathnote/src/services/purchase_service.dart';
import 'package:breathnote/src/screens/lesson_routes.dart';
import 'package:breathnote/src/screens/song_practice_screen.dart';
import 'package:breathnote/src/screens/tuner_screen.dart';
import 'package:breathnote/src/state/app_controller.dart';
import 'package:breathnote/src/theme/app_motion.dart';
import 'package:breathnote/src/theme/app_theme.dart';
import 'package:breathnote/src/widgets/cute_illustrations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const preferencesChannel = MethodChannel('app.breathnote/preferences');

class _DelayedPreferencesService extends PreferencesService {
  _DelayedPreferencesService(this.values);

  final Completer<Map<String, Object?>> values;
  final Map<String, Object> savedValues = {};

  @override
  Future<Map<String, Object?>> getAll() => values.future;

  @override
  Future<void> setValue(String key, Object value) async {
    savedValues[key] = value;
  }
}

class _DelayedSavePreferencesService extends _DelayedPreferencesService {
  _DelayedSavePreferencesService()
    : super(Completer<Map<String, Object?>>()..complete(const {}));

  final Completer<void> saveGate = Completer<void>();

  @override
  Future<void> setValue(String key, Object value) async {
    await saveGate.future;
    await super.setValue(key, value);
  }
}

class AudioErrorHarness {
  const AudioErrorHarness(this.calls, this.emitError);

  final List<String> calls;
  final void Function() emitError;
}

AudioErrorHarness installAudioErrorHarness() {
  const audioChannel = MethodChannel('app.breathnote/audio_control');
  const pitchChannel = EventChannel('app.breathnote/pitch_events');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <String>[];
  MockStreamHandlerEventSink? eventSink;

  messenger.setMockMethodCallHandler(audioChannel, (call) async {
    calls.add(call.method);
    return switch (call.method) {
      'requestMicrophonePermission' => 'granted',
      'startPitchDetection' => true,
      'playGuideSequence' => 1000,
      _ => null,
    };
  });
  messenger.setMockStreamHandler(
    pitchChannel,
    MockStreamHandler.inline(
      onListen: (arguments, events) {
        eventSink = events;
      },
    ),
  );
  addTearDown(() {
    messenger.setMockMethodCallHandler(audioChannel, null);
    messenger.setMockStreamHandler(pitchChannel, null);
  });

  return AudioErrorHarness(calls, () {
    final sink = eventSink;
    if (sink == null) throw StateError('Pitch stream was not started.');
    sink.error(code: 'pitch_read_failed');
  });
}

class PitchCompletionHarness {
  const PitchCompletionHarness(this.emitPitch);

  final void Function(double frequency) emitPitch;
}

PitchCompletionHarness installPitchCompletionHarness() {
  const audioChannel = MethodChannel('app.breathnote/audio_control');
  const pitchChannel = EventChannel('app.breathnote/pitch_events');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  MockStreamHandlerEventSink? eventSink;

  messenger.setMockMethodCallHandler(audioChannel, (call) async {
    return switch (call.method) {
      'requestMicrophonePermission' => 'granted',
      'startPitchDetection' => true,
      'playGuideSequence' => 1000,
      _ => null,
    };
  });
  messenger.setMockStreamHandler(
    pitchChannel,
    MockStreamHandler.inline(
      onListen: (arguments, events) {
        eventSink = events;
      },
    ),
  );
  addTearDown(() {
    messenger.setMockMethodCallHandler(audioChannel, null);
    messenger.setMockStreamHandler(pitchChannel, null);
  });

  var timestampMicros = 0;
  return PitchCompletionHarness((frequency) {
    final sink = eventSink;
    if (sink == null) throw StateError('Pitch stream was not started.');
    timestampMicros += 250000;
    sink.success(<String, Object?>{
      'detected': true,
      'frequency': frequency,
      'note': 'F',
      'octave': 5,
      'cents': 0,
      'confidence': 1,
      'levelDb': -20,
      'timestampMicros': timestampMicros,
    });
  });
}

Future<void> pumpBreathnote(
  WidgetTester tester, {
  AppController? controller,
  Size size = const Size(412, 915),
  double systemTextScale = 1,
  bool sawHarmonicaGuide = true,
  bool hasRegisteredHarmonica = true,
  bool isProUnlocked = true,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = systemTextScale;
  final appController = controller ?? AppController();
  appController.sawHarmonicaGuide = sawHarmonicaGuide;
  appController.hasRegisteredHarmonica = hasRegisteredHarmonica;
  appController.isProUnlocked = isProUnlocked;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(BreathnoteApp(controller: appController));
  await tester.pumpAndSettle();
}

void main() {
  setUp(PitchService.resetForTesting);
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(preferencesChannel, (call) async {
          return switch (call.method) {
            'getAll' => <String, Object?>{},
            'setValue' => null,
            'clear' => null,
            _ => null,
          };
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(preferencesChannel, null);
  });

  test('uses the verified Figma motion timings', () {
    expect(AppMotion.fast, const Duration(milliseconds: 160));
    expect(AppMotion.base, const Duration(milliseconds: 240));
    expect(AppMotion.slow, const Duration(milliseconds: 420));
    expect(AppMotion.breathing, const Duration(milliseconds: 2400));
    expect(AppMotion.sheetCurve, const Cubic(0.32, 0.72, 0, 1));
  });

  test('parses valid custom harmonica notation', () {
    final notes = parseHarmonicaTabs('4↑ 4↓ | 5↑，6↓');

    expect(notes.map((note) => note.tab), ['4↑', '4↓', '5↑', '6↓']);
    expect(() => parseHarmonicaTabs('4 5↑'), throwsFormatException);
  });

  test('groups pitch attempts into seven-day note accuracy', () {
    final controller = AppController();
    addTearDown(controller.dispose);
    controller.pitchAttempts.addAll([
      PitchAttempt(tab: '4↑', absoluteCents: 8, timestamp: DateTime.now()),
      PitchAttempt(tab: '4↑', absoluteCents: 32, timestamp: DateTime.now()),
      PitchAttempt(tab: '4↓', absoluteCents: 4, timestamp: DateTime.now()),
    ]);

    final accuracy = controller.weakNoteAccuracy();
    expect(accuracy[3], 0.5);
    expect(accuracy[13], 1);
    expect(accuracy.whereType<double>(), hasLength(2));
  });

  test('repaints pitch dots when samples change at the same count', () {
    expect(shouldRepaintPitchSamples([1, 2], [1, 3]), isTrue);
    expect(shouldRepaintPitchSamples([1, 2], [1, 2]), isFalse);
  });

  test('uses the statistical median for an even sample count', () {
    expect(pitchSampleMedian([-8, 4]), -2);
    expect(pitchSampleMedian([-8, 0, 7]), 0);
  });

  test(
    'stores locale-independent song metadata and natural guide labels',
    () async {
      final controller = AppController();
      addTearDown(controller.dispose);
      final song = await controller.addCustomSong(
        title: 'Morning',
        notation: '4↑',
      );

      expect(song.level, 'custom');
      expect(song.subtitle, 'customSongSubtitle');
      expect(AppStrings('en').t(song.subtitle), 'Custom harmonica tabs');
      expect(AppStrings('en').t('stopDemo'), 'Stop melody');
      expect(AppStrings('ja').t('stopDemo'), 'メロディーを停止');
    },
  );

  test(
    'normalizes legacy local metadata to locale-independent values',
    () async {
      final preferences = _DelayedPreferencesService(
        Completer<Map<String, Object?>>()..complete(const {
          'displayName': AppController.legacyDefaultDisplayName,
          'customSongs': '[{"id":"legacy","title":"Legacy","subtitle":"自定义曲谱","level":"自定义","notes":[{"note":"C","octave":5,"tab":"4↑"}]}]',
        }),
      );
      final controller = AppController(preferences: preferences);
      addTearDown(controller.dispose);
      await controller.load();

      expect(controller.displayName, AppController.defaultDisplayName);
      expect(controller.customSongs.single.subtitle, 'customSongSubtitle');
      expect(controller.customSongs.single.level, 'custom');
    },
  );

  test('waits for custom-song storage before returning the song', () async {
    final preferences = _DelayedSavePreferencesService();
    final controller = AppController(preferences: preferences);
    addTearDown(controller.dispose);
    await controller.load();

    final pendingSong = controller.addCustomSong(
      title: 'Morning',
      notation: '4↑',
    );
    var returned = false;
    unawaited(
      pendingSong.then((_) {
        returned = true;
      }),
    );

    await Future<void>.delayed(Duration.zero);
    expect(returned, isFalse);

    preferences.saveGate.complete();
    final song = await pendingSong;
    expect(returned, isTrue);
    expect(song.title, 'Morning');
    expect(preferences.savedValues.containsKey('customSongs'), isTrue);
  });

  test('skips persisted custom songs with no notes', () async {
    final preferences = _DelayedPreferencesService(
      Completer<Map<String, Object?>>()..complete(const {
        'customSongs':
            '[{"id":"empty","title":"Empty","subtitle":"自定义曲谱","level":"自定义","notes":[]},'
            '{"id":"valid","title":"Valid","subtitle":"自定义曲谱","level":"自定义","notes":[{"note":"C","octave":5,"tab":"4↑"}]}]',
      }),
    );
    final controller = AppController(preferences: preferences);
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.customSongs.map((song) => song.id), ['valid']);
  });

  test('counts only complete practice minutes', () {
    final controller = AppController()..practiceSeconds = 59;
    addTearDown(controller.dispose);

    expect(controller.practiceMinutes, 0);
    controller.practiceSeconds = 60;
    expect(controller.practiceMinutes, 1);
  });

  testWidgets('opens all four main navigation destinations', (tester) async {
    await pumpBreathnote(tester);

    expect(find.byKey(const Key('main-tab-page-view')), findsOneWidget);
    expect(find.text('学习路径'), findsOneWidget);

    await tester.tap(find.text('曲谱'));
    await tester.pumpAndSettle();
    expect(find.byType(SearchBar), findsOneWidget);
    expect(find.text('小星星'), findsOneWidget);

    await tester.tap(find.text('调音'));
    await tester.pumpAndSettle();
    expect(find.text('检测灵敏度'), findsOneWidget);
    expect(find.text('开始调音'), findsOneWidget);

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    expect(find.text('口琴练习者'), findsOneWidget);
    expect(find.text('本机数据与隐私'), findsOneWidget);
  });

  testWidgets('main tabs track horizontal swipes and settle on a page', (
    tester,
  ) async {
    await pumpBreathnote(tester);

    final pages = find.byKey(const Key('main-tab-page-view'));
    await tester.drag(pages, const Offset(-330, 0));
    await tester.pumpAndSettle();

    expect(find.byType(SearchBar), findsOneWidget);
    expect(find.text('小星星'), findsOneWidget);

    await tester.fling(pages, const Offset(180, 0), 1400);
    await tester.pumpAndSettle();

    expect(find.text('学习路径'), findsOneWidget);
  });

  testWidgets('short slow tab swipes snap back', (tester) async {
    await pumpBreathnote(tester);

    final pages = find.byKey(const Key('main-tab-page-view'));
    await tester.timedDrag(
      pages,
      const Offset(-80, 0),
      const Duration(milliseconds: 600),
    );
    await tester.pumpAndSettle();

    expect(find.text('学习路径'), findsOneWidget);
    expect(find.byType(SearchBar), findsNothing);
  });

  testWidgets('short fast tab flicks move to the next page', (tester) async {
    await pumpBreathnote(tester);

    final pages = find.byKey(const Key('main-tab-page-view'));
    await tester.fling(pages, const Offset(-90, 0), 2400);
    await tester.pumpAndSettle();

    expect(find.byType(SearchBar), findsOneWidget);
    expect(find.text('小星星'), findsOneWidget);
  });

  testWidgets('far navigation taps emit one selection haptic', (tester) async {
    await pumpBreathnote(tester);

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final haptics = <Object?>[];
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        haptics.add(call.arguments);
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();

    expect(find.text('本机数据与隐私'), findsOneWidget);
    expect(
      haptics.where((value) => value == 'HapticFeedbackType.selectionClick'),
      hasLength(1),
    );
  });

  testWidgets('reduced motion keeps direct drag but removes fling momentum', (
    tester,
  ) async {
    final controller = AppController()..reduceMotion = true;
    addTearDown(controller.dispose);
    await pumpBreathnote(tester, controller: controller);

    final pages = find.byKey(const Key('main-tab-page-view'));
    final pageController = tester.widget<PageView>(pages).controller!;
    final gesture = await tester.startGesture(tester.getCenter(pages));
    await gesture.moveBy(const Offset(-20, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-60, 0));
    await tester.pump();

    expect(pageController.offset, greaterThan(0));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('学习路径'), findsOneWidget);

    await tester.fling(pages, const Offset(-80, 0), 2400);
    expect(pageController.page, lessThan(0.5));
    await tester.pumpAndSettle();
    expect(find.text('学习路径'), findsOneWidget);

    await tester.tap(find.text('曲谱'));
    await tester.pump();

    expect(find.byType(SearchBar), findsOneWidget);
    expect(find.text('小星星'), findsOneWidget);
  });

  testWidgets('opens lesson detail and single-note practice', (tester) async {
    await pumpBreathnote(tester);

    await tester.tap(find.text('认识你的口琴').first);
    await tester.pumpAndSettle();
    expect(find.text('10 孔布鲁斯口琴'), findsOneWidget);
    expect(find.text('完成本课'), findsOneWidget);

    await tester.ensureVisible(find.text('完成本课'));
    await tester.tap(find.text('完成本课'));
    await tester.pumpAndSettle();
    expect(find.text('完成本课'), findsNothing);
    expect(find.text('下一课'), findsOneWidget);

    await tester.tap(find.byKey(const Key('lesson-1-next')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('breath-pacer-card')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('breath-complete-btn')));
    await tester.tap(find.byKey(const Key('breath-complete-btn')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('breath-next-lesson')));
    await tester.tap(find.byKey(const Key('breath-next-lesson')));
    await tester.pumpAndSettle();
    expect(find.text('目标音'), findsOneWidget);
    expect(find.text('含住第 4 孔，轻轻吹气。'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('吹响第一个音').first);
    await tester.pumpAndSettle();
    expect(find.text('目标音'), findsOneWidget);
    expect(find.text('准备'), findsOneWidget);
    expect(find.text('单音'), findsOneWidget);
    expect(find.text('跟吹'), findsOneWidget);
    expect(find.byKey(const Key('practice-primary-control')), findsOneWidget);
    expect(find.text('循环'), findsOneWidget);
    expect(find.text('播放 C 的示范音'), findsOneWidget);
    expect(find.text('含住第 4 孔，轻轻吹气。'), findsOneWidget);
  });

  testWidgets('shows the next lesson and completed lesson count', (
    tester,
  ) async {
    final controller = AppController();
    addTearDown(controller.dispose);
    await pumpBreathnote(tester, controller: controller);

    expect(find.text('已完成 0/10 课'), findsOneWidget);
    await controller.markLessonComplete('lesson_1');
    await tester.pumpAndSettle();

    expect(find.text('已完成 1/10 课'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('featured-lesson')),
        matching: find.text('呼吸与吹吸'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('beginner guide leads from lesson 1 to first-note practice', (
    tester,
  ) async {
    final controller = AppController();
    addTearDown(controller.dispose);
    await pumpBreathnote(
      tester,
      controller: controller,
      sawHarmonicaGuide: false,
    );

    expect(find.byKey(const Key('featured-lesson')), findsOneWidget);
    await tester.tap(find.text('认识你的口琴').first);
    await tester.pumpAndSettle();
    expect(find.text('认识你的口琴'), findsWidgets);
    expect(find.text('第 1 步，共 3 步'), findsOneWidget);
    expect(find.text('继续'), findsOneWidget);

    expect(find.byKey(const Key('guide-harmonica-diagram')), findsOneWidget);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('guide-next')));
    await tester.pumpAndSettle();
    expect(find.text('第 2 步，共 3 步'), findsOneWidget);
    expect(find.byKey(const Key('guide-direction-blow')), findsOneWidget);
    await tester.tap(find.byKey(const Key('guide-direction-draw')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('guide-harmonica-diagram')),
        matching: find.byIcon(Icons.arrow_downward_rounded),
      ),
      findsWidgets,
    );
    await tester.tap(find.byKey(const Key('guide-next')));
    await tester.pumpAndSettle();
    expect(find.text('第 3 步，共 3 步'), findsOneWidget);
    expect(find.byKey(const Key('guide-key-action')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('guide-key-cover')),
        matching: find.text('C 调'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('guide-next')));
    await tester.pumpAndSettle();

    expect(find.text('10 孔布鲁斯口琴'), findsOneWidget);
    expect(find.byKey(const Key('lesson-1-next-hole')), findsOneWidget);
    await tester.tap(find.byKey(const Key('lesson-1-next-hole')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('完成本课'));
    await tester.tap(find.text('完成本课'));
    await tester.pumpAndSettle();
    expect(controller.completedLessons, contains('lesson_1'));
    await tester.tap(find.byKey(const Key('lesson-1-next')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('breath-pacer-card')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('breath-complete-btn')));
    await tester.tap(find.byKey(const Key('breath-complete-btn')));
    await tester.pumpAndSettle();
    expect(controller.completedLessons, contains('lesson_breath'));
    await tester.ensureVisible(find.byKey(const Key('breath-next-lesson')));
    await tester.tap(find.byKey(const Key('breath-next-lesson')));
    await tester.pumpAndSettle();
    expect(find.text('目标音'), findsOneWidget);
    expect(find.text('含住第 4 孔，轻轻吹气。'), findsOneWidget);
  });

  testWidgets('guide skip opens lesson 1 without completing it', (
    tester,
  ) async {
    final controller = AppController();
    addTearDown(controller.dispose);
    await pumpBreathnote(
      tester,
      controller: controller,
      sawHarmonicaGuide: false,
    );

    await tester.tap(find.byKey(const Key('featured-lesson')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('guide-skip')));
    await tester.pumpAndSettle();

    expect(find.text('10 孔布鲁斯口琴'), findsOneWidget);
    expect(find.text('完成本课'), findsOneWidget);
    expect(find.byKey(const Key('lesson-1-guide')), findsOneWidget);
    expect(controller.completedLessons, isNot(contains('lesson_1')));
  });

  testWidgets('guide key picker updates the visible key', (tester) async {
    final controller = AppController();
    addTearDown(controller.dispose);
    await pumpBreathnote(
      tester,
      controller: controller,
      sawHarmonicaGuide: false,
    );

    await tester.tap(find.byKey(const Key('featured-lesson')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('guide-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('guide-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('guide-key-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('harmonica-key-F')));
    await tester.pumpAndSettle();

    expect(controller.harmonicaKey, 'F');
    expect(
      find.descendant(
        of: find.byKey(const Key('guide-key-cover')),
        matching: find.text('F 调'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('keeps practice guidance tied to the guide action', (
    tester,
  ) async {
    await pumpBreathnote(tester);

    await tester.tap(find.text('吹响第一个音').first);
    await tester.pumpAndSettle();
    expect(find.text('播放 C 的示范音'), findsOneWidget);
    expect(find.text('含住第 4 孔，轻轻吹气。'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('清晰的单音').first);
    await tester.pumpAndSettle();
    expect(find.text('只含住第 5 孔，缩小嘴型，保持柔和、稳定的气流。'), findsOneWidget);
  });

  testWidgets('explains localized score and progress values', (tester) async {
    expect(AppStrings('zh').t('pitchScore', {'score': 91}), '音准得分：91 / 100');
    expect(
      AppStrings('en').t('pitchScore', {'score': 91}),
      'Pitch score: 91 / 100',
    );
    expect(AppStrings('ja').t('pitchScore', {'score': 91}), '音程スコア：91 / 100');
    expect(AppStrings('zh').t('songProgress', {'percent': 40}), '已完成 40%');
    expect(AppStrings('en').t('songProgress', {'percent': 40}), '40% complete');
    expect(AppStrings('ja').t('songProgress', {'percent': 40}), '40% 完了');
    expect(
      AppStrings('en').t('openLesson', {'title': 'Play your first note'}),
      'Play your first note',
    );
    expect(AppStrings('ja').t('lessonLabel', {'number': '02'}), '第 02 レッスン');
    expect(AppStrings('ja').songTitle('two_tigers', '两只老虎'), 'グーチョキパーでなにつくろう');
  });

  testWidgets('completed practice opens the next lesson', (tester) async {
    final harness = installPitchCompletionHarness();
    final controller = AppController();
    addTearDown(controller.dispose);
    await pumpBreathnote(tester, controller: controller);

    await tester.tap(find.text('吹响第一个音').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('practice-primary-control')));
    await tester.pump(const Duration(milliseconds: 80));

    harness.emitPitch(
      const PracticeNote(note: 'C', octave: 5, tab: '4↑').frequencyForKey('C'),
    );
    await tester.pump(const Duration(milliseconds: 20));
    harness.emitPitch(
      const PracticeNote(note: 'C', octave: 5, tab: '4↑').frequencyForKey('C'),
    );
    await tester.pump(const Duration(milliseconds: 520));
    harness.emitPitch(
      const PracticeNote(note: 'C', octave: 5, tab: '4↑').frequencyForKey('C'),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(controller.completedLessons, contains('lesson_2'));
    expect(find.text('下一课'), findsWidgets);

    await tester.tap(find.byKey(const Key('practice-primary-control')));
    await tester.pumpAndSettle();

    expect(find.text('清晰的单音'), findsWidgets);
    expect(find.text('只含住第 5 孔，缩小嘴型，保持柔和、稳定的气流。'), findsOneWidget);
  });

  testWidgets('opens built-in song practice', (tester) async {
    await pumpBreathnote(tester);

    await tester.tap(find.text('曲谱'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('小星星'));
    await tester.pumpAndSettle();

    expect(find.text('当前目标'), findsOneWidget);
    expect(find.text('开始曲谱练习'), findsOneWidget);
    expect(find.text('播放旋律'), findsOneWidget);
  });

  testWidgets('edits local nickname and harmonica key', (tester) async {
    final controller = AppController();
    addTearDown(controller.dispose);
    await pumpBreathnote(tester, controller: controller);

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('edit-profile-name')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('profile-name-field')), '小风');
    await tester.tap(find.byKey(const Key('save-profile-name')));
    await tester.pumpAndSettle();
    expect(find.text('小风'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('harmonica-key-setting')));
    await tester.tap(find.byKey(const Key('harmonica-key-setting')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('harmonica-key-G')));
    await tester.pumpAndSettle();
    expect(controller.harmonicaKey, 'G');
    expect(find.text('G 调'), findsOneWidget);
  });

  testWidgets('creates a custom song and opens practice', (tester) async {
    final controller = AppController();
    addTearDown(controller.dispose);
    await pumpBreathnote(tester, controller: controller);

    await tester.tap(find.text('曲谱'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-custom-song')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('custom-song-title')), '晨风');
    await tester.tap(find.byKey(const Key('custom-song-blow')));
    await tester.pump();
    final notationField = tester.widget<TextField>(
      find.byKey(const Key('custom-song-notation')),
    );
    expect(notationField.controller?.text, '4↑');
    await tester.tap(find.byKey(const Key('custom-song-remove-note')));
    await tester.pump();
    expect(notationField.controller?.text, isEmpty);
    await tester.tap(find.byKey(const Key('custom-song-blow')));
    await tester.tap(find.byKey(const Key('custom-song-draw')));
    await tester.tap(find.byKey(const Key('custom-song-hole-5')));
    await tester.tap(find.byKey(const Key('custom-song-blow')));
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('save-custom-song')));
    await tester.tap(find.byKey(const Key('save-custom-song')));
    await tester.pumpAndSettle();

    expect(controller.customSongs.single.title, '晨风');
    expect(controller.customSongs.single.tabPreview, '4↑ 4↓ 5↑');
    expect(find.text('晨风'), findsWidgets);
    expect(find.text('当前目标'), findsOneWidget);
  });

  testWidgets('keeps custom-song open and delete actions accessible', (
    tester,
  ) async {
    final controller = AppController();
    await controller.addCustomSong(title: '晨风', notation: '4↑ 4↓');
    addTearDown(controller.dispose);
    await pumpBreathnote(tester, controller: controller);

    await tester.tap(find.text('曲谱'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('练习「晨风」'), findsOneWidget);
    expect(find.bySemanticsLabel('删除 晨风'), findsOneWidget);
  });

  testWidgets('wraps a long English song title at 120% text', (tester) async {
    final controller = AppController()
      ..languageCode = 'en'
      ..textScale = 1.2;
    addTearDown(controller.dispose);
    await pumpBreathnote(
      tester,
      controller: controller,
      size: const Size(360, 800),
    );

    await tester.tap(find.text('Songs'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Twinkle, Twinkle, Little Star'));
    await tester.pumpAndSettle();

    final titleFinder = find.descendant(
      of: find.byType(AppBar),
      matching: find.text('Twinkle, Twinkle, Little Star'),
    );
    final title = tester.widget<Text>(titleFinder);
    expect(title.maxLines, 2);
    expect(title.overflow, TextOverflow.visible);
    expect(tester.takeException(), isNull);
  });

  for (final locale in [('en', 'Songs'), ('ja', '楽譜')]) {
    testWidgets('${locale.$1} custom-song sheet fits at 120% text', (
      tester,
    ) async {
      final controller = AppController()
        ..languageCode = locale.$1
        ..textScale = 1.2;
      addTearDown(controller.dispose);
      await pumpBreathnote(
        tester,
        controller: controller,
        size: const Size(360, 800),
      );

      await tester.tap(find.text(locale.$2));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add-custom-song')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('custom-song-blow')), findsOneWidget);
      expect(find.byKey(const Key('custom-song-draw')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('shows holes 1 through 10 without horizontal scrolling', (
    tester,
  ) async {
    final controller = AppController()..textScale = 1.2;
    addTearDown(controller.dispose);
    await pumpBreathnote(
      tester,
      controller: controller,
      size: const Size(360, 800),
    );

    await tester.tap(find.text('曲谱'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-custom-song')));
    await tester.pumpAndSettle();

    for (var hole = 1; hole <= 10; hole++) {
      final finder = find.byKey(Key('custom-song-hole-$hole'));
      expect(finder, findsOneWidget);
      final rect = tester.getRect(finder);
      expect(rect.left, greaterThanOrEqualTo(20));
      expect(rect.right, lessThanOrEqualTo(340));
    }
    expect(
      tester.getTopLeft(find.byKey(const Key('custom-song-hole-10'))).dy,
      greaterThan(
        tester.getTopLeft(find.byKey(const Key('custom-song-hole-1'))).dy,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('has no overflow on a small Android viewport', (tester) async {
    final controller = AppController()..textScale = 1.2;
    addTearDown(controller.dispose);
    await pumpBreathnote(
      tester,
      controller: controller,
      size: const Size(360, 800),
    );

    expect(tester.takeException(), isNull);

    await tester.tap(find.text('曲谱'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('调音'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    expect(find.text('声音只在设备上分析，不会上传或保存。'), findsNothing);
    expect(find.byKey(const Key('help-setting')), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.byKey(const Key('accessibility-setting')));
    await tester.tap(find.byKey(const Key('accessibility-setting')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('tuner fits the maximum supported effective text scale', (
    tester,
  ) async {
    final controller = AppController()..textScale = 1.2;
    addTearDown(controller.dispose);
    await pumpBreathnote(
      tester,
      controller: controller,
      size: const Size(360, 800),
      systemTextScale: 1.5,
    );

    await tester.tap(find.text('调音'));
    await tester.pumpAndSettle();

    expect(find.text('开始调音'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tuner keeps translated content inside a 360dp viewport', (
    tester,
  ) async {
    for (final locale in [('zh', '调音'), ('en', 'Tuner'), ('ja', 'チューナー')]) {
      final controller = AppController()
        ..languageCode = locale.$1
        ..textScale = 1.2;
      addTearDown(controller.dispose);
      await pumpBreathnote(
        tester,
        controller: controller,
        size: const Size(360, 800),
        systemTextScale: 1.5,
      );

      await tester.tap(find.text(locale.$2).first);
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });

  testWidgets('switches language across the whole app', (tester) async {
    final controller = AppController();
    addTearDown(controller.dispose);
    await pumpBreathnote(tester, controller: controller);

    expect(find.text('初鸣'), findsOneWidget);
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('appearance-language-setting')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(controller.languageCode, 'en');
    expect(find.text('Theme'), findsWidgets);
    expect(find.text('Me'), findsOneWidget);
    expect(find.text('Harmonica learner'), findsOneWidget);
    expect(find.text('口琴练习者'), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();
    expect(find.text('初鸣'), findsOneWidget);
    expect(find.text('Learning path'), findsOneWidget);
    expect(find.text('0/10 completed'), findsOneWidget);
    expect(find.text('Start with one breath'), findsNothing);
    expect(find.text('LEARNING PATH'), findsNothing);
    expect(find.text('TARGET NOTE'), findsNothing);
  });

  testWidgets('applies theme mode and shared microphone sensitivity', (
    tester,
  ) async {
    final controller = AppController()
      ..themeMode = ThemeMode.dark
      ..microphoneSensitivity = 0.82;
    addTearDown(controller.dispose);
    await pumpBreathnote(tester, controller: controller);

    final context = tester.element(find.byType(Scaffold).first);
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(context.colors.background, const Color(0xFF18181A));
    expect(context.colors.surface, const Color(0xFF222224));
    expect(context.colors.primary, const Color(0xFF6FA8FF));
    expect(context.colors.accent, const Color(0xFFF2B272));

    await tester.tap(find.text('调音'));
    await tester.pumpAndSettle();
    final sliderFinder = find.byKey(const Key('tuner-sensitivity-slider'));
    expect(sliderFinder, findsOneWidget);
    expect(tester.getSemantics(sliderFinder).value, '82%');
    expect(find.text('82%'), findsOneWidget);
  });

  testWidgets('loads and persists tuner sensitivity after first frame', (
    tester,
  ) async {
    final preferences = _DelayedPreferencesService(Completer());
    final controller = AppController(preferences: preferences);
    addTearDown(controller.dispose);
    await pumpBreathnote(tester, controller: controller);

    await tester.tap(find.text('调音'));
    await tester.pumpAndSettle();
    final sliderFinder = find.byKey(const Key('tuner-sensitivity-slider'));
    expect(sliderFinder, findsOneWidget);
    expect(tester.getSemantics(sliderFinder).value, '68%');

    preferences.values.complete({'microphoneSensitivity': 0.9});
    await tester.pumpAndSettle();
    expect(tester.getSemantics(sliderFinder).value, '90%');
    expect(find.text('90%'), findsOneWidget);

    await tester.ensureVisible(sliderFinder);
    await tester.pumpAndSettle();
    await tester.drag(sliderFinder, const Offset(-120, 0));
    await tester.pumpAndSettle();
    expect(preferences.savedValues['microphoneSensitivity'], isA<double>());
    expect(find.text('检测灵敏度'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
    expect(find.text('本机数据与隐私'), findsNothing);
  });

  testWidgets('uses native Japanese tuner wording', (tester) async {
    final controller = AppController()..languageCode = 'ja';
    addTearDown(controller.dispose);
    await pumpBreathnote(tester, controller: controller);

    await tester.tap(find.text('チューナー').first);
    await tester.pumpAndSettle();

    expect(find.text('チューナーを開始'), findsOneWidget);
    expect(find.text('検出感度'), findsOneWidget);
    expect(find.textContaining('調律'), findsNothing);
  });

  testWidgets('shows custom song metadata in the selected language', (
    tester,
  ) async {
    final controller = AppController()..languageCode = 'en';
    addTearDown(controller.dispose);
    await controller.addCustomSong(title: 'Morning', notation: '4↑');
    await pumpBreathnote(tester, controller: controller);

    await tester.tap(find.text('Songs'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SearchBar));
    await tester.enterText(find.byType(TextField), 'Morning');
    await tester.pumpAndSettle();

    expect(find.text('Morning'), findsWidgets);
    expect(find.text('Custom harmonica tabs'), findsOneWidget);
    expect(find.text('自定义曲谱'), findsNothing);
  });

  testWidgets('exposes clear lesson and song actions to accessibility', (
    tester,
  ) async {
    await pumpBreathnote(tester);

    expect(find.bySemanticsLabel('开始「认识你的口琴」'), findsOneWidget);
    await tester.tap(find.text('曲谱'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('练习「小星星」'), findsOneWidget);
  });

  testWidgets('does not repeat visible text inside semantic labels', (
    tester,
  ) async {
    await pumpBreathnote(tester);
    await tester.tap(find.text('调音'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('稳吹一个单音，这里会实时显示音准'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        RegExp('稳吹一个单音，这里会实时显示音准\\n稳吹一个单音，这里会实时显示音准'),
      ),
      findsNothing,
    );

    await tester.tap(find.text('学习'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('吹响第一个音').first);
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('1×'), findsOneWidget);
    expect(find.bySemanticsLabel('循环'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('1×\\n1×|循环\\n循环')), findsNothing);
  });

  testWidgets('keeps custom-song errors beside fields and clears them', (
    tester,
  ) async {
    await pumpBreathnote(tester);
    await tester.tap(find.text('曲谱'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-custom-song')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('save-custom-song')));
    await tester.tap(find.byKey(const Key('save-custom-song')));
    await tester.pump();
    expect(find.text('请输入曲名。'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('custom-song-title')), '晨风');
    await tester.pump();
    expect(find.text('请输入曲名。'), findsNothing);

    await tester.enterText(find.byKey(const Key('custom-song-notation')), '4');
    await tester.ensureVisible(find.byKey(const Key('save-custom-song')));
    await tester.tap(find.byKey(const Key('save-custom-song')));
    await tester.pump();
    expect(find.textContaining('无法识别'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('custom-song-notation')),
      '4↑ 4↓',
    );
    await tester.pump();
    expect(find.textContaining('无法识别'), findsNothing);
  });

  for (final locale in [('zh', '我的'), ('en', 'Me'), ('ja', 'マイページ')]) {
    testWidgets('${locale.$1} fits a compact Android screen at 120% text', (
      tester,
    ) async {
      final controller = AppController()
        ..languageCode = locale.$1
        ..textScale = 1.2;
      addTearDown(controller.dispose);
      await pumpBreathnote(
        tester,
        controller: controller,
        size: const Size(360, 800),
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.text(locale.$2));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('tuner shows only analytics backed by real samples', (
    tester,
  ) async {
    final controller = AppController();
    controller.pitchAttempts.add(
      PitchAttempt(tab: '4↑', absoluteCents: 30, timestamp: DateTime.now()),
    );
    addTearDown(controller.dispose);
    await pumpBreathnote(tester, controller: controller);

    await tester.tap(find.text('调音'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tuner-segmented-arc')), findsOneWidget);
    expect(find.byKey(const Key('tuner-session-distribution')), findsNothing);
    expect(find.byKey(const Key('tuner-weak-note-map')), findsOneWidget);
    expect(find.text('暂无数据'), findsNothing);
  });

  testWidgets('tuner reports when sampled notes have no weak areas', (
    tester,
  ) async {
    final controller = AppController();
    controller.pitchAttempts.add(
      PitchAttempt(tab: '4↑', absoluteCents: 8, timestamp: DateTime.now()),
    );
    addTearDown(controller.dispose);
    await pumpBreathnote(tester, controller: controller);

    await tester.tap(find.text('调音'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tuner-weak-note-map')), findsOneWidget);
    expect(find.text('没有需要复习的音'), findsOneWidget);
    expect(find.text('暂无数据'), findsNothing);
  });

  testWidgets('practice layout fits a small Android viewport', (tester) async {
    final controller = AppController()..textScale = 1.2;
    addTearDown(controller.dispose);
    await pumpBreathnote(
      tester,
      controller: controller,
      size: const Size(360, 800),
    );

    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -420),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('吹响第一个音').first);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('practice-primary-control')), findsOneWidget);
    expect(find.text('目标音'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('practice listening motion follows reduced-motion setting', (
    tester,
  ) async {
    const audioChannel = MethodChannel('app.breathnote/audio_control');
    const pitchChannel = MethodChannel('app.breathnote/pitch_events');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(audioChannel, (call) async {
      return switch (call.method) {
        'requestMicrophonePermission' => 'granted',
        'startPitchDetection' => true,
        _ => null,
      };
    });
    messenger.setMockMethodCallHandler(pitchChannel, (_) async => null);
    addTearDown(() {
      messenger.setMockMethodCallHandler(audioChannel, null);
      messenger.setMockMethodCallHandler(pitchChannel, null);
    });

    final preferences = _DelayedPreferencesService(
      Completer<Map<String, Object?>>()..complete(const {}),
    );
    final controller = AppController(preferences: preferences);
    addTearDown(controller.dispose);
    await pumpBreathnote(tester, controller: controller);
    await tester.tap(find.text('吹响第一个音').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('practice-primary-control')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.byKey(const Key('breathing-pulse-ring')), findsOneWidget);
    final stageProgress = find.byKey(const Key('practice-stage-progress'));
    expect(
      find.descendant(
        of: stageProgress,
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsNWidgets(2),
    );

    await controller.setReduceMotion(true);
    await tester.pump();

    expect(find.byKey(const Key('breathing-pulse-ring')), findsNothing);
    expect(
      tester
          .widget<AnimatedSwitcher>(
            find
                .descendant(
                  of: find.byKey(const Key('practice-primary-control')),
                  matching: find.byType(AnimatedSwitcher),
                )
                .first,
          )
          .duration,
      Duration.zero,
    );

    await tester.tap(find.byKey(const Key('practice-primary-control')));
    await tester.pump();
  });

  testWidgets('stops native audio when the practice pitch stream fails', (
    tester,
  ) async {
    final harness = installAudioErrorHarness();
    await pumpBreathnote(tester);
    await tester.tap(find.text('吹响第一个音').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('practice-primary-control')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('停止练习'), findsOneWidget);

    harness.emitError();
    await tester.pumpAndSettle();

    expect(harness.calls, contains('startPitchDetection'));
    expect(harness.calls, contains('stopPitchDetection'));
    expect(harness.calls, contains('stopGuideSequence'));
    expect(find.text('麦克风读取失败，请重试。'), findsOneWidget);
    expect(find.text('开始练习'), findsOneWidget);
    expect(find.byKey(const Key('breathing-pulse-ring')), findsNothing);
  });

  testWidgets('tuner input semantics use dBFS rather than a percentage', (
    tester,
  ) async {
    final controller = AppController()..microphoneSensitivity = 0.68;
    addTearDown(controller.dispose);
    await pumpBreathnote(tester, controller: controller);

    await tester.tap(find.text('调音'));
    await tester.pumpAndSettle();

    final semantics = tester.getSemantics(
      find.byKey(const Key('tuner-input-level')),
    );
    expect(semantics.label, contains('dBFS'));
    expect(semantics.label, isNot(contains('61%')));
  });

  testWidgets('shows localized unsupported audio message in Chinese', (
    tester,
  ) async {
    const audioChannel = MethodChannel('app.breathnote/audio_control');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(audioChannel, (call) async {
      throw MissingPluginException(
        'No implementation found for method ${call.method} on channel ${audioChannel.name}',
      );
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(audioChannel, null);
    });

    await pumpBreathnote(tester);
    await tester.tap(find.text('调音'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('开始调音'));
    await tester.pumpAndSettle();

    expect(find.text('当前设备暂不支持此功能'), findsOneWidget);
    expect(find.text('请使用 Android 应用。'), findsOneWidget);
    expect(find.text('帮助'), findsOneWidget);
    expect(find.text('重试'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows localized unsupported audio message in Japanese', (
    tester,
  ) async {
    const audioChannel = MethodChannel('app.breathnote/audio_control');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(audioChannel, (call) async {
      throw MissingPluginException(
        'No implementation found for method ${call.method} on channel ${audioChannel.name}',
      );
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(audioChannel, null);
    });

    final controller = AppController()..languageCode = 'ja';
    addTearDown(controller.dispose);
    await pumpBreathnote(tester, controller: controller);
    await tester.tap(find.text('チューナー').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('チューナーを開始'));
    await tester.pumpAndSettle();

    expect(find.text('この端末では利用できません'), findsOneWidget);
    expect(find.text('Android アプリをご利用ください。'), findsOneWidget);
    expect(find.text('ヘルプ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens help once from profile and keeps explanations there', (
    tester,
  ) async {
    await pumpBreathnote(tester);
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();

    expect(find.text('声音只在设备上分析，不会上传或保存。'), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('help-setting')));
    await tester.tap(find.byKey(const Key('help-setting')));
    await tester.pumpAndSettle();

    expect(find.text('帮助'), findsOneWidget);
    expect(find.textContaining('声音只在设备上实时分析'), findsOneWidget);
    expect(find.text('检测灵敏度'), findsWidgets);
    expect(find.text('图表'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens chart help from the tuner section icon', (tester) async {
    final controller = AppController();
    controller.pitchAttempts.add(
      PitchAttempt(tab: '4↑', absoluteCents: 32, timestamp: DateTime.now()),
    );
    addTearDown(controller.dispose);
    await pumpBreathnote(
      tester,
      controller: controller,
      size: const Size(360, 320),
    );
    await tester.tap(find.text('调音'));
    await tester.pumpAndSettle();

    final helpIcons = find.byIcon(Icons.info_outline_rounded);
    expect(helpIcons, findsWidgets);
    await tester.ensureVisible(helpIcons.last);
    await tester.tap(helpIcons.last);
    await tester.pumpAndSettle();

    expect(find.text('图表'), findsOneWidget);
    expect(find.textContaining('每个点代表一次采样'), findsOneWidget);
    final helpList = find.byType(ListView);
    final chartContext = tester.element(find.text('图表').last);
    expect(Scrollable.of(chartContext).position.pixels, greaterThan(0));

    await tester.drag(helpList, const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(Scrollable.of(chartContext).position.pixels, 0);

    await controller.setHighContrast(true);
    await tester.pumpAndSettle();
    expect(Scrollable.of(chartContext).position.pixels, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stops native audio when the song pitch stream fails', (
    tester,
  ) async {
    final harness = installAudioErrorHarness();
    await pumpBreathnote(tester);
    await tester.tap(find.text('曲谱'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('小星星'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('开始曲谱练习'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    harness.emitError();
    await tester.pumpAndSettle();

    expect(harness.calls, contains('startPitchDetection'));
    expect(harness.calls, contains('stopPitchDetection'));
    expect(find.text('麦克风读取失败，请重试。'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('stops native audio when the tuner pitch stream fails', (
    tester,
  ) async {
    final harness = installAudioErrorHarness();
    await pumpBreathnote(tester);
    await tester.tap(find.text('调音'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('开始调音'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    harness.emitError();
    await tester.pumpAndSettle();

    expect(harness.calls, contains('startPitchDetection'));
    expect(harness.calls, contains('stopPitchDetection'));
    expect(find.text('麦克风读取失败，请重试。'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });

  testWidgets('renders brand harmonica icon, mascot, and replayable gestures', (
    tester,
  ) async {
    await pumpBreathnote(tester);

    expect(find.byType(HarmonicaBrandIcon), findsNothing);
    expect(find.byType(ChumingBird), findsWidgets);

    await tester.tap(find.text('调音'));
    await tester.pumpAndSettle();
    expect(find.byType(HarmonicaBrandIcon), findsWidgets);

    await tester.tap(find.text('学习'));
    await tester.pumpAndSettle();

    // Open practice lesson and replay breath gesture guide
    await tester.tap(find.text('吹响第一个音').first);
    await tester.pumpAndSettle();

    final breathGuide = find.byKey(const Key('breath-gesture-guide'));
    expect(breathGuide, findsOneWidget);
    await tester.tap(breathGuide);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
  });

  testWidgets('assigns distinct default song icons and allows customization', (
    tester,
  ) async {
    final controller = AppController();
    addTearDown(controller.dispose);
    await pumpBreathnote(tester, controller: controller);

    expect(controller.iconIdForSong(songs[0]), 'star');
    expect(controller.iconIdForSong(songs[1]), 'sunburst');
    expect(controller.iconIdForSong(songs[2]), 'tiger');
    expect(controller.iconIdForSong(songs[3]), 'flower');

    await tester.tap(find.text('曲谱'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('song-icon-twinkle')), findsOneWidget);
    await tester.tap(find.byKey(const Key('song-icon-twinkle')));
    await tester.pumpAndSettle();

    expect(find.text('更换曲谱图标'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pick-song-icon-moon')));
    await tester.pumpAndSettle();

    expect(controller.iconIdForSong(songs[0]), 'moon');

    await tester.tap(find.byKey(const Key('song-icon-twinkle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reset-song-icon')));
    await tester.pumpAndSettle();

    expect(controller.iconIdForSong(songs[0]), 'star');
  });

  testWidgets('plays Chuming Bird launch splash transition on cold start', (
    tester,
  ) async {
    final controller = AppController()..sawHarmonicaGuide = true;
    addTearDown(controller.dispose);

    await tester.pumpWidget(BreathnoteApp(controller: controller));
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.byKey(const Key('chuming-launch-splash')), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chuming-launch-splash')), findsNothing);
  });

  test('folds subharmonic and overtone octaves for target note cents', () {
    const target = PracticeNote(note: 'C', octave: 5, tab: '4↑');
    final c5 = target.frequencyForKey('C'); // ~523.25 Hz
    final c4 = c5 / 2; // ~261.63 Hz (1 octave below)
    final c3 = c5 / 4; // ~130.81 Hz (2 octaves below)
    final c6 = c5 * 2; // ~1046.50 Hz (1 octave above)

    expect(target.centsFromFrequency(c5, 'C'), closeTo(0, 0.01));
    expect(target.centsFromFrequency(c4, 'C'), closeTo(0, 0.01));
    expect(target.centsFromFrequency(c3, 'C'), closeTo(0, 0.01));
    expect(target.centsFromFrequency(c6, 'C'), closeTo(0, 0.01));

    // Wrong note (D4) still reports ~+200 cents error
    final d4 = c4 * 1.122462;
    expect(target.centsFromFrequency(d4, 'C'), closeTo(200, 1.0));
  });

  testWidgets(
    'completes lesson 1, transitions to lesson 2, and pops while listening without assertion error',
    (tester) async {
      final harness = installPitchCompletionHarness();
      final controller = AppController()..harmonicaKey = 'C';
      addTearDown(controller.dispose);
      await pumpBreathnote(tester, controller: controller);

      await tester.tap(find.text('认识你的口琴').first);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('完成本课'));
      await tester.tap(find.text('完成本课'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('lesson-1-next')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('breath-complete-btn')));
      await tester.tap(find.byKey(const Key('breath-complete-btn')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('breath-next-lesson')));
      await tester.tap(find.byKey(const Key('breath-next-lesson')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('practice-hold-bar')), findsOneWidget);
      await tester.tap(find.byKey(const Key('practice-primary-control')));
      await tester.pump(const Duration(milliseconds: 80));

      // Emit a C4 subharmonic reading while listening, then immediately pop back to LearnScreen
      final c4Freq =
          const PracticeNote(
            note: 'C',
            octave: 5,
            tab: '4↑',
          ).frequencyForKey('C') /
          2;
      harness.emitPitch(c4Freq);
      await tester.pump(const Duration(milliseconds: 40));

      await tester.tap(find.byIcon(Icons.arrow_back).first);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('学习路径'), findsOneWidget);
      expect(find.text('已完成 2/10 课'), findsOneWidget);
      expect(find.text('吹响第一个音'), findsOneWidget);
    },
  );

  testWidgets(
    'avoids duplicate lesson cards and duplicate coach birds on Learn and Songs tabs',
    (tester) async {
      final controller = AppController();
      addTearDown(controller.dispose);
      await pumpBreathnote(tester, controller: controller);

      // Active lesson title appears only once on LearnScreen (no duplicate hero card)
      expect(find.text('认识你的口琴'), findsOneWidget);
      expect(find.byType(ChumingBird), findsOneWidget);

      await controller.markLessonComplete('lesson_1');
      await tester.pumpAndSettle();

      expect(find.text('吹响第一个音'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Songs tab renders only one ChumingBird when coach banner is visible or dismissed
      await tester.tap(find.text('曲谱'));
      await tester.pumpAndSettle();
      expect(find.byType(ChumingBird), findsOneWidget);

      await tester.tap(find.byKey(const Key('coach-dismiss-songs')));
      await tester.pumpAndSettle();
      expect(find.byType(ChumingBird), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'converts Jianpu 1-7 and share codes into harmonica tabs and provides 8 built-in songs',
    () {
      expect(songs, hasLength(8));
      expect(songs.any((s) => s.id == 'sky_castle'), isFalse);
      expect(songs.any((s) => s.id == 'always_with_me'), isFalse);
      expect(defaultIconIdForSong('amazing_grace'), 'moon');
      expect(defaultIconIdForSong('happy_birthday'), 'campfire');
      expect(defaultIconIdForSong('auld_lang_syne'), 'wave');
      expect(defaultIconIdForSong('first_breeze'), 'vinyl');
      final jasmine = songs.firstWhere((s) => s.id == 'jasmine');
      expect(
        jasmine.notes.map((n) => n.tab),
        ['5↑', '5↑', '6↑', '6↓', '7↑', '7↑', '6↓', '6↑'],
      );

      expect(
        convertJianpuToTabs('1 1 5 5 6 6 5'),
        '4↑ 4↑ 6↑ 6↑ 6↓ 6↓ 6↑',
      );
      expect(convertJianpuToTabs("6 7 1' 7 1' 3' 7"), '6↓ 7↓ 7↑ 7↓ 7↑ 8↑ 7↓');

      final code = formatSongShareCode(title: '小星星', tabs: '4↑ 4↑ 6↑');
      expect(code, '【初鸣曲谱】小星星｜4↑ 4↑ 6↑');

      final parsed = parseSongShareOrJianpu('【初鸣曲谱】生日歌｜5 5 6 5 1\' 7');
      expect(parsed.title, '生日歌');
      expect(parsed.tabs, '6↑ 6↑ 6↓ 6↑ 7↑ 7↓');
    },
  );

  testWidgets(
    'supports Jianpu quick-tap chips, share-code conversion, and 10-hole checkup in Tuner',
    (tester) async {
      final controller = AppController();
      addTearDown(controller.dispose);
      await pumpBreathnote(tester, controller: controller);

      await tester.tap(find.text('曲谱'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add-custom-song')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('jianpu-chip-1')));
      await tester.tap(find.byKey(const Key('jianpu-chip-1')));
      await tester.tap(find.byKey(const Key('jianpu-chip-5')));
      await tester.pump();

      final notationField = tester.widget<TextField>(
        find.byKey(const Key('custom-song-notation')),
      );
      expect(notationField.controller?.text, '4↑ 6↑');

      await tester.enterText(
        find.byKey(const Key('custom-song-notation')),
        '【初鸣曲谱】晴天｜1 2 3 5',
      );
      await tester.ensureVisible(
        find.byKey(const Key('convert-jianpu-button')),
      );
      await tester.tap(find.byKey(const Key('convert-jianpu-button')));
      await tester.pump();

      expect(notationField.controller?.text, '4↑ 4↓ 5↑ 6↑');
      final titleField = tester.widget<TextField>(
        find.byKey(const Key('custom-song-title')),
      );
      expect(titleField.controller?.text, '晴天');

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      await tester.tap(find.text('调音'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tuner-hole-checkup')), findsOneWidget);
      expect(find.text('已点亮 0/10 孔'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('checkup-hole-4')));
      await tester.tap(find.byKey(const Key('checkup-hole-4')));
      await tester.pumpAndSettle();
      expect(find.text('已点亮 1/10 孔'), findsOneWidget);

      await tester.tap(find.byKey(const Key('reset-hole-checkup')));
      await tester.pumpAndSettle();
      expect(find.text('已点亮 0/10 孔'), findsOneWidget);
    },
  );

  test('detects harmonica key from hole 4 blow frequency across keys', () {
    final cResult = detectHarmonicaKeyFromHole4Blow(523.25); // C5
    expect(cResult, isNotNull);
    expect(cResult!.key, 'C');
    expect(cResult.noteLabel, 'C5');
    expect(cResult.cents.abs(), lessThan(5));

    final fResult = detectHarmonicaKeyFromHole4Blow(698.46); // F5
    expect(fResult!.key, 'F');
    expect(fResult.noteLabel, 'F5');

    final gResult = detectHarmonicaKeyFromHole4Blow(392.00); // G4
    expect(gResult!.key, 'G');
    expect(gResult.noteLabel, 'G4');

    final bbResult = detectHarmonicaKeyFromHole4Blow(466.16); // Bb4
    expect(bbResult!.key, 'B♭');

    expect(detectHarmonicaKeyFromHole4Blow(0), isNull);
    expect(detectHarmonicaKeyFromHole4Blow(80), isNull);

    expect(shortNoteNameForHole(4, isBlow: true, key: 'C'), 'C');
    expect(shortNoteNameForHole(4, isBlow: false, key: 'C'), 'D');
    expect(shortNoteNameForHole(4, isBlow: true, key: 'F'), 'F');
    expect(shortNoteNameForHole(5, isBlow: false, key: 'F'), 'B♭');
  });

  testWidgets('first-launch registration allows skipping with default C key', (
    tester,
  ) async {
    final controller = AppController();
    addTearDown(controller.dispose);
    await pumpBreathnote(
      tester,
      controller: controller,
      hasRegisteredHarmonica: false,
    );

    expect(find.text('登记你的口琴'), findsOneWidget);
    expect(find.byKey(const Key('reg-hole-preview')), findsOneWidget);
    expect(find.byKey(const Key('registration-skip')), findsOneWidget);

    await tester.tap(find.byKey(const Key('registration-skip')));
    await tester.pumpAndSettle();

    expect(controller.hasRegisteredHarmonica, isTrue);
    expect(controller.harmonicaKey, 'C');
    expect(find.byKey(const Key('main-tab-page-view')), findsOneWidget);
  });

  testWidgets(
    'first-launch registration detects harmonica key via hole 4 blow and saves',
    (tester) async {
      final harness = installPitchCompletionHarness();
      final controller = AppController();
      addTearDown(controller.dispose);
      await pumpBreathnote(
        tester,
        controller: controller,
        hasRegisteredHarmonica: false,
      );

      // Expand secondary keys and verify they become visible
      await tester.tap(find.byKey(const Key('reg-more-keys')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reg-key-F#')), findsOneWidget);

      // Trigger Hole 4 auto-detection and stream G4 (392 Hz)
      await tester.ensureVisible(find.byKey(const Key('reg-detect-key-btn')));
      await tester.tap(find.byKey(const Key('reg-detect-key-btn')));
      await tester.pump(const Duration(milliseconds: 50));

      harness.emitPitch(392.00); // frame 1 (t = 250ms)
      await tester.pump(const Duration(milliseconds: 20));
      harness.emitPitch(392.00); // frame 2 (t = 500ms)
      await tester.pump(const Duration(milliseconds: 20));
      harness.emitPitch(392.00); // frame 3 (t = 750ms, elapsed 500ms -> lock!)
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('reg-detect-result')), findsOneWidget);
      expect(find.textContaining('G 调'), findsWidgets);

      await tester.tap(find.byKey(const Key('registration-complete')));
      await tester.pumpAndSettle();

      expect(controller.hasRegisteredHarmonica, isTrue);
      expect(controller.harmonicaKey, 'G');
      expect(find.byKey(const Key('main-tab-page-view')), findsOneWidget);

      // Verify Songs tab also surfaces the quick harmonica key chip
      await tester.tap(find.text('曲谱'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('songs-key-chip')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('songs-key-chip')),
          matching: find.text('G 调'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'gates lessons 6-7 and Pro songs until Early-Bird buyout or Restore Purchases',
    (tester) async {
      final fakeBilling = _FakePurchaseService();
      final controller = AppController(purchaseService: fakeBilling);
      addTearDown(controller.dispose);
      await pumpBreathnote(
        tester,
        controller: controller,
        isProUnlocked: false,
      );

      // Lessons 1-5 are free; lessons 6-10 are Pro
      expect(lessons, hasLength(10));
      expect(lessons.where((l) => !l.isPro), hasLength(5));
      expect(lessons.where((l) => l.isPro), hasLength(5));

      // Tapping Pro-gated Lesson 6 opens the Early-Bird buyout paywall
      await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('lesson-pro-badge-lesson_5')), findsOneWidget);

      await tester.tap(find.byKey(const Key('progressive-upcoming-lesson_5')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('paywall-buy-pro')), findsOneWidget);
      expect(find.byKey(const Key('paywall-restore')), findsOneWidget);

      // Buy Pro lifetime -> unlocks immediately and enters Lesson 6
      await tester.tap(find.byKey(const Key('paywall-buy-pro')));
      await tester.pumpAndSettle();

      expect(controller.isProUnlocked, isTrue);
      expect(find.text('开始曲谱练习'), findsOneWidget);

      // Verify Restore Purchases path on a fresh controller
      final restoreController = AppController(
        purchaseService: _FakePurchaseService(restoreFound: true),
      );
      addTearDown(restoreController.dispose);
      final restored = await restoreController.restorePro();
      expect(restored.status, PurchaseStatus.restored);
      expect(restoreController.isProUnlocked, isTrue);
    },
  );

  testWidgets(
    'lesson 7 chord & rhythm uses beat pulse and breath volume envelope (no single-note pitch required)',
    (tester) async {
      const audioChannel = MethodChannel('app.breathnote/audio_control');
      const pitchChannel = EventChannel('app.breathnote/pitch_events');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      MockStreamHandlerEventSink? eventSink;

      messenger.setMockMethodCallHandler(audioChannel, (call) async {
        return switch (call.method) {
          'requestMicrophonePermission' => 'granted',
          'startPitchDetection' => true,
          'playGuideSequence' => 600,
          _ => null,
        };
      });
      messenger.setMockStreamHandler(
        pitchChannel,
        MockStreamHandler.inline(
          onListen: (_, events) {
            eventSink = events;
          },
        ),
      );
      addTearDown(() {
        messenger.setMockMethodCallHandler(audioChannel, null);
        messenger.setMockStreamHandler(pitchChannel, null);
      });

      final controller = AppController();
      addTearDown(controller.dispose);
      await pumpBreathnote(tester, controller: controller, isProUnlocked: true);

      await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -700));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('progressive-upcoming-lesson_chord')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('chord-holes-bar')), findsOneWidget);
      expect(find.byKey(const Key('chord-envelope-meter')), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('chord-start-practice')));
      await tester.tap(find.byKey(const Key('chord-start-practice')));
      await tester.pump(const Duration(milliseconds: 50));

      void emitChordBreath() {
        // Multi-note chord has detected=false for monophonic pitch, but strong breath envelope (-22 dBFS)!
        eventSink?.success(<String, Object?>{
          'detected': false,
          'frequency': 0.0,
          'note': '',
          'octave': 0,
          'cents': 0.0,
          'confidence': 0.0,
          'levelDb': -22.0,
          'timestampMicros': 1000000,
        });
      }

      // Bar 1: Beat 1 (blow) -> Beat 2 (rest) -> Beat 3 (draw) -> Beat 4 (rest)
      emitChordBreath();
      await tester.pump(const Duration(milliseconds: 850)); // -> beat 2
      await tester.pump(const Duration(milliseconds: 850)); // -> beat 3
      emitChordBreath();
      await tester.pump(const Duration(milliseconds: 850)); // -> beat 4
      await tester.pump(const Duration(milliseconds: 850)); // -> Bar 2 Beat 1

      // Bar 2: Beat 1 (blow) -> Beat 2 -> Beat 3 (draw) -> completes!
      emitChordBreath();
      await tester.pump(const Duration(milliseconds: 850)); // -> beat 2
      await tester.pump(const Duration(milliseconds: 850)); // -> beat 3
      emitChordBreath();
      await tester.pumpAndSettle();

      expect(controller.completedLessons, contains('lesson_chord'));
      expect(find.byKey(const Key('chord-share-achievement')), findsOneWidget);
    },
  );

  test(
    'evaluates 3D song score (pitch, timing, stability), stars, and weakest tab coaching',
    () {
      const n1 = PracticeNote(note: 'C', octave: 5, tab: '4↑');
      const n2 = PracticeNote(note: 'E', octave: 5, tab: '5↑');
      const n3 = PracticeNote(note: 'A', octave: 5, tab: '6↓');
      const n4 = PracticeNote(note: 'A', octave: 5, tab: '6↓');

      final records = [
        NoteScoreRecord.fromSamples(
          index: 0,
          note: n1,
          centsSamples: const [2, 4, 1],
          firstOnsetOffsetMs: 40,
        ),
        NoteScoreRecord.fromSamples(
          index: 1,
          note: n2,
          centsSamples: const [-6, -4, -5],
          firstOnsetOffsetMs: 80,
        ),
        NoteScoreRecord.fromSamples(
          index: 2,
          note: n3,
          centsSamples: const [-38, -42, -35],
          firstOnsetOffsetMs: 180,
        ),
        NoteScoreRecord.fromSamples(
          index: 3,
          note: n4,
          centsSamples: const [],
          firstOnsetOffsetMs: null,
        ),
      ];

      final summary = SongScoreSummary.evaluate(records);
      expect(summary.hitCount, 3);
      expect(summary.maxCombo, 2);
      expect(summary.pitchScore, inInclusiveRange(50, 85));
      expect(summary.timingScore, inInclusiveRange(60, 85));
      expect(summary.stabilityScore, inInclusiveRange(65, 85));
      expect(summary.stars, inInclusiveRange(1, 2));
      expect(summary.weakestTab, '6↓');
      expect(summary.notes[0].status, NoteScoreStatus.accurate);
      expect(summary.notes[2].status, NoteScoreStatus.flat);
      expect(summary.notes[3].status, NoteScoreStatus.missed);
    },
  );

  testWidgets(
    'song scoring mode runs count-in, scores notes, gates 3D report for Free and unlocks on Pro buyout',
    (tester) async {
      final harness = installPitchCompletionHarness();
      final controller = AppController(
        purchaseService: const _FakePurchaseService(),
      );
      addTearDown(controller.dispose);
      const miniSong = Song(
        id: 'mini_score_song',
        title: '双音小测',
        subtitle: 'customSongSubtitle',
        level: 'easy',
        color: Color(0xFF1A6BFF),
        notes: [
          PracticeNote(note: 'C', octave: 5, tab: '4↑'),
          PracticeNote(note: 'E', octave: 5, tab: '5↑'),
        ],
      );

      controller.sawHarmonicaGuide = true;
      controller.hasRegisteredHarmonica = true;
      controller.isProUnlocked = false;

      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(412, 915);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        AppScope(
          controller: controller,
          child: MaterialApp(
            theme: AppTheme.light(highContrast: false, reduceMotion: false),
            home: const SongPracticeScreen(song: miniSong),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Scoring Mode
      await tester.tap(find.text('评分模式'));
      await tester.pumpAndSettle();
      expect(find.text('开始评分挑战'), findsOneWidget);

      // Start Scoring -> 4-beat count-in
      await tester.tap(find.text('开始评分挑战'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const Key('scoring-count-in-banner')), findsOneWidget);

      // Advance past 4 count-in beats (4 * 450ms = 1800ms)
      await tester.pump(const Duration(milliseconds: 1850));

      // Note 1: 4↑ (C5) accurate
      harness.emitPitch(miniSong.notes[0].frequencyForKey('C'));
      await tester.pump(const Duration(milliseconds: 900));

      // Note 2: 5↑ (E5) accurate -> completes song & opens Performance Report
      harness.emitPitch(miniSong.notes[1].frequencyForKey('C'));
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();

      // Free user sees stars + total score + Pro locked teaser
      expect(find.byKey(const Key('score-stars-row')), findsOneWidget);
      expect(find.byKey(const Key('score-pro-locked-card')), findsOneWidget);
      expect(find.byKey(const Key('score-pro-diagnostics')), findsNothing);
      expect(controller.bestStarsForSong('mini_score_song'), 3);
      expect(controller.isSongCompleted('mini_score_song'), isTrue);

      // Unlock Pro inside report -> 3D breakdown, note review & coach tip appear immediately
      await tester.ensureVisible(find.byKey(const Key('score-unlock-pro-btn')));
      await tester.tap(find.byKey(const Key('score-unlock-pro-btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('paywall-buy-pro')));
      await tester.pumpAndSettle();

      expect(controller.isProUnlocked, isTrue);
      expect(find.byKey(const Key('score-pro-diagnostics')), findsOneWidget);
      expect(find.byKey(const Key('score-dim-pitch')), findsOneWidget);
      expect(find.byKey(const Key('score-dim-timing')), findsOneWidget);
      expect(find.byKey(const Key('score-dim-stability')), findsOneWidget);
      expect(find.byKey(const Key('score-note-review')), findsOneWidget);
      expect(find.byKey(const Key('score-coach-tip')), findsOneWidget);
    },
  );

  testWidgets(
    'songs library supports favorites, star badges, and completed/favorites filters',
    (tester) async {
      final controller = AppController();
      addTearDown(controller.dispose);
      await controller.recordSongResult(
        songId: 'twinkle',
        score: 92,
        stars: 3,
      );
      await pumpBreathnote(tester, controller: controller);

      await tester.tap(find.text('曲谱'));
      await tester.pumpAndSettle();

      // Completed song shows star badge; unplayed song shows unplayed tag
      expect(find.byKey(const Key('song-stars-twinkle')), findsOneWidget);
      expect(find.byKey(const Key('song-unplayed-ode_to_joy')), findsOneWidget);

      // Filter: Completed -> only twinkle visible
      await tester.tap(find.byKey(const Key('songs-filter-completed')));
      await tester.pumpAndSettle();
      expect(find.text('小星星'), findsOneWidget);
      expect(find.text('欢乐颂'), findsNothing);

      // Favorite twinkle and check Favorites filter
      await tester.tap(find.byKey(const Key('song-favorite-twinkle')));
      await tester.pumpAndSettle();
      expect(controller.isSongFavorite('twinkle'), isTrue);

      await tester.tap(find.byKey(const Key('songs-filter-favorites')));
      await tester.pumpAndSettle();
      expect(find.text('小星星'), findsOneWidget);
      expect(find.text('两只老虎'), findsNothing);
    },
  );

  testWidgets(
    'tuner live 1-10 hole strip highlights enharmonic 2↓ and 3↑ simultaneously',
    (tester) async {
      const audioChannel = MethodChannel('app.breathnote/audio_control');
      const pitchChannel = EventChannel('app.breathnote/pitch_events');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      MockStreamHandlerEventSink? eventSink;

      messenger.setMockMethodCallHandler(audioChannel, (call) async {
        return switch (call.method) {
          'requestMicrophonePermission' => 'granted',
          'startPitchDetection' => true,
          _ => null,
        };
      });
      messenger.setMockStreamHandler(
        pitchChannel,
        MockStreamHandler.inline(
          onListen: (_, events) {
            eventSink = events;
          },
        ),
      );
      addTearDown(() {
        messenger.setMockMethodCallHandler(audioChannel, null);
        messenger.setMockStreamHandler(pitchChannel, null);
      });

      final controller = AppController();
      addTearDown(controller.dispose);
      await pumpBreathnote(tester, controller: controller);

      await tester.tap(find.text('调音'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tuner-live-hole-strip')), findsOneWidget);
      for (var hole = 1; hole <= 10; hole++) {
        expect(find.byKey(Key('tuner-hole-cell-$hole')), findsOneWidget);
      }

      await tester.ensureVisible(find.text('开始调音'));
      await tester.tap(find.text('开始调音'));
      await tester.pump(const Duration(milliseconds: 50));

      // G4 (392.0 Hz, MIDI 67) is BOTH 2↓ and 3↑ on a C harmonica!
      eventSink?.success(<String, Object?>{
        'detected': true,
        'frequency': 392.0,
        'note': 'G',
        'octave': 4,
        'cents': 0.0,
        'confidence': 1.0,
        'levelDb': -20.0,
        'timestampMicros': 1000000,
      });
      await tester.pump(const Duration(milliseconds: 80));

      expect(
        find.descendant(
          of: find.byKey(const Key('tuner-hole-cell-2')),
          matching: find.text('2↓'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('tuner-hole-cell-3')),
          matching: find.text('3↑'),
        ),
        findsOneWidget,
      );
    },
  );

  test(
    'parses MIDI SMF bytes and MusicXML, auto-transposes for minimum bends, and recommends enharmonic holes',
    () {
      // Build a valid SMF Format 0 MIDI with track title "Folk" and C# major notes [61, 63, 65, 68]
      final titleBytes = utf8.encode('Folk');
      final trackEvents = <int>[
        0x00, 0xFF, 0x03, titleBytes.length, ...titleBytes, // Track Name
        0x00, 0x90, 61, 100, // C#4
        0x20, 0x80, 61, 0,
        0x00, 0x90, 63, 100, // D#4
        0x20, 0x80, 63, 0,
        0x00, 0x90, 65, 100, // F4
        0x20, 0x80, 65, 0,
        0x00, 0x90, 68, 100, // G#4
        0x20, 0x80, 68, 0,
        0x00, 0x99, 36, 100, // Channel 10 percussion -> must be skipped
        0x00, 0xFF, 0x2F, 0x00, // End of track
      ];
      final midiBytes = Uint8List.fromList([
        0x4D, 0x54, 0x68, 0x64, // MThd
        0x00, 0x00, 0x00, 0x06, // header length 6
        0x00, 0x00, // format 0
        0x00, 0x01, // 1 track
        0x00, 0x60, // division 96
        0x4D, 0x54, 0x72, 0x6B, // MTrk
        (trackEvents.length >> 24) & 0xFF,
        (trackEvents.length >> 16) & 0xFF,
        (trackEvents.length >> 8) & 0xFF,
        trackEvents.length & 0xFF,
        ...trackEvents,
      ]);

      final midiSource = parseMidiBytes(midiBytes);
      expect(midiSource.title, 'Folk');
      expect(midiSource.midis, [61, 63, 65, 68]);

      final midiPlan = buildScoreImportPlan(
        sourceMidis: midiSource.midis,
        harmonicaKey: 'C',
      );
      // Shifting -1 semitone turns [61, 63, 65, 68] -> [60, 62, 64, 67] (C D E G: 0 bends!)
      expect(midiPlan.bendCount, 0);

      // Parse MusicXML with rest & chord skipped
      const sampleXml = '''
<score-partwise>
  <work><work-title>River Song</work-title></work>
  <part id="P1">
    <measure number="1">
      <note><pitch><step>C</step><octave>4</octave></pitch></note>
      <note><chord/><pitch><step>E</step><octave>4</octave></pitch></note>
      <note><pitch><step>G</step><octave>4</octave></pitch></note>
      <note><rest/></note>
      <note><pitch><step>C</step><octave>5</octave></pitch></note>
      <note><pitch><step>G</step><octave>4</octave></pitch></note>
    </measure>
  </part>
</score-partwise>
''';
      final xmlSource = parseMusicXml(sampleXml);
      expect(xmlSource.title, 'River Song');
      expect(xmlSource.midis, [60, 67, 72, 67]);

      final xmlPlan = buildScoreImportPlan(
        sourceMidis: xmlSource.midis,
        harmonicaKey: 'C',
        transposeOverride: 0,
      );
      // Index 1 (G4 after C4/1↑) -> recommends 2↓; Index 3 (G4 after C5/4↑) -> recommends 3↑!
      expect(xmlPlan.items[1].hasEnharmonicChoice, isTrue);
      expect(xmlPlan.items[1].selectedTab, '2↓');
      expect(xmlPlan.items[3].selectedTab, '3↑');

      final flipped = xmlPlan.withSelectedTab(1, '3↑');
      expect(flipped.items[1].selectedTab, '3↑');
    },
  );

  testWidgets(
    '3-step custom song import wizard imports MusicXML, transposes, skips bends, edits 2↓/3↑, and saves',
    (tester) async {
      const filePickerChannel = MethodChannel('app.breathnote/file_picker');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      // Chromatic cluster C4, C#4, D4, G4 (2↓/3↑ enharmonic), C5, E5 -> guarantees >=1 bend in any key
      const sampleXml = '''
<score-partwise>
  <work><work-title>Breeze XML</work-title></work>
  <part id="P1">
    <measure number="1">
      <note><pitch><step>C</step><octave>4</octave></pitch></note>
      <note><pitch><step>C</step><alter>1</alter><octave>4</octave></pitch></note>
      <note><pitch><step>D</step><octave>4</octave></pitch></note>
      <note><pitch><step>G</step><octave>4</octave></pitch></note>
      <note><pitch><step>C</step><octave>5</octave></pitch></note>
      <note><pitch><step>E</step><octave>5</octave></pitch></note>
    </measure>
  </part>
</score-partwise>
''';
      messenger.setMockMethodCallHandler(filePickerChannel, (call) async {
        if (call.method == 'pickScoreFile') {
          return <String, Object?>{
            'name': 'breeze.musicxml',
            'bytes': Uint8List.fromList(utf8.encode(sampleXml)),
          };
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(filePickerChannel, null),
      );

      final controller = AppController();
      addTearDown(controller.dispose);
      await pumpBreathnote(tester, controller: controller, isProUnlocked: true);

      await tester.tap(find.text('曲谱'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add-custom-song')));
      await tester.pumpAndSettle();

      // Switch Step 1 to MIDI / MusicXML tab and pick file
      await tester.tap(find.text('MIDI / MusicXML'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('import-pick-file-btn')));
      await tester.pumpAndSettle();

      // Step 2: Transpose & Bend preview
      expect(find.byKey(const Key('import-transpose-summary')), findsOneWidget);
      expect(find.byKey(const Key('import-skip-bend-switch')), findsOneWidget);

      // Step 3: Enharmonic check (if enharmonic present, flip; then save)
      await tester.ensureVisible(find.byKey(const Key('import-next-to-step3')));
      await tester.tap(find.byKey(const Key('import-next-to-step3')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('import-final-save')));
      await tester.tap(find.byKey(const Key('import-final-save')));
      await tester.pumpAndSettle();

      expect(controller.customSongs, hasLength(1));
      final saved = controller.customSongs.first;
      expect(saved.title, 'Breeze XML');
      expect(saved.skipBendNotes, isTrue);
      expect(saved.bendNoteCount, greaterThan(0));
      expect(saved.playableNotes.length, lessThan(saved.notes.length));
      expect(find.byKey(const Key('song-skip-bend-badge')), findsOneWidget);
    },
  );

  testWidgets(
    'Pro multi-harmonica presets allow adding and one-tap switching with Pro gating',
    (tester) async {
      final controller = AppController(
        purchaseService: const _FakePurchaseService(),
      );
      addTearDown(controller.dispose);
      await pumpBreathnote(tester, controller: controller, isProUnlocked: false);

      await tester.tap(find.text('我的'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('harmonica-key-setting')));
      await tester.pumpAndSettle();

      // Tapping Add Harp while Free opens Pro paywall -> buy unlocks -> opens Add dialog
      await tester.tap(find.byKey(const Key('key-picker-add-preset')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('paywall-buy-pro')), findsOneWidget);
      await tester.tap(find.byKey(const Key('paywall-buy-pro')));
      await tester.pumpAndSettle();

      // Add "G 调民谣琴" in key G
      await tester.enterText(
        find.byKey(const Key('preset-name-field')),
        'G 调民谣琴',
      );
      await tester.tap(find.byKey(const Key('preset-key-G')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('preset-save-btn')));
      await tester.pumpAndSettle();

      expect(controller.isProUnlocked, isTrue);
      expect(controller.harmonicaPresets, hasLength(1));
      expect(controller.harmonicaKey, 'G');
      expect(controller.activePreset?.name, 'G 调民谣琴');

      // Switch to key C directly, then tap preset to jump back to G
      await controller.setHarmonicaKey('C');
      await tester.pumpAndSettle();
      expect(controller.harmonicaKey, 'C');

      await tester.tap(find.byKey(const Key('harmonica-key-setting')));
      await tester.pumpAndSettle();
      final presetId = controller.harmonicaPresets.first.id;
      await tester.tap(find.byKey(Key('harmonica-preset-$presetId')));
      await tester.pumpAndSettle();
      expect(controller.harmonicaKey, 'G');
    },
  );

  testWidgets(
    '48h intro offer uses real firstInstallAt timestamp and falls back to ¥68 after 48h',
    (tester) async {
      final controller = AppController();
      addTearDown(controller.dispose);
      controller.firstInstallAt = DateTime.now().subtract(
        const Duration(hours: 10),
      );
      await pumpBreathnote(tester, controller: controller, isProUnlocked: false);

      expect(controller.hasActiveIntroOffer, isTrue);
      await tester.tap(find.text('我的'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('profile-pro-card')));
      await tester.pumpAndSettle();
      expect(find.text('¥28'), findsOneWidget);
      expect(find.textContaining('48h 新手首单特惠'), findsOneWidget);

      Navigator.of(tester.element(find.byKey(const Key('paywall-buy-pro')))).pop();
      await tester.pumpAndSettle();

      // After 48h -> real regular price ¥68, no fake countdown
      controller.firstInstallAt = DateTime.now().subtract(
        const Duration(hours: 50),
      );
      expect(controller.hasActiveIntroOffer, isFalse);
      await tester.tap(find.byKey(const Key('profile-pro-card')));
      await tester.pumpAndSettle();
      expect(find.text('¥68'), findsOneWidget);
      expect(find.text('一次性永久买断'), findsOneWidget);
    },
  );

  test(
    'maps all 12 standard Richter keys to physical octaves and matches Tuner holes accurately',
    () {
      const hole1Blow = PracticeNote(note: 'C', octave: 4, tab: '1↑');
      const hole4Blow = PracticeNote(note: 'C', octave: 5, tab: '4↑');
      const hole10Blow = PracticeNote(note: 'C', octave: 7, tab: '10↑');

      // Authentic physical Richter octaves: G3..F#4 on Hole 1 blow
      expect(hole1Blow.labelForKey('G'), 'G3');
      expect(hole4Blow.labelForKey('G'), 'G4');
      expect(hole4Blow.frequencyForKey('G'), closeTo(392.00, 0.2));
      expect(hole4Blow.labelForKey('A'), 'A4');
      expect(hole4Blow.frequencyForKey('A'), closeTo(440.00, 0.2));
      expect(hole4Blow.labelForKey('B♭'), 'A#4');
      expect(hole4Blow.labelForKey('C'), 'C5');
      expect(hole4Blow.labelForKey('F'), 'F5');
      expect(hole10Blow.labelForKey('F#'), 'F#7');
      expect(hole10Blow.frequencyForKey('F#'), closeTo(2959.96, 0.5));

      // Tuner live hole strip must match physical G4 = 4↑ on a G harmonica
      final g4Tabs = tabsForReading(
        const PitchReading(
          detected: true,
          frequency: 392.00,
          note: 'G',
          octave: 4,
          cents: 0,
          confidence: 0.96,
          levelDb: -24,
          timestampMicros: 1000,
        ),
        'G',
      );
      expect(g4Tabs, hasLength(1));
      expect(g4Tabs.first.hole, 4);
      expect(g4Tabs.first.isBlow, isTrue);

      // Physical A4 = 4↑ on an A harmonica
      final a4Tabs = tabsForReading(
        const PitchReading(
          detected: true,
          frequency: 440.00,
          note: 'A',
          octave: 4,
          cents: 0,
          confidence: 0.96,
          levelDb: -24,
          timestampMicros: 1000,
        ),
        'A',
      );
      expect(a4Tabs, hasLength(1));
      expect(a4Tabs.first.hole, 4);
      expect(a4Tabs.first.isBlow, isTrue);

      // Attack-transient trimming: 1 stray onset frame (+85¢) followed by steady frames
      // must keep median accurate and high stability score
      final trimmed = NoteScoreRecord.fromSamples(
        index: 0,
        note: hole4Blow,
        centsSamples: const [85.0, 2.0, -1.0, 3.0, 1.0, 0.0],
        firstOnsetOffsetMs: 40,
      );
      expect(trimmed.status, NoteScoreStatus.accurate);
      expect(trimmed.stabilityStdDevCents!, lessThan(3.0));
      final summary = SongScoreSummary.evaluate([trimmed]);
      expect(summary.stabilityScore, 100);
    },
  );

  testWidgets(
    'tuner header exposes quick multi-key switcher chip and updates active key',
    (tester) async {
      final controller = AppController()..harmonicaKey = 'C';
      addTearDown(controller.dispose);
      await pumpBreathnote(tester, controller: controller);

      await tester.tap(find.text('调音'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tuner-key-chip')), findsOneWidget);
      await tester.tap(find.byKey(const Key('tuner-key-chip')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('harmonica-key-G')));
      await tester.pumpAndSettle();

      expect(controller.harmonicaKey, 'G');
      expect(
        find.descendant(
          of: find.byKey(const Key('tuner-key-chip')),
          matching: find.textContaining('G'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'expands curriculum to 10 lessons and opens lessons 8-10 when Pro unlocked',
    (tester) async {
      final controller = AppController();
      addTearDown(controller.dispose);
      await pumpBreathnote(tester, controller: controller, isProUnlocked: true);

      expect(lessons, hasLength(10));
      expect(find.text('已完成 0/10 课'), findsOneWidget);

      await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -1000));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('progressive-upcoming-lesson_6')), findsOneWidget);
      expect(find.byKey(const Key('progressive-upcoming-lesson_7')), findsOneWidget);
      expect(find.byKey(const Key('progressive-upcoming-lesson_8')), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('progressive-upcoming-lesson_6')));
      await tester.tap(find.byKey(const Key('progressive-upcoming-lesson_6')));
      await tester.pumpAndSettle();
      expect(find.text('低音共鸣与同音孔位'), findsOneWidget);
      expect(find.textContaining('3↑'), findsWidgets);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('progressive-upcoming-lesson_8')));
      await tester.tap(find.byKey(const Key('progressive-upcoming-lesson_8')));
      await tester.pumpAndSettle();
      expect(find.text('初鸣微风'), findsOneWidget);
      expect(find.text('开始曲谱练习'), findsOneWidget);
    },
  );

  testWidgets(
    'tuner keeps primary button above navigation bar on phone viewport',
    (tester) async {
      final controller = AppController();
      addTearDown(controller.dispose);
      await pumpBreathnote(
        tester,
        controller: controller,
        size: const Size(360, 792),
      );

      await tester.tap(find.text('调音'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tuner-live-hole-strip')), findsOneWidget);
      expect(find.text('稳吹一个单音，这里会实时显示音准'), findsOneWidget);
      expect(find.text('吹吸任意孔即可点亮'), findsOneWidget);

      final startButton = find.ancestor(
        of: find.text('开始调音'),
        matching: find.byType(FilledButton),
      );
      expect(startButton, findsOneWidget);

      final startBtnBottom = tester.getBottomRight(startButton).dy;
      final navBarTop = tester
          .getTopLeft(find.byKey(const Key('floating-glass-tab-bar')))
          .dy;
      expect(startBtnBottom, lessThanOrEqualTo(navBarTop));
      expect(navBarTop - startBtnBottom, inInclusiveRange(8.0, 24.0));
    },
  );

  testWidgets(
    'floating liquid glass tab bar supports direct horizontal scrub across tabs',
    (tester) async {
      await pumpBreathnote(tester);

      final glassBar = find.byKey(const Key('floating-glass-tab-bar'));
      expect(glassBar, findsOneWidget);
      expect(find.byKey(const Key('floating-glass-indicator')), findsOneWidget);

      final rect = tester.getRect(glassBar);
      final startPoint = Offset(rect.left + rect.width * 0.12, rect.center.dy);
      final dragDistance = rect.width * 0.76;

      await tester.dragFrom(startPoint, Offset(dragDistance, 0));
      await tester.pumpAndSettle();

      // Scrubbing from Learn (left) to Profile (right) switches to Profile tab
      expect(find.text('本机数据与隐私'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'floating glass bar and Option A bottom scrim adapt across resolutions without hazing tuner CTA',
    (tester) async {
      final sizes = <(Size, double)>[
        (const Size(320, 640), 54), // very compact phone
        (const Size(360, 792), 58), // OnePlus 13 / standard compact phone
        (const Size(430, 932), 62), // large flagship phone
        (const Size(780, 360), 50), // landscape viewport
      ];

      for (final (viewport, expectedBarHeight) in sizes) {
        final controller = AppController();
        addTearDown(controller.dispose);
        await pumpBreathnote(tester, controller: controller, size: viewport);

        final barFinder = find.byKey(const Key('floating-glass-tab-bar'));
        final scrimFinder = find.byKey(const Key('floating-glass-bottom-scrim'));
        expect(barFinder, findsOneWidget);
        expect(scrimFinder, findsOneWidget);

        final barRect = tester.getRect(barFinder);
        final scrimRect = tester.getRect(scrimFinder);
        expect(barRect.height, expectedBarHeight);
        // Option A scrim starts above the floating capsule on list tabs
        expect(scrimRect.top, lessThan(barRect.top));
        expect(scrimRect.bottom, viewport.height);
      }

      // On Tuner tab, scrim retracts above-bar fade so the pinned CTA button is never hazed
      final tunerController = AppController();
      addTearDown(tunerController.dispose);
      await pumpBreathnote(
        tester,
        controller: tunerController,
        size: const Size(360, 792),
      );
      await tester.tap(find.text('调音'));
      await tester.pumpAndSettle();

      final startButton = find.ancestor(
        of: find.text('开始调音'),
        matching: find.byType(FilledButton),
      );
      final startBtnBottom = tester.getBottomRight(startButton).dy;
      final scrimTop = tester
          .getTopLeft(find.byKey(const Key('floating-glass-bottom-scrim')))
          .dy;
      expect(scrimTop, greaterThanOrEqualTo(startBtnBottom));
      expect(tester.takeException(), isNull);
    },
  );
}

class _FakePurchaseService extends PurchaseService {
  const _FakePurchaseService({this.restoreFound = false});

  final bool restoreFound;

  @override
  Future<PurchaseResult> purchaseProLifetime() async {
    return const PurchaseResult(PurchaseStatus.purchased);
  }

  @override
  Future<PurchaseResult> restorePurchases() async {
    return PurchaseResult(
      restoreFound ? PurchaseStatus.restored : PurchaseStatus.notFound,
    );
  }
}
