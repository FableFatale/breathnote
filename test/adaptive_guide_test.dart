import 'package:breathnote/src/app.dart';
import 'package:breathnote/src/state/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const preferencesChannel = MethodChannel('app.breathnote/preferences');

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

  Future<void> pumpApp(
    WidgetTester tester, {
    required String languageCode,
  }) async {
    final controller = AppController()
      ..languageCode = languageCode
      ..textScale = 1.2;
    addTearDown(controller.dispose);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(BreathnoteApp(controller: controller));
    await tester.pumpAndSettle();
  }

  for (final locale in [
    ('zh', '认识你的口琴', '继续'),
    ('en', 'Meet your harmonica', 'Continue'),
    ('ja', 'ハーモニカを知る', '次へ'),
  ]) {
    testWidgets('${locale.$1} guide fits compact large text', (tester) async {
      final errors = <String>[];
      final previousOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        errors.add(details.exceptionAsString());
      };

      await pumpApp(tester, languageCode: locale.$1);
      await tester.ensureVisible(find.byKey(const Key('learn-beginner-guide')));
      await tester.pumpAndSettle();
      final guideCenter = tester.getCenter(
        find.byKey(const Key('learn-beginner-guide')),
      );
      expect(guideCenter.dy, inInclusiveRange(0, 800));
      await tester.tap(find.byKey(const Key('learn-beginner-guide')));
      await tester.pumpAndSettle();

      FlutterError.onError = previousOnError;
      expect(find.text(locale.$2), findsWidgets);
      expect(find.text(locale.$3), findsOneWidget);
      expect(
        errors.where((error) => error.toLowerCase().contains('overflowed')),
        isEmpty,
      );
    });
  }
}
