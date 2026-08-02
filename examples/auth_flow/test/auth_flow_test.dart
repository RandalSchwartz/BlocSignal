import 'package:auth_flow_example/main.dart';
import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    HydratedStorage.storage = MemoryHydratedStorage();
  });

  testWidgets('AuthFlowApp logs in and out cleanly', (tester) async {
    await tester.pumpWidget(const AuthFlowApp());
    await tester.pumpAndSettle();

    expect(find.text('Login'), findsOneWidget);

    final signInButton = find.byType(ElevatedButton);
    await tester.tap(signInButton);
    await tester.pumpAndSettle();

    expect(find.text('Home Dashboard'), findsOneWidget);
    expect(find.text('Welcome, alex!'), findsOneWidget);

    final logoutButton = find.byIcon(Icons.logout);
    await tester.tap(logoutButton);
    await tester.pumpAndSettle();

    expect(find.text('Login'), findsOneWidget);
  });
}
