import 'package:breathnote/src/app.dart';
import 'package:breathnote/src/models/song.dart';
import 'package:breathnote/src/state/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
  test('parses valid custom harmonica notation', () {
    final notes = parseHarmonicaTabs('4↑ 4↓ | 5↑，6↓');

    expect(notes.map((note) => note.tab), ['4↑', '4↓', '5↑', '6↓']);
    expect(() => parseHarmonicaTabs('4 5↑'), throwsFormatException);
  });

  testWidgets('opens all four main navigation destinations', (tester) async {
    await pumpBreathnote(tester);

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

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('吹响第一个音').first);
    await tester.pumpAndSettle();
    expect(find.text('目标音'), findsOneWidget);
    expect(find.text('开始练习'), findsOneWidget);
    expect(find.text('播放示范'), findsOneWidget);
    expect(find.textContaining('4↑'), findsWidgets);
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
}
