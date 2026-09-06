import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';
import 'package:flutter/material.dart';

import 'src/cubit/shopping_cart_cubit.dart';
import 'src/views/catalog_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize in-memory storage for persistent hydration across sessions.
  HydratedStorage.storage = MemoryHydratedStorage();

  runApp(const UnbreakableShoppingCartApp());
}

/// Root application widget for the Enterprise FIC Shopping Cart example.
class UnbreakableShoppingCartApp extends StatelessWidget {
  /// Creates an [UnbreakableShoppingCartApp].
  const UnbreakableShoppingCartApp({
    this.storageOverride,
    super.key,
  });

  /// Optional storage override for testing.
  final HydratedStorage? storageOverride;

  @override
  Widget build(BuildContext context) {
    return BlocSignalProvider<ShoppingCartCubit>(
      create: (_) => ShoppingCartCubit(storageOverride: storageOverride),
      child: MaterialApp(
        title: 'Unbreakable Shopping Cart (FIC + BlocSignal)',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.light,
          ),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.dark,
          ),
        ),
        home: const CatalogView(),
      ),
    );
  }
}
