import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';

import '../../cubit/shopping_cart_cubit.dart';

/// Surgical reactive cart badge showing total items using [SignalBuilder].
class CartBadge extends StatelessWidget {
  /// Creates a [CartBadge].
  const CartBadge({
    required this.onPressed,
    super.key,
  });

  /// Action when the badge or cart button is tapped.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final count = context.select<ShoppingCartCubit, int>(
      (cubit) => cubit.totalItemCount.value,
    );

    return IconButton(
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: const Icon(Icons.shopping_cart_outlined),
      ),
      tooltip: 'View Shopping Cart',
      onPressed: onPressed,
    );
  }
}
