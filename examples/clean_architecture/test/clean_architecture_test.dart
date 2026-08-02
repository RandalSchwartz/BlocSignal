import 'package:clean_architecture_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CleanArchitectureApp fetches weather via repository',
      (tester) async {
    await tester
        .pumpWidget(CleanArchitectureApp(repository: MockWeatherRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Clean Architecture Weather'), findsOneWidget);

    final searchButton = find.text('Search');
    await tester.tap(searchButton);
    await tester.pumpAndSettle();

    expect(find.text('Tokyo'), findsNWidgets(2));
    expect(find.text('18.5 °C'), findsOneWidget);
  });
}
