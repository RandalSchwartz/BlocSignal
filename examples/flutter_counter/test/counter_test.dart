import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_counter_example/main.dart';

void main() {
  testWidgets('CounterApp increments and decrements Cubit and Bloc state',
      (tester) async {
    await tester.pumpWidget(const CounterApp());
    await tester.pumpAndSettle();

    expect(find.text('0'), findsNWidgets(2));

    final cubitAdd = find.widgetWithIcon(IconButton, Icons.add).first;
    await tester.tap(cubitAdd);
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);

    final blocAdd = find.widgetWithIcon(IconButton, Icons.add).last;
    await tester.tap(blocAdd);
    await tester.pumpAndSettle();

    expect(find.text('1'), findsNWidgets(2));
  });
}
