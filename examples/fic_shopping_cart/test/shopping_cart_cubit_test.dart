import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';
import 'package:bloc_signals_test/bloc_signals_test.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:fic_shopping_cart_example/src/cubit/shopping_cart_cubit.dart';
import 'package:fic_shopping_cart_example/src/cubit/shopping_cart_state.dart';
import 'package:fic_shopping_cart_example/src/models/cart_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MemoryHydratedStorage storage;

  setUp(() {
    storage = MemoryHydratedStorage();
  });

  group('ShoppingCartCubit', () {
    const item1 = CartItem(
      id: 'item_1',
      title: 'Retro Floppy Disk',
      price: 4.99,
      quantity: 1,
    );

    const item2 = CartItem(
      id: 'item_2',
      title: 'Neon Speed Cube',
      price: 14.50,
      quantity: 2,
    );

    test('initial state is completely empty', () {
      final cubit = ShoppingCartCubit(storageOverride: storage);
      addTearDown(cubit.close);

      expect(cubit.stateValue.items, const IMap<String, CartItem>.empty());
      expect(cubit.stateValue.promoCode, isNull);
      expect(cubit.stateValue.isCheckingOut, isFalse);

      expect(cubit.isCartEmpty.value, isTrue);
      expect(cubit.totalItemCount.value, 0);
      expect(cubit.subtotal.value, 0.0);
      expect(cubit.grandTotal.value, 0.0);
    });

    blocSignalTest<ShoppingCartCubit, ShoppingCartState>(
      'addItem adds new item and increments existing item quantity',
      build: () => ShoppingCartCubit(storageOverride: storage),
      act: (cubit) {
        cubit.addItem(item1);
        cubit.addItem(item1); // Duplicate ID -> increments quantity
      },
      verify: (cubit) {
        expect(cubit.stateValue.items.length, 1);
        expect(cubit.stateValue.items['item_1']?.quantity, 2);
        expect(cubit.totalItemCount.value, 2);
        expect(cubit.subtotal.value, closeTo(9.98, 0.001));
        expect(cubit.isCartEmpty.value, isFalse);
      },
    );

    blocSignalTest<ShoppingCartCubit, ShoppingCartState>(
      'updateQuantity updates count and removes when non-positive',
      build: () => ShoppingCartCubit(storageOverride: storage)..addItem(item1),
      act: (cubit) {
        cubit.updateQuantity('item_1', 5);
        expect(cubit.stateValue.items['item_1']?.quantity, 5);
        cubit.updateQuantity('item_1', 0); // Triggers removal
      },
      verify: (cubit) {
        expect(cubit.stateValue.items.isEmpty, isTrue);
        expect(cubit.isCartEmpty.value, isTrue);
      },
    );

    blocSignalTest<ShoppingCartCubit, ShoppingCartState>(
      'removeItem removes specified item from cart',
      build: () => ShoppingCartCubit(storageOverride: storage)
        ..addItem(item1)
        ..addItem(item2),
      act: (cubit) => cubit.removeItem('item_1'),
      verify: (cubit) {
        expect(cubit.stateValue.items.containsKey('item_1'), isFalse);
        expect(cubit.stateValue.items.containsKey('item_2'), isTrue);
        expect(cubit.totalItemCount.value, 2);
      },
    );

    blocSignalTest<ShoppingCartCubit, ShoppingCartState>(
      'promo codes compute discounts correctly',
      build: () => ShoppingCartCubit(storageOverride: storage)..addItem(item2),
      act: (cubit) => cubit.applyPromoCode('SAVE10'),
      verify: (cubit) {
        expect(cubit.subtotal.value, 29.00);
        expect(cubit.discountAmount.value, closeTo(2.90, 0.001));
        expect(cubit.grandTotal.value, closeTo(26.10, 0.001));
      },
    );

    blocSignalTest<ShoppingCartCubit, ShoppingCartState>(
      'HALF and FREESHIP promo discounts calculate accurately',
      build: () => ShoppingCartCubit(storageOverride: storage)..addItem(item2),
      act: (cubit) {
        cubit.applyPromoCode('HALF');
        expect(cubit.discountAmount.value, 14.50);
        cubit.applyPromoCode('FREESHIP');
        expect(cubit.discountAmount.value, 5.00);
        cubit.applyPromoCode('INVALID');
        expect(cubit.discountAmount.value, 0.0);
      },
    );

    test('undo and redo operations maintain 100% uncorrupted state history',
        () {
      final cubit = ShoppingCartCubit(storageOverride: storage);
      addTearDown(cubit.close);

      expect(cubit.canUndo, isFalse);

      cubit.addItem(item1); // 1 item
      expect(cubit.canUndo, isTrue);
      expect(cubit.totalItemCount.value, 1);

      cubit.addItem(item2); // 1 + 2 = 3 items
      expect(cubit.totalItemCount.value, 3);

      // Perform Undo: item 2 addition is undone
      cubit.undo();
      expect(cubit.totalItemCount.value, 1);
      expect(cubit.stateValue.items.containsKey('item_2'), isFalse);
      expect(cubit.stateValue.items.containsKey('item_1'), isTrue);
      expect(cubit.canRedo, isTrue);

      // Perform Redo: item 2 is restored
      cubit.redo();
      expect(cubit.totalItemCount.value, 3);
      expect(cubit.stateValue.items.containsKey('item_2'), isTrue);

      // Perform Undo twice to return to empty cart
      cubit.undo();
      cubit.undo();
      expect(cubit.isCartEmpty.value, isTrue);
      expect(cubit.canUndo, isFalse);
    });

    test('toJson and fromJson serialize and hydrate correctly', () {
      final cubit = ShoppingCartCubit(storageOverride: storage);
      addTearDown(cubit.close);

      cubit.addItem(item1);
      cubit.applyPromoCode('SAVE10');

      final json = cubit.toJson(cubit.stateValue);
      expect(json, isNotNull);
      expect(json!['promoCode'], 'SAVE10');
      expect((json['items'] as Map)['item_1'], isNotNull);

      // Restore from json using another cubit
      final restoredCubit = ShoppingCartCubit(storageOverride: storage);
      addTearDown(restoredCubit.close);

      final restoredState = restoredCubit.fromJson(json);
      expect(restoredState, isNotNull);
      expect(restoredState!.promoCode, 'SAVE10');
      expect(restoredState.items['item_1']?.title, 'Retro Floppy Disk');
      expect(restoredState.items['item_1']?.price, 4.99);
    });

    test('fromJson safely handles corrupted or partial json', () {
      final cubit = ShoppingCartCubit(storageOverride: storage);
      addTearDown(cubit.close);

      expect(cubit.fromJson(null), isNull);
      expect(cubit.fromJson('invalid string'), isNull);
      expect(cubit.fromJson({'items': 'not a map'}), isNull);

      // Corrupted items map with missing fields is gracefully handled
      final partial = cubit.fromJson({
        'items': {
          'corrupted_item': {'id': 'corrupted', 'missing_title': true},
        },
      });
      expect(partial, isNotNull);
      expect(partial!.items.isEmpty, isTrue);
    });

    test('setCheckingOut updates checking out status', () {
      final cubit = ShoppingCartCubit(storageOverride: storage);
      addTearDown(cubit.close);

      expect(cubit.stateValue.isCheckingOut, isFalse);
      cubit.setCheckingOut(true);
      expect(cubit.stateValue.isCheckingOut, isTrue);
      cubit.setCheckingOut(false);
      expect(cubit.stateValue.isCheckingOut, isFalse);
    });
  });
}
