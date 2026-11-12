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

  testWidgets('main tabs adapt to compact screens and large text', (
    tester,
  ) async {
    final errors = <String>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      errors.add(details.exceptionAsString());
    };

    final controller = AppController()..textScale = 1.2;
    addTearDown(controller.dispose);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(280, 640);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    await tester.pumpWidget(BreathnoteApp(controller: controller));
    await tester.pumpAndSettle();

    for (final tab in ['学习', '曲谱', '调音', '我的']) {
      final finder = find.text(tab);
      if (finder.evaluate().isEmpty) continue;
      await tester.tap(finder.first, warnIfMissed: false);
      await tester.pumpAndSettle();
      final scrollables = find.byType(Scrollable);
      for (var index = 0; index < scrollables.evaluate().length; index++) {
        await tester.drag(
          scrollables.at(index),
          const Offset(0, -240),
          warnIfMissed: false,
        );
        await tester.pumpAndSettle();
      }
    }

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    FlutterError.onError = previousOnError;

    final overflows = errors
        .where((error) => error.toLowerCase().contains('overflowed'))
        .toList();
    expect(overflows, isEmpty, reason: overflows.join('\n\n'));
  });
}
