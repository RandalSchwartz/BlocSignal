import 'package:bloc_signals/bloc_signals.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:fic_shopping_cart_example/src/cubit/cart_pricing_mixin.dart';
import 'package:fic_shopping_cart_example/src/cubit/shopping_cart_state.dart';
import 'package:fic_shopping_cart_example/src/models/cart_item.dart';
import 'package:flutter_test/flutter_test.dart';

/// A minimal test-harness Cubit that mixes in [CartPricingMixin] directly.
///
/// Demonstrates the "Write Once, Test Once" architectural principle:
/// pricing logic and reactive [computed] signals can be tested in complete
/// isolation without requiring hydrated storage, replay history, or UI widgets.
class TestCartCubit extends CubitSignal<ShoppingCartState>
    with CartPricingMixin {
  TestCartCubit({ShoppingCartState? initialState})
      : super(
          initialState: initialState ??
              (
                items: const IMap.empty(),
                promoCode: null,
                isCheckingOut: false,
              ),
        );

  void updateState(ShoppingCartState nextState) => emit(nextState);
}

void main() {
  group('CartPricingMixin Unit Tests', () {
    const book = CartItem(
      id: 'book',
      title: 'Design Patterns',
      price: 29.99,
      quantity: 1,
    );

    const keyboard = CartItem(
      id: 'keyboard',
      title: 'Mechanical Keyboard',
      price: 89.50,
      quantity: 2, // lineTotal = 179.00
    );

    test('evaluates empty cart initial values correctly', () {
      final cubit = TestCartCubit();
      addTearDown(cubit.close);

      expect(cubit.isCartEmpty.value, isTrue);
      expect(cubit.totalItemCount.value, 0);
      expect(cubit.subtotal.value, 0.0);
      expect(cubit.discountAmount.value, 0.0);
      expect(cubit.grandTotal.value, 0.0);
    });

    test(
      'recomputes subtotal and totalItemCount reactively as items change',
      () {
        final cubit = TestCartCubit();
        addTearDown(cubit.close);

        // Add 1 book
        cubit.updateState((
          items: IMap({'book': book}),
          promoCode: null,
          isCheckingOut: false,
        ));

        expect(cubit.isCartEmpty.value, isFalse);
        expect(cubit.totalItemCount.value, 1);
        expect(cubit.subtotal.value, 29.99);
        expect(cubit.grandTotal.value, 29.99);

        // Add keyboard (quantity 2)
        cubit.updateState((
          items: IMap({'book': book, 'keyboard': keyboard}),
          promoCode: null,
          isCheckingOut: false,
        ));

        expect(cubit.totalItemCount.value, 3);
        expect(cubit.subtotal.value, closeTo(208.99, 0.001));
        expect(cubit.grandTotal.value, closeTo(208.99, 0.001));
      },
    );

    test('applies percentage promo codes accurately (SAVE10 & HALF)', () {
      final cubit = TestCartCubit(
        initialState: (
          items: IMap({'book': book}), // 29.99
          promoCode: null,
          isCheckingOut: false,
        ),
      );
      addTearDown(cubit.close);

      // 10% discount
      cubit.updateState((
        items: cubit.stateValue.items,
        promoCode: 'SAVE10',
        isCheckingOut: false,
      ));
      expect(cubit.discountAmount.value, closeTo(2.999, 0.001));
      expect(cubit.grandTotal.value, closeTo(26.991, 0.001));

      // 50% discount
      cubit.updateState((
        items: cubit.stateValue.items,
        promoCode: 'HALF',
        isCheckingOut: false,
      ));
      expect(cubit.discountAmount.value, closeTo(14.995, 0.001));
      expect(cubit.grandTotal.value, closeTo(14.995, 0.001));
    });

    test('applies flat discount (FREESHIP) and clamps grandTotal at 0.0', () {
      final cubit = TestCartCubit(
        initialState: (
          items: IMap({
            'cheap': const CartItem(
              id: 'cheap',
              title: 'Sticker',
              price: 3.00,
              quantity: 1,
            ),
          }),
          promoCode: 'FREESHIP',
          isCheckingOut: false,
        ),
      );
      addTearDown(cubit.close);

      // FREESHIP is $5, but clamped to subtotal when subtotal <= $5
      expect(cubit.discountAmount.value, 3.00);
      expect(cubit.grandTotal.value, 0.0);
    });

    test('ignores unknown or whitespace-only promo codes', () {
      final cubit = TestCartCubit(
        initialState: (
          items: IMap({'book': book}),
          promoCode: 'INVALID_CODE',
          isCheckingOut: false,
        ),
      );
      addTearDown(cubit.close);

      expect(cubit.discountAmount.value, 0.0);
      expect(cubit.grandTotal.value, 29.99);

      cubit.updateState((
        items: cubit.stateValue.items,
        promoCode: '   ',
        isCheckingOut: false,
      ));
      expect(cubit.discountAmount.value, 0.0);
      expect(cubit.grandTotal.value, 29.99);
    });
  });
}
