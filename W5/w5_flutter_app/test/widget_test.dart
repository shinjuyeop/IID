import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:w5_flutter_app/main.dart';

void main() {
  testWidgets('app renders without crash', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    // Expect at least the app bar title to appear
    expect(find.text('W5 IOT Controller'), findsOneWidget);
  });
}