# Enterprise FIC Shopping Cart Example

An enterprise-ready Flutter e-commerce shopping cart demonstrating **`BlocSignal`** paired with Marcelo Glasberg's **`fast_immutable_collections` (FIC)**, offline JSON persistence via **`bloc_signals_hydrate`**, and uncorruptible undo/redo with **`bloc_signals_replay`**.

> Read the full architectural masterclass on DEV.to:  
> [**The Unbreakable Shopping Cart: Pairing BlocSignal with Fast Immutable Collections (FIC) for Bulletproof Flutter Apps**](https://dev.to/gde/the-unbreakable-shopping-cart-pairing-blocsignal-with-fast-immutable-collections-fic-for-1pn2)

---

## 🚀 Key Architectural Highlights

### 1. Fast Immutable Collections (`IMap`)
Standard Dart mutable collections (`List`, `Map`, `Set`) compare references (`identical`) rather than contents. In Flutter reactive architecture, in-place mutations lead to:
- Skipped widget rebuilds (the container sees `state == newState` and drops emissions).
- Corrupted undo/redo history buffers (past state snapshots mutate retroactively).
- Heavy $O(N)$ garbage collection pressure caused by defensive copying (`[...items]`).

By using `IMap<String, CartItem>`, collections gain:
- **True Value Equality**: Structural equality out-of-the-box without `Equatable` props or `build_runner`.
- **$O(1)$ / $O(\log N)$ Copy-on-Write**: Persistent data structures (radix tries and AVL trees) reuse existing nodes, eliminating defensive copying overhead.

### 2. Synchronous Derived Signals (`computed`)
Derived metrics like `subtotal`, `totalItemCount`, and `isCartEmpty` are computed declaratively as signals rather than recalculated in `Widget.build()`:

```dart
late final subtotal = computed(() {
  return stateValue.items.values.fold(0.0, (sum, item) => sum + item.lineTotal);
});

late final totalItemCount = computed(() {
  return stateValue.items.values.fold(0, (sum, item) => sum + item.quantity);
});
```

Widgets listening via `SignalBuilder` or `context.select` only rebuild when their observed signal changes.

### 3. Crash-Proof Offline Hydration (`HydratedMixin`)
State is saved to local storage seamlessly. When restoring state from cache, Dart 3 first-level pattern matching guarantees that schema migrations or partially corrupted disk entries never crash the app:

```dart
@override
ShoppingCartState? fromJson(dynamic data) {
  if (data case {'items': final Map<String, dynamic> rawItems}) {
    final restored = <String, CartItem>{};
    for (final MapEntry(:key, :value) in rawItems.entries) {
      final parsed = CartItem.fromJson(value);
      if (parsed != null) restored[key] = parsed;
    }
    return (items: restored.lock, promoCode: data['promoCode'] as String?, isCheckingOut: false);
  }
  return null;
}
```

### 4. Uncorruptible Undo / Redo (`ReplayCubitMixin`)
Because past state snapshots contain immutable collections, invoking `cubit.undo()` or `cubit.redo()` restores previous states with 100% mathematical integrity.

---

## 🏃‍♂️ Running the Example

Run the app with Flutter:

```bash
cd examples/fic_shopping_cart
flutter run
```

Run tests:

```bash
flutter test
```
