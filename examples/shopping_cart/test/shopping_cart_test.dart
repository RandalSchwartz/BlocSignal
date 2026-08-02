import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_cart_example/main.dart';

void main() {
  testWidgets('ShoppingCartApp renders catalog and adds items to cart',
      (tester) async {
    await tester.pumpWidget(const ShoppingCartApp());
    await tester.pumpAndSettle();

    expect(find.text('Catalog'), findsOneWidget);
    expect(find.text('Code With Dart'), findsOneWidget);

    final addButton = find.byIcon(Icons.add_shopping_cart).first;
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    final cartButton = find.byIcon(Icons.shopping_cart);
    await tester.tap(cartButton);
    await tester.pumpAndSettle();

    expect(find.text('Shopping Cart'), findsOneWidget);
    expect(find.text('Code With Dart'), findsOneWidget);
    expect(find.text('Total (1 items):'), findsOneWidget);
  });
}
