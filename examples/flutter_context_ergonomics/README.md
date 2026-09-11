# Flutter Context Ergonomics Example

A runnable Flutter application demonstrating modern contextual ergonomics in `BlocSignal`:
- `context.value<B, S>()` for 1-line reactive element state subscription.
- Scoped micro-rebuilds using standard Flutter `Builder`.
- `context.state<B, S>()` for multi-container signal composition inside `Watch()`.
- Zero-closure provider tearoffs (`Cubit.create`).
- Side-by-side comparison matrix with classic `flutter_bloc`.

---

## 🚀 Running the Example

From the root of the workspace or this directory:

```bash
flutter run -d chrome # or macos, ios, android
```

Run automated widget tests:

```bash
flutter test
```

---

## 🎯 Key Patterns Demonstrated

### 1. Zero-Closure Provider Tearoffs (`Cubit.create`)

Instead of writing anonymous closures:

```dart
// ❌ Verbose lambda:
BlocSignalProvider<CartCubit>(create: (context) => CartCubit())

// ✅ Zero-closure constructor tearoff:
BlocSignalProvider<CartCubit>(create: CartCubit.create)
```

### 2. Single-Line Reads with `context.value`

Instead of wrapping widgets with `BlocBuilder`:

```dart
// ❌ Classic flutter_bloc builder pyramid:
BlocBuilder<CartCubit, CartState>(
  builder: (context, state) => Text('Items: ${state.totalCount}'),
)

// ✅ Modern BlocSignal 1-line read:
final cart = context.value<CartCubit, CartState>();
Text('Items: ${cart.totalCount}');
```

### 3. Multi-Cubit Reactive Composition with `context.state` and `Watch`

Instead of multi-bloc builders or nested listening trees:

```dart
final cartSignal = context.state<CartCubit, CartState>();
final userSignal = context.state<UserCubit, UserState>();

return Watch((context) {
  final subtotal = cartSignal.value.subtotal;
  final discount = userSignal.value.isVip ? (subtotal * 0.20) : 0.0;
  return Text('Total: \$${subtotal - discount}');
});
```
