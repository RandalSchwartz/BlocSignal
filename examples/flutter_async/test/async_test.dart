import 'package:flutter_async_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AsyncApp renders user profile after async fetch',
      (tester) async {
    await tester.pumpWidget(const AsyncApp());
    await tester.pumpAndSettle();

    expect(find.text('Samantha Reed'), findsOneWidget);
    expect(find.text('Principal Systems Architect'), findsOneWidget);

    final errorButton = find.text('Simulate Error');
    await tester.tap(errorButton);
    await tester.pumpAndSettle();

    expect(find.textContaining('Failed to connect to user service'),
        findsOneWidget);
  });
}
