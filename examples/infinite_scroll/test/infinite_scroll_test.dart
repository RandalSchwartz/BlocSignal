import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_scroll_example/main.dart';

void main() {
  testWidgets('InfiniteScrollApp renders posts and filters on search',
      (tester) async {
    await tester.pumpWidget(const InfiniteScrollApp());
    await tester.pumpAndSettle();

    expect(find.text('Infinite Scroll Posts'), findsOneWidget);
    expect(find.text('Post 1: BlocSignal Reactivity'), findsOneWidget);

    final searchField = find.byType(TextField);
    await tester.enterText(searchField, 'Reactivity');
    await tester.pumpAndSettle();

    expect(find.text('Post 1: BlocSignal Reactivity'), findsOneWidget);
  });
}
