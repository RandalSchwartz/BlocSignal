import 'package:flutter/material.dart';
import 'package:flutter_colorband_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ColorbandApp updates RGB channel values via sliders',
      (tester) async {
    await tester.pumpWidget(const ColorbandApp());
    await tester.pumpAndSettle();

    expect(find.text('Dynamic Colorband Signals'), findsOneWidget);
    expect(find.text('106'), findsOneWidget); // Initial Red
    expect(find.text('27'), findsOneWidget); // Initial Green
    expect(find.text('154'), findsOneWidget); // Initial Blue

    final resetButton = find.byIcon(Icons.refresh);
    await tester.tap(resetButton);
    await tester.pumpAndSettle();

    expect(find.text('106'), findsOneWidget);
  });
}
