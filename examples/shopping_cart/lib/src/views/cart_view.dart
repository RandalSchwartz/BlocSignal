import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import '../cart/cart_bloc.dart';

class CartView extends StatelessWidget {
  const CartView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping Cart'),
      ),
      body: BlocSignalBuilder<CartBloc, CartState>(
        builder: (context, state) {
          switch (state) {
            case CartLoading():
              return const Center(child: CircularProgressIndicator());

            case CartError(:final message):
              return Center(child: Text('Error: $message'));

            case CartLoaded(:final cart):
              if (cart.items.isEmpty) {
                return const Center(child: Text('Your cart is empty.'));
              }
              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      itemCount: cart.items.length,
                      itemBuilder: (context, index) {
                        final item = cart.items[index];
                        return ListTile(
                          leading: const Icon(Icons.shopping_bag),
                          title: Text(item.name),
                          subtitle: Text('\$${item.price.toStringAsFixed(2)}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () {
                              context
                                  .read<CartBloc>()
                                  .add(CartItemRemoved(item));
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total (${cart.itemCount} items):',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '\$${cart.totalPrice.toStringAsFixed(2)}',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              );
          }
        },
      ),
    );
  }
}
