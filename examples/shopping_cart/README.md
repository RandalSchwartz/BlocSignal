# Shopping Cart Example (`BlocSignal`)

A classic shopping cart and catalog application demonstrating multi-bloc coordination and immutable cart state transitions with `BlocSignal`.

## ✨ Features

- **Multi-Bloc Architecture**: Coordinates `CatalogCubit` (providing product catalog data) with `CartBloc` (managing customer cart items and total calculations).
- **Immutable State Transitions**: Items are added and removed with pure, immutable state calculations (`cart.addItem`, `cart.removeItem`).
- **Responsive Cart Badge & Checkout**: Synchronously updates the app bar badge and checkout total summary across views.
- **Sealed Cart State**: Type-safe loading, loaded, and error representations handled via pattern matching.

## 🔗 Upstream Reference

- Inspired by the [flutter_shopping_cart](https://bloclibrary.dev/tutorials/flutter-shopping-cart/) tutorial from `felangel/bloc`.

## 🚀 Running the Example

```bash
cd examples/shopping_cart
flutter run
```

## 🧪 Running Tests

```bash
cd examples/shopping_cart
flutter test
```
