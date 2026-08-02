import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import 'src/cart/cart_bloc.dart';
import 'src/catalog/catalog_cubit.dart';
import 'src/views/cart_view.dart';
import 'src/views/catalog_view.dart';

void main() {
  runApp(const ShoppingCartApp());
}

class ShoppingCartApp extends StatelessWidget {
  const ShoppingCartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSignalProvider<CatalogCubit>(
      lazy: false,
      create: (context) => CatalogCubit()..loadCatalog(),
      child: BlocSignalProvider<CartBloc>(
        lazy: false,
        create: (context) => CartBloc()..add(const CartStarted()),
        child: MaterialApp(
          title: 'BlocSignal Shopping Cart',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            useMaterial3: true,
          ),
          initialRoute: '/',
          routes: {
            '/': (context) => const CatalogView(),
            '/cart': (context) => const CartView(),
          },
        ),
      ),
    );
  }
}
