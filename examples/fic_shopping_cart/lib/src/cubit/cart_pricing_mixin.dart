import 'package:bloc_signals/bloc_signals.dart';
import 'package:signals_core/signals_core.dart';

import 'shopping_cart_state.dart';

/// A domain-specific pricing and promotional mixin targeted onto [CubitSignal]
/// holding [ShoppingCartState].
///
/// Encapsulates derived calculation logic such as item counts, subtotal,
/// promotional discounts, and grand totals into a clean, reusable component.
///
/// By targeting `on CubitSignal<ShoppingCartState>`, this mixin gains safe,
/// typed access to [CubitSignal.stateValue] while keeping domain pricing logic
/// completely decoupled from cart storage (hydration) or time-travel (replay).
///
/// ```dart
/// class MyCartCubit extends CubitSignal<ShoppingCartState>
///     with CartPricingMixin {
///   MyCartCubit()
///     : super(
///         initialState: (
///           items: const IMap.empty(),
///           promoCode: null,
///           isCheckingOut: false,
///         ),
///       );
/// }
/// ```
mixin CartPricingMixin on CubitSignal<ShoppingCartState> {
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
}
