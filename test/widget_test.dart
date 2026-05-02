import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_tech/main.dart';

void main() {
  testWidgets('AiTechApp se monte sans crasher', (WidgetTester tester) async {
    await tester.pumpWidget(const AiTechApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
