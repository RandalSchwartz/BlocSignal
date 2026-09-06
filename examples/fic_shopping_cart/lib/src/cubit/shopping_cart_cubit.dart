import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';
import 'package:bloc_signals_replay/bloc_signals_replay.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:signals_core/signals_core.dart';

import '../models/cart_item.dart';
import 'shopping_cart_state.dart';

/// An enterprise-ready shopping cart cubit that combines:
/// 1. Fast Immutable Collections ([IMap]) for true value equality and O(1) mutations.
/// 2. [HydratedMixin] for offline state persistence.
/// 3. [ReplayCubitMixin] for uncorruptible time-travel undo and redo.
/// 4. Synchronous declarative [computed] signals for derived totals and counts.
///
/// ```dart
/// final cubit = ShoppingCartCubit();
/// cubit.addItem(const CartItem(id: '1', title: 'Widget', price: 9.99));
/// print(cubit.subtotal.value); // 9.99
/// cubit.undo();
/// print(cubit.isCartEmpty.value); // true
/// ```
class ShoppingCartCubit extends HydratedCubitSignal<ShoppingCartState>
    with ReplayCubitMixin<ShoppingCartState> {
  /// Creates a [ShoppingCartCubit] with an empty cart.
  ShoppingCartCubit({
    HydratedStorage? storageOverride,
    int? undoLimit,
  })  : _storageOverride = storageOverride,
        super(
          initialState: (
            items: const IMap.empty(),
            promoCode: null,
            isCheckingOut: false,
          ),
        ) {
    if (undoLimit != null) {
      limit = undoLimit;
    }
  }

  final HydratedStorage? _storageOverride;

  @override
  HydratedStorage? get storageOverride => _storageOverride;

  // ✨ Declarative derived signals: computed once and cached lazily!

  /// Total cost of items before promotional discounts.
  late final subtotal = computed(() {
    return stateValue.items.values.fold(
      0.0,
      (sum, item) => sum + item.lineTotal,
    );
  });

  /// Total count of physical units in the cart across all line items.
  late final totalItemCount = computed(() {
    return stateValue.items.values.fold(
      0,
      (sum, item) => sum + item.quantity,
    );
  });

  /// Whether the cart contains zero items.
  late final isCartEmpty = computed(() {
    return stateValue.items.isEmpty;
  });

  /// Discount amount applied by the current promotional code.
  late final discountAmount = computed(() {
    final code = stateValue.promoCode?.trim().toUpperCase();
    if (code == null || code.isEmpty) return 0.0;

    // Supported promo codes:
    // SAVE10: 10% off
    // HALF: 50% off
    // FREESHIP: $5 flat discount
    if (code == 'SAVE10') {
      return subtotal.value * 0.10;
    } else if (code == 'HALF') {
      return subtotal.value * 0.50;
    } else if (code == 'FREESHIP') {
      return subtotal.value > 5.0 ? 5.0 : subtotal.value;
    }
    return 0.0;
  });

  /// Grand total after discounts.
  late final grandTotal = computed(() {
    final total = subtotal.value - discountAmount.value;
    return total < 0.0 ? 0.0 : total;
  });

  /// Adds an item to the cart or increments its quantity if already present.
  void addItem(CartItem item) {
    final existing = stateValue.items[item.id];
    final updatedItem = existing != null
        ? existing.copyWith(quantity: existing.quantity + item.quantity)
        : item;

    emit((
      items: stateValue.items.add(item.id, updatedItem),
      promoCode: stateValue.promoCode,
      isCheckingOut: stateValue.isCheckingOut,
    ));
  }

  /// Updates the quantity of a specific item. Removes the item if quantity <= 0.
  void updateQuantity(String itemId, int newQuantity) {
    if (newQuantity <= 0) {
      removeItem(itemId);
      return;
    }

    final existing = stateValue.items[itemId];
    if (existing == null || existing.quantity == newQuantity) return;

    emit((
      items: stateValue.items.add(
        itemId,
        existing.copyWith(quantity: newQuantity),
      ),
      promoCode: stateValue.promoCode,
      isCheckingOut: stateValue.isCheckingOut,
    ));
  }

  /// Removes an item from the cart completely.
  void removeItem(String itemId) {
    if (!stateValue.items.containsKey(itemId)) return;

    emit((
      items: stateValue.items.remove(itemId),
      promoCode: stateValue.promoCode,
      isCheckingOut: stateValue.isCheckingOut,
    ));
  }

  /// Clears all items and active promo codes from the cart.
  void clearCart() {
    if (stateValue.items.isEmpty && stateValue.promoCode == null) return;

    emit((
      items: const IMap.empty(),
      promoCode: null,
      isCheckingOut: false,
    ));
  }

  /// Applies or clears a promotional discount code.
  void applyPromoCode(String? code) {
    final cleanCode = code?.trim();
    final effectiveCode =
        cleanCode == null || cleanCode.isEmpty ? null : cleanCode;
    if (stateValue.promoCode == effectiveCode) return;

    emit((
      items: stateValue.items,
      promoCode: effectiveCode,
      isCheckingOut: stateValue.isCheckingOut,
    ));
  }

  /// Initiates or completes a checkout flow.
  void setCheckingOut(bool isCheckingOut) {
    if (stateValue.isCheckingOut == isCheckingOut) return;

    emit((
      items: stateValue.items,
      promoCode: stateValue.promoCode,
      isCheckingOut: isCheckingOut,
    ));
  }

  @override
  Map<String, dynamic>? toJson(ShoppingCartState state) {
    return {
      'promoCode': state.promoCode,
      'items': state.items.unlock.map(
        (key, item) => MapEntry(key, item.toJson()),
      ),
    };
  }

  @override
  ShoppingCartState? fromJson(dynamic data) {
    if (data case {'items': final Map<String, dynamic> rawItems}) {
      final restoredItems = <String, CartItem>{};

      for (final MapEntry(:key, :value) in rawItems.entries) {
        final parsed = CartItem.fromJson(value);
        if (parsed != null) {
          restoredItems[key] = parsed;
        }
      }

      final promoCode = switch (data) {
        {'promoCode': final String promo} => promo,
        _ => null,
      };

      return (
        items: restoredItems.lock,
        promoCode: promoCode,
        isCheckingOut: false,
      );
    }
    return null;
  }
}
