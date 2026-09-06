import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';
import 'package:fic_shopping_cart_example/main.dart';
import 'package:fic_shopping_cart_example/src/views/cart_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MemoryHydratedStorage storage;

  setUp(() {
    storage = MemoryHydratedStorage();
    HydratedStorage.storage = storage;
  });

  tearDown(() {
    HydratedStorage.reset();
  });

  testWidgets(
      'Full e-commerce flow: add item, undo snackbar, navigate to cart, update quantity, and undo',
      (tester) async {
    await tester.pumpWidget(
      UnbreakableShoppingCartApp(storageOverride: storage),
    );
    await tester.pumpAndSettle();

    // Verify Catalog screen renders with product titles
    expect(find.text('Retro Cyber Store'), findsOneWidget);
    expect(find.text('Retro 3.5" Floppy Disk (1.44 MB)'), findsOneWidget);

    // Initial cart badge has no label
    expect(find.byType(Badge), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Add first item to cart
    final addButtons = find.widgetWithText(ElevatedButton, 'Add');
    await tester.tap(addButtons.first);
    await tester.pumpAndSettle();

    // Badge updates to '1'
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Added Retro 3.5" Floppy Disk (1.44 MB) to cart'),
        findsOneWidget);

    // Tap 'Undo' on the SnackBar
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    // Badge clears back to 0
    expect(find.text('1'), findsNothing);

    // Add two items
    await tester.tap(addButtons.at(0));
    await tester.pumpAndSettle();
    await tester.tap(addButtons.at(1));
    await tester.pumpAndSettle();

    // Open Cart Screen via CartBadge icon
    await tester.tap(find.byIcon(Icons.shopping_cart_outlined));
    await tester.pumpAndSettle();

    // Verify Cart View renders
    expect(find.byType(CartView), findsOneWidget);
    expect(find.text('Shopping Cart'), findsOneWidget);
    expect(find.text('Retro 3.5" Floppy Disk (1.44 MB)'), findsOneWidget);
    expect(find.text('Neon Speed Cube (3x3)'), findsOneWidget);

    // Increment quantity of item 1
    final addIcons = find.byIcon(Icons.add_circle_outline);
    await tester.tap(addIcons.first);
    await tester.pump();

    // Verify subtotal updated
    expect(find.text('Subtotal (3 items)'), findsOneWidget);

    // Apply SAVE10 Promo Code
    await tester.tap(find.text('SAVE10 (10% off)'));
    await tester.pump();

    expect(find.text('Discount (SAVE10)'), findsOneWidget);

    // Tap AppBar Undo button
    final undoIcon = find.byIcon(Icons.undo);
    await tester.tap(undoIcon);
    await tester.pump();

    // Discount is removed because the promo code selection was undone!
    expect(find.text('Discount (SAVE10)'), findsNothing);
  });
}
