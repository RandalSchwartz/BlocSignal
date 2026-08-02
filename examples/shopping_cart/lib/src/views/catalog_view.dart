import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import '../cart/cart_bloc.dart';
import '../catalog/catalog_cubit.dart';
import '../models/models.dart';

class CatalogView extends StatelessWidget {
  const CatalogView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catalog'),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () => Navigator.of(context).pushNamed('/cart'),
          ),
        ],
      ),
      body: BlocSignalBuilder<CatalogCubit, List<Item>>(
        builder: (context, items) {
          if (items.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _CatalogListItem(item: item);
            },
          );
        },
      ),
    );
  }
}

class _CatalogListItem extends StatelessWidget {
  const _CatalogListItem({required this.item});

  final Item item;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        color: Colors.primaries[item.id % Colors.primaries.length],
      ),
      title: Text(item.name),
      subtitle: Text('\$${item.price.toStringAsFixed(2)}'),
      trailing: BlocSignalSelector<CartBloc, CartState, bool>(
        selector: (state) {
          if (state case CartLoaded(:final cart)) {
            return cart.items.contains(item);
          }
          return false;
        },
        builder: (context, isInCart) {
          return IconButton(
            icon: isInCart
                ? const Icon(Icons.check, color: Colors.green)
                : const Icon(Icons.add_shopping_cart),
            onPressed: isInCart
                ? null
                : () {
                    context.read<CartBloc>().add(CartItemAdded(item));
                  },
          );
        },
      ),
    );
  }
}
