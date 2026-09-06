import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';

import '../cubit/shopping_cart_cubit.dart';
import '../cubit/shopping_cart_state.dart';

/// The interactive shopping cart view showing items, promo discounts,
/// and uncorruptible undo/redo operations.
class CartView extends StatelessWidget {
  /// Creates a [CartView].
  const CartView({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ShoppingCartCubit>();

    return BlocSignalBuilder<ShoppingCartCubit, ShoppingCartState>(
      builder: (context, state) {
        final items = state.items.values.toList();
        final isEmpty = cubit.isCartEmpty.value;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Shopping Cart'),
            actions: [
              IconButton(
                icon: const Icon(Icons.undo),
                tooltip: 'Undo last change',
                onPressed: cubit.canUndo ? cubit.undo : null,
              ),
              IconButton(
                icon: const Icon(Icons.redo),
                tooltip: 'Redo previous change',
                onPressed: cubit.canRedo ? cubit.redo : null,
              ),
              if (!isEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined),
                  tooltip: 'Clear Cart',
                  onPressed: () {
                    cubit.clearCart();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Cart cleared'),
                        duration: const Duration(seconds: 2),
                        action: SnackBarAction(
                          label: 'Undo',
                          onPressed: cubit.undo,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          body: isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.remove_shopping_cart_outlined,
                        size: 72,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Your cart is empty',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Explore our retro catalog and add products!',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.store),
                        label: const Text('Continue Shopping'),
                      ),
                    ],
                  ),
                )
              : CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = items[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.title,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '\$${item.price.toStringAsFixed(2)} each',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                              Icons.remove_circle_outline),
                                          onPressed: () => cubit.updateQuantity(
                                            item.id,
                                            item.quantity - 1,
                                          ),
                                        ),
                                        Text(
                                          '${item.quantity}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                              Icons.add_circle_outline),
                                          onPressed: () => cubit.updateQuantity(
                                            item.id,
                                            item.quantity + 1,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '\$${item.lineTotal.toStringAsFixed(2)}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.close),
                                          tooltip: 'Remove item',
                                          onPressed: () {
                                            cubit.removeItem(item.id);
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                    'Removed ${item.title}'),
                                                duration:
                                                    const Duration(seconds: 2),
                                                action: SnackBarAction(
                                                  label: 'Undo',
                                                  onPressed: cubit.undo,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          childCount: items.length,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Promo Codes',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                _PromoChip(
                                  label: 'SAVE10 (10% off)',
                                  code: 'SAVE10',
                                  currentCode: state.promoCode,
                                  onSelected: cubit.applyPromoCode,
                                ),
                                _PromoChip(
                                  label: 'HALF (50% off)',
                                  code: 'HALF',
                                  currentCode: state.promoCode,
                                  onSelected: cubit.applyPromoCode,
                                ),
                                _PromoChip(
                                  label: 'FREESHIP (\$5 off)',
                                  code: 'FREESHIP',
                                  currentCode: state.promoCode,
                                  onSelected: cubit.applyPromoCode,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Card(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    _PriceRow(
                                      label:
                                          'Subtotal (${cubit.totalItemCount.value} items)',
                                      value:
                                          '\$${cubit.subtotal.value.toStringAsFixed(2)}',
                                    ),
                                    if (cubit.discountAmount.value > 0) ...[
                                      const SizedBox(height: 8),
                                      _PriceRow(
                                        label: 'Discount (${state.promoCode})',
                                        value:
                                            '-\$${cubit.discountAmount.value.toStringAsFixed(2)}',
                                        isDiscount: true,
                                      ),
                                    ],
                                    const Divider(height: 24),
                                    _PriceRow(
                                      label: 'Grand Total',
                                      value:
                                          '\$${cubit.grandTotal.value.toStringAsFixed(2)}',
                                      isTotal: true,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: FilledButton(
                                onPressed: state.isCheckingOut
                                    ? null
                                    : () async {
                                        cubit.setCheckingOut(true);
                                        await Future<void>.delayed(
                                          const Duration(seconds: 1),
                                        );
                                        cubit.setCheckingOut(false);
                                        if (context.mounted) {
                                          cubit.clearCart();
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  '🎉 Order placed successfully!'),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                          Navigator.of(context).pop();
                                        }
                                      },
                                child: state.isCheckingOut
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Proceed to Checkout',
                                        style: TextStyle(fontSize: 16),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _PromoChip extends StatelessWidget {
  const _PromoChip({
    required this.label,
    required this.code,
    required this.currentCode,
    required this.onSelected,
  });

  final String label;
  final String code;
  final String? currentCode;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final isSelected = currentCode == code;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        onSelected(selected ? code : null);
      },
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.value,
    this.isDiscount = false,
    this.isTotal = false,
  });

  final String label;
  final String value;
  final bool isDiscount;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    TextStyle? style = Theme.of(context).textTheme.bodyMedium;
    if (isTotal) {
      style = Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          );
    } else if (isDiscount) {
      style = style?.copyWith(
        color: Colors.green.shade700,
        fontWeight: FontWeight.w600,
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(value, style: style),
      ],
    );
  }
}
