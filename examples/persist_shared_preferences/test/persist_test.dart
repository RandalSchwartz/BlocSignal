import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:persist_shared_preferences_example/main.dart';

void main() {
  setUp(() {
    HydratedStorage.storage = MemoryHydratedStorage();
  });

  testWidgets('PersistApp toggles and clears dark mode state', (tester) async {
    await tester.pumpWidget(const PersistApp());
    await tester.pumpAndSettle();

    expect(find.text('Light theme is active and persisted'), findsOneWidget);

    final switchTile = find.byType(SwitchListTile);
    await tester.tap(switchTile);
    await tester.pumpAndSettle();

    expect(find.text('Dark theme is active and persisted'), findsOneWidget);

    final clearButton = find.text('Clear Persisted State');
    await tester.tap(clearButton);
    await tester.pumpAndSettle();

    expect(find.text('Light theme is active and persisted'), findsOneWidget);
  });
}
