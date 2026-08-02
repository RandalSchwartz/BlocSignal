import 'package:flutter_test/flutter_test.dart';
import 'package:get_it_signals_example/main.dart';

void main() {
  setUp(() {
    setupServiceLocator();
  });

  testWidgets('GetItApp updates state managed by GetIt singleton',
      (tester) async {
    await tester.pumpWidget(const GetItApp());
    await tester.pumpAndSettle();

    expect(find.text('100'), findsOneWidget);

    final incrementButton = find.text('Increment');
    await tester.tap(incrementButton);
    await tester.pumpAndSettle();

    expect(find.text('101'), findsOneWidget);
  });
}
