import 'package:breathnote/src/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('opens all main navigation destinations', (tester) async {
    await tester.pumpWidget(const BreathnoteApp());

    expect(find.text('吹响第一个音'), findsOneWidget);

    await tester.tap(find.text('曲谱'));
    await tester.pumpAndSettle();
    expect(find.text('搜索曲目'), findsOneWidget);

    await tester.tap(find.text('调音'));
    await tester.pumpAndSettle();
    expect(find.text('检测灵敏度'), findsOneWidget);

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    expect(find.text('口琴练习者'), findsOneWidget);
  });

  testWidgets('opens practice UI', (tester) async {
    await tester.pumpWidget(const BreathnoteApp());

    await tester.tap(find.byIcon(Icons.play_arrow_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('单音练习'), findsOneWidget);
    expect(find.text('保持轻柔、均匀的气息'), findsOneWidget);
  });
}
