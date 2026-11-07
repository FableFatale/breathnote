import 'dart:async';

import 'package:breathnote/src/app.dart';
import 'package:breathnote/src/models/song.dart';
import 'package:breathnote/src/services/preferences_service.dart';
import 'package:breathnote/src/state/app_controller.dart';
import 'package:breathnote/src/theme/app_motion.dart';
import 'package:breathnote/src/widgets/motion_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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

Future<void> pumpBreathnote(
  WidgetTester tester, {
  AppController? controller,
  Size size = const Size(412, 915),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(BreathnoteApp(controller: controller));
  await tester.pumpAndSettle();
}

void main() {
  test('uses the verified Figma motion timings', () {
    expect(AppMotion.fast, const Duration(milliseconds: 160));
    expect(AppMotion.base, const Duration(milliseconds: 240));
    expect(AppMotion.slow, const Duration(milliseconds: 420));
    expect(AppMotion.breathing, const Duration(milliseconds: 2400));
  });

  test('parses valid custom harmonica notation', () {
    final notes = parseHarmonicaTabs('4↑ 4↓ | 5↑，6↓');

    expect(notes.map((note) => note.tab), ['4↑', '4↓', '5↑', '6↓']);
    expect(() => parseHarmonicaTabs('4 5↑'), throwsFormatException);
  });

  testWidgets('opens all four main navigation destinations', (tester) async {
    await pumpBreathnote(tester);

    expect(
      tester.widget<AnimatedTabStack>(find.byType(AnimatedTabStack)).duration,
      AppMotion.base,
    );
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

  testWidgets('opens lesson detail and single-note practice', (tester) async {
    await pumpBreathnote(tester);

    await tester.tap(find.text('认识你的口琴').first);
    await tester.pumpAndSettle();
    expect(find.text('10 孔布鲁斯口琴'), findsOneWidget);
    expect(find.text('完成本课'), findsOneWidget);

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
    expect(find.text('吹出 F 音'), findsOneWidget);
    expect(find.text('含住第 4 孔，轻轻吹气。不要用力，让气息自然流过。'), findsOneWidget);
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
    await tester.enterText(
      find.byKey(const Key('custom-song-notation')),
      '4↑ 4↓ 5↑',
    );
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('save-custom-song')));
    await tester.tap(find.byKey(const Key('save-custom-song')));
    await tester.pumpAndSettle();

    expect(controller.customSongs.single.title, '晨风');
    expect(find.text('晨风'), findsWidgets);
    expect(find.text('当前目标'), findsOneWidget);
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

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.byKey(const Key('accessibility-setting')));
    await tester.tap(find.byKey(const Key('accessibility-setting')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('switches language across the whole app', (tester) async {
    final controller = AppController();
    addTearDown(controller.dispose);
    await pumpBreathnote(tester, controller: controller);

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('appearance-language-setting')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(controller.languageCode, 'en');
    expect(find.text('Theme'), findsWidgets);
    expect(find.text('Profile'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();
    expect(find.text('LEARNING PATH'), findsOneWidget);
    expect(find.text('Start with one breath'), findsOneWidget);
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

    await tester.tap(find.text('调音'));
    await tester.pumpAndSettle();
    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.value, closeTo(0.82, 0.001));
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
    expect(
      tester.widget<Slider>(find.byType(Slider)).value,
      closeTo(0.68, 0.001),
    );

    preferences.values.complete({'microphoneSensitivity': 0.9});
    await tester.pumpAndSettle();
    expect(
      tester.widget<Slider>(find.byType(Slider)).value,
      closeTo(0.9, 0.001),
    );
    expect(find.text('90%'), findsOneWidget);

    await tester.drag(find.byType(Slider), const Offset(-120, 0));
    await tester.pumpAndSettle();
    expect(preferences.savedValues['microphoneSensitivity'], isA<double>());
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
}
