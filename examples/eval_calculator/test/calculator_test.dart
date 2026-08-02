import 'package:eval_calculator_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CalculatorApp evaluates math operations', (tester) async {
    await tester.pumpWidget(const CalculatorApp());
    await tester.pumpAndSettle();

    expect(find.text('0'), findsWidgets);

    await tester.tap(find.text('7'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('+'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('5'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('='));
    await tester.pumpAndSettle();

    expect(find.text('12'), findsOneWidget);
  });
}
