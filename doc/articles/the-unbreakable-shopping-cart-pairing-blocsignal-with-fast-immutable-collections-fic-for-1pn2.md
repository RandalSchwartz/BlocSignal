---
series: "BlocSignal Architecture & Practice"
title: "The Unbreakable Shopping Cart: Pairing BlocSignal with Fast Immutable Collections (FIC) for Bulletproof Flutter Apps"
published: true
description: Eliminate in-place mutation bugs, corrupted undo stacks, defensive copying overhead, and skipped Flutter rebuilds by pairing BlocSignal with fast_immutable_collections.
tags: flutter, dart, architecture, statemanagement
---

## The Most Dangerous Line of Code in Flutter

Every Flutter developer has stared at this bug in disbelief:

A user taps "Add to Cart". The button ripple animates. Your logger prints the updated item. The network request returns HTTP 200. And yet... **the screen completely refuses to update.** The badge stays at `0`, the total stays `$0.00`, and the UI sits there, completely frozen—until you accidentally tap an unrelated text field or switch tabs, and the items suddenly flash into existence.

Or even worse: you build a slick "Undo" button for swiped items. You tap "Undo", and to your horror, your time-travel history stack is completely corrupted. Past state snapshots in memory secretly changed because they were pointing to the exact same mutable list as the present!

In Flutter state management, the single most dangerous line of code you can write is not an unhandled `Future` or a rogue null pointer. It is this:

```dart
state.items.add(newItem); // 💀 The ghost rebuild trap!
```

Standard Dart collections (`List`, `Set`, and `Map`) are silent ticking time bombs inside reactive architectures. They compare by memory pointer rather than contents, they can be mutated in-place by any layer of your app, and the moment you try to protect yourself with defensive spread copies (`[...state.items, newItem]`), you pay a brutal tax: allocating and copying thousands of array references on every keystroke, choking the garbage collector, and dropping 120 FPS frames.

**What if you could have it all?**
- **True value equality** (`[1, 2] == [1, 2]` evaluating to `true` out of the box).
- **Guaranteed compile-time immutability** (where in-place mutation bugs cannot even compile).
- **O(1) and O(log N) copy-on-write speed** via persistent structural sharing (zero garbage collection churn).
- **0ms synchronous state de-duplication** (dropping duplicate emissions in the exact same frame before a single pixel repaints).
- **And 100% boilerplate-free state classes**—*without* running `build_runner` for `freezed`, *without* writing 30 lines of `Equatable` props boilerplate, and defined in a **single line of Dart 3 record syntax**.

By pairing [**`BlocSignal`**](https://pub.dev/packages/bloc_signals) with Marcelo Glasberg's acclaimed [**`fast_immutable_collections`**](https://pub.dev/packages/fast_immutable_collections) (FIC), we can build an **Unbreakable Shopping Cart** and eliminate an entire category of client-side bugs forever.

Let us pull back the curtain on the crime scene, dissect the Four Horsemen of collection state bugs, and see how clean reactive architecture is supposed to look.

---

## The Four Horsemen of Collection State Bugs in Flutter

In reactive UI architecture, state management frameworks live or die by **state de-duplication**. When a state container receives a new emission, it must answer one fundamental question before touching a single pixel or notifying a single subscriber:

> *Has the state actually changed?*

In [**`BlocSignal`**](https://pub.dev/packages/bloc_signals), state transitions propagate **synchronously in the exact same frame**. The moment you call `emit(newState)` inside a `CubitSignal` or `BlocSignal`, the container performs an immediate equality check:

```dart
if (stateValue == newState) return;
```

If `stateValue == newState` evaluates to `true`, `BlocSignal` immediately drops the transition. It skips creating a `Change` object, skips executing `onChange` and `onTransition` lifecycle hooks, avoids notifying reactive `effect()` and `computed()` signals, and completely prevents downstream Flutter widgets from scheduling redundant build passes.

This synchronous de-duplication is the secret to 120 FPS performance in `BlocSignal`. 

However, when developers model domain state using standard Dart collections (`List`, `Set`, and `Map`), this entire de-duplication mechanism collides with a hidden architectural trap: **standard Dart collections do not implement value equality, and they are mutable by default.**

```dart
final listA = ['apple', 'banana'];
final listB = ['apple', 'banana'];

print(listA == listB); // FALSE! Standard List checks identity (identical memory address).
```

Because standard Dart collections compare memory references (`identical`) rather than their underlying contents, relying on them inside reactive state containers inevitably unleashes what we call **The Four Horsemen of Collection State Bugs**:

```plaintext
┌────────────────────────────────────────────────────────────────────────┐
│               THE FOUR HORSEMEN OF COLLECTION STATE BUGS               │
├──────────────────────────┬─────────────────────────────────────────────┤
│ 1. The Ghost Rebuild     │ In-place mutation (state.items.add(x)) has  │
│    (Skipped Rebuild)     │ identical identity: emit() drops the change │
│                          │ and Flutter's UI stays frozen!              │
├──────────────────────────┼─────────────────────────────────────────────┤
│ 2. Corrupted Undo Stack  │ Time-travel history buffers hold pointers   │
│    (Historical Amnesia)  │ to the same mutable list: mutating present  │
│                          │ silently corrupts past snapshots!           │
├──────────────────────────┼─────────────────────────────────────────────┤
│ 3. Defensive Copy Tax    │ Writing [...state.items, x] copies N items  │
│    (Garbage Collector)   │ on every keystroke: memory spikes and 120Hz │
│                          │ frame drops.                                │
├──────────────────────────┼─────────────────────────────────────────────┤
│ 4. Concurrent Mutation   │ ListView.builder iterates while an async    │
│    Crash                 │ handler modifies the list in-place: throws  │
│                          │ ConcurrentModificationError at runtime.     │
└──────────────────────────┴─────────────────────────────────────────────┘
```

Let us examine these four failure modes before seeing how the solution completely eliminates them.

---

### 1. The Ghost Rebuild (The Skipped Rebuild)

Consider a junior or mid-level developer building a shopping cart. They write what looks like completely reasonable Dart code:

```dart
class CartCubit extends CubitSignal<CartState> {
  CartCubit() : super(initialState: CartState(items: []));

  void addItem(Item item) {
    // ❌ In-place mutation bug!
    stateValue.items.add(item);
    emit(stateValue);
  }
}
```

What happens when `addItem` runs?
1. `stateValue.items.add(item)` mutates the existing `List` instance in heap memory.
2. `emit(stateValue)` passes the mutated state back into `CubitSignal`.
3. `BlocSignalBase` evaluates `if (stateValue == newState) return;`.
4. Because `stateValue` and `newState` point to the **exact same memory address** (`identical(a, b) == true`), the check evaluates to `true`!
5. `BlocSignal` assumes nothing changed and **drops the emission**.

The Flutter UI never receives a notification. Downstream `BlocSignalBuilder` and `SignalBuilder` widgets do not rebuild. The user taps "Add to Cart", nothing visibly happens, and the screen looks frozen until some unrelated user interaction (for example focusing a text field or navigating tabs) triggers an accidental ancestor rebuild that finally reveals the updated items.

---

### 2. The Corrupted Undo Stack (Historical Amnesia)

Modern applications frequently require undo/redo capabilities (for example "Undo Remove Item" in a cart, or undoing canvas edits). The `bloc_signals_replay` package provides this via `ReplayCubitSignal` and `ReplayBlocSignal`, maintaining an internal history buffer of past states.

If your state holds a standard mutable `List`:

```dart
// History Stack initially:
// [ State0(items: ['Book']) ]

cubit.addItem('Pen'); 
// If implemented with in-place mutation or shallow objects sharing the list:
// History Stack becomes:
// [ State0(items: ['Book', 'Pen']), State1(items: ['Book', 'Pen']) ]
```

Because `State0` held a reference to the same mutable list object, mutating the list for `State1` secretly and retroactively mutated `State0` in the history buffer!

When the user taps "Undo", `ReplayCubitSignal` steps back to `State0`—but `State0` already contains the mutated list! The undo button either does nothing or restores an already-corrupted state. The historical timeline has been permanently poisoned.

---

### 3. The Defensive Copying Tax (Garbage Collector Jitter)

Aware of in-place mutation bugs, conscientious developers learn to write "defensive copies" using the spread operator (`...`):

```dart
void addItem(Item item) {
  emit(CartState(items: [...stateValue.items, item]));
}
```

While this fixes the identity equality bug, it introduces a severe performance penalty:
- If your cart, table, or catalog has 2,000 items, adding one item allocates a brand new 2,001-element array in memory and copies all 2,000 references one by one (O(N) memory reallocation).
- In a fast search field or interactive filter where updates occur on every keystroke, copying 2,000 items 10 times per second allocates tens of thousands of temporary object references.
- Dart's garbage collector (GC) is forced to perform frequent generational scavenger cycles, causing micro-stutters and dropped frames during 120 FPS animations.

---

### 4. The Concurrent Modification Crash

Because standard Dart collections are mutable, any asynchronous operation (`await http.get(...)`) leaves a time window where a background event can mutate the collection while a Flutter widget is in the middle of reading or iterating over it.

If Flutter's `ListView.builder` is reading `state.items[index]` while a web socket message triggers `state.items.removeAt(0)`, Dart throws a fatal runtime exception:

```plaintext
Concurrent modification during iteration: Instance of 'List<Item>'.
```

Your app crashes in production over a fundamental flaw in collection architecture.

---

## Enter Fast Immutable Collections (FIC)

To permanently cure these issues, we do not need complex code generators, heavyweight reflection, or cumbersome boilerplate. We simply need proper data structures.

[`package:fast_immutable_collections`](https://pub.dev/packages/fast_immutable_collections) (FIC), created by Flutter author and GDE Marcelo Glasberg, introduces pure, persistent, immutable collection types for Dart: **`IList`**, **`ISet`**, and **`IMap`**.

Unlike Dart's built-in `List.unmodifiable`—which is merely a runtime wrapper that throws exceptions when you call `.add()` and still evaluates equality by reference identity—FIC collections are built from the ground up on persistent data structure theory:

```plaintext
                      TRADITIONAL MUTABLE LIST
           ┌──────────────────────────────────────────────┐
           │ ['apple', 'banana', 'cherry', 'date', ...]   │
           └───────────────────────┬──────────────────────┘
                                   │ [...items, 'egg'] (O(N) full copy)
                                   ▼
           ┌─────────────────────────────────────────────────────┐
           │ ['apple', 'banana', 'cherry', 'date', ..., 'egg']   │
           └─────────────────────────────────────────────────────┘
                 (Entire array reallocated in new memory heap)


                FIC PERSISTENT DATA STRUCTURE (IList)
                               [Root]
                              /      \
                        [Node A]    [Node B]
                        /      \
                  ['apple']  ['banana']
                                   │ .add('cherry') (O(1) / O(log N))
                                   ▼
                               [New Root]
                              /          \
                       (Shares Node A)  [New Node C]
                                       /            \
                                 ['banana']     ['cherry']
            (Zero defensive copying! Unchanged nodes shared in memory)
```

### Why FIC is the Ideal Partner for BlocSignal:

1. **True Structural Value Equality Out of the Box**:
   ```dart
   final list1 = ['apple', 'banana'].lock;
   final list2 = ['apple', 'banana'].lock;

   print(list1 == list2); // TRUE! Evaluates contents, not memory address!
   ```
   Because `IList` and `IMap` implement value equality directly in `operator ==`, `BlocSignal`'s synchronous `if (stateValue == newState) return;` check works automatically with zero extra code!

2. **Structural Sharing & O(1) / O(log N) Mutations**:
   When you call `list.add(item)` or `map.remove(key)`, FIC does not duplicate the underlying elements. It creates a new root node in a persistent AVL tree or radix tree, sharing all unmodified subtrees with the previous collection. Mutations are blisteringly fast and create virtually zero garbage collection pressure.

3. **Guaranteed Compile-Time Immutability**:
   `IList` simply does not have mutable mutating methods that return `void`. You cannot write `list.add(x)` and expect the original list to change in-place. Methods like `.add()`, `.remove()`, and `.replace()` return a *new* `IList`, making in-place mutation bugs impossible to write.

4. **Cached Hash Codes & Identity Shortcuts**:
   FIC caches hash codes once computed and leverages identity checks (`identical(a, b)`) as an instant O(1) fast path before falling back to structural comparison. If two collection instances share an identical subtree or root, comparison is instantaneous.

---

## Pattern 1: The Pure Collection Cubit (Zero-Boilerplate State)

When your state machine is simply an observable collection of entities (for example a list of tasks, tags, or IDs), you do not even need to create a dedicated state class. You can parameterize `CubitSignal` directly with `IList<T>`:

### Modern Dart 3.13 Syntax:

```dart
import 'package:bloc_signals/bloc_signals.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';

class TodoListCubit() extends CubitSignal<IList<String>> {
  this : super(initialState: const IList.empty());

  void addTodo(String text) {
    emit(stateValue.add(text));
  }

  void removeTodo(int index) {
    emit(stateValue.removeAt(index));
  }

  void reorder(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    final item = stateValue[oldIndex];
    final updated = stateValue.removeAt(oldIndex).insert(newIndex, item);
    emit(updated);
  }
}
```

### Traditional Dart 3.5 Baseline Syntax:

```dart
import 'package:bloc_signals/bloc_signals.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';

class TodoListCubit extends CubitSignal<IList<String>> {
  TodoListCubit() : super(initialState: const IList.empty());

  void addTodo(String text) {
    emit(stateValue.add(text));
  }

  void removeTodo(int index) {
    emit(stateValue.removeAt(index));
  }

  void reorder(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    final item = stateValue[oldIndex];
    final updated = stateValue.removeAt(oldIndex).insert(newIndex, item);
    emit(updated);
  }
}
```

### The Magic of 0ms De-Duplication in Action

Look closely at what happens when a developer calls `reorder(2, 2)` or attempts to remove an item that does not exist:

```dart
final cubit = TodoListCubit();
cubit.addTodo('Buy groceries');

// Attempt to remove an item not in the list:
cubit.emit(cubit.stateValue.remove('Read book'));
```

In standard Dart `List`, `[...items]..remove('Read book')` creates a brand new `List` object. Because standard lists compare by identity reference, `cubit.emit()` would treat this as a brand new state, triggering an unnecessary UI rebuild across the entire screen!

With `fast_immutable_collections`:
1. `stateValue.remove('Read book')` detects that the item was not present and returns the unchanged `IList`.
2. `emit()` runs `if (stateValue == newState) return;`.
3. The check evaluates to `true` in 0ms!
4. The emission is dropped instantly. Downstream widgets do not rebuild, and `BlocSignalObserver` logs zero false-positive state transitions.

---

## Pattern 2: The Ultimate State Combo — Dart 3 Records + FIC

Real-world application state is rarely just a single collection; it often includes query filters, loading flags, pagination tokens, or error messages.

Traditionally, modeling this required choosing between two painful compromises:
1. **The Boilerplate Tax (`Equatable`)**: Writing manual `props` arrays for every state class. Forgetting to add a single collection field to `props` silently breaks equality.
2. **The Build Runner Tax (`freezed`)**: Adding `@freezed`, running `dart run build_runner watch`, waiting 45 seconds for thousands of lines of generated `.freezed.dart` code, and dealing with git merge conflicts on generated files.

By pairing **Dart 3 Records** with **Fast Immutable Collections**, you achieve 100% type-safe, immutable, value-equal state classes in a **single line of code**:

```dart
// Zero code generation. Zero Equatable. 100% Value Equality & Immutability.
typedef FilteredTodosState = ({
  IList<String> todos,
  ISet<String> selectedTags,
  bool isLoading,
});
```

Why does this work so cleanly?
- Dart 3 records synthesize `operator ==` and `hashCode` automatically based on the structural equality of their component fields.
- Because `IList` and `ISet` implement value equality, the record compares the collections by value rather than identity!
- Modifying a field is as simple as using record syntax:

### Modern Dart 3.13 Syntax:

```dart
class FilteredTodosCubit() extends CubitSignal<FilteredTodosState> {
  this : super(
    initialState: (
      todos: const IList.empty(),
      selectedTags: const ISet.empty(),
      isLoading: false,
    ),
  );

  void toggleTag(String tag) {
    final tags = stateValue.selectedTags;

    emit((
      todos: stateValue.todos,
      selectedTags: tags.toggle(tag),
      isLoading: stateValue.isLoading,
    ));
  }
}
```

### Traditional Dart 3.5 Baseline Syntax:

```dart
class FilteredTodosCubit extends CubitSignal<FilteredTodosState> {
  FilteredTodosCubit()
      : super(
          initialState: (
            todos: const IList.empty(),
            selectedTags: const ISet.empty(),
            isLoading: false,
          ),
        );

  void toggleTag(String tag) {
    final tags = stateValue.selectedTags;

    emit((
      todos: stateValue.todos,
      selectedTags: tags.toggle(tag),
      isLoading: stateValue.isLoading,
    ));
  }
}
```

Notice how FIC even provides a native `.toggle(item)` method directly on `ISet` and `IList`! Instead of writing repetitive `tags.contains(tag) ? tags.remove(tag) : tags.add(tag)` ternaries, FIC handles membership toggling internally with persistent structural sharing. And because Dart records compare their fields using value equality, any redundant emission is dropped synchronously by `BlocSignal` in 0ms!

---

## Pattern 3: The Unbreakable Shopping Cart Showcase

Let us now engineer a complete, production-grade e-commerce shopping cart.

In enterprise applications, shopping carts are notorious bug magnets:
- Users rapidly tap `+` and `-` quantity buttons, creating race conditions.
- Items must be indexed by ID for instantaneous O(1) lookups and updates.
- Total price and item count must be computed declaratively without manual tallying callbacks.
- The cart must survive app restarts through offline persistence.
- Users expect an "Undo Remove" action that must never corrupt previous state history.

Here is the complete domain model and `CubitSignal` implementation:

```dart
import 'package:bloc_signals/bloc_signals.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/foundation.dart';

/// Immutable domain item model using standard Dart value equality.
@immutable
class CartItem {
  const CartItem({
    required this.id,
    required this.title,
    required this.price,
    this.quantity = 1,
  });

  final String id;
  final String title;
  final double price;
  final int quantity;

  double get lineTotal => price * quantity;

  CartItem copyWith({int? quantity}) => CartItem(
    id: id,
    title: title,
    price: price,
    quantity: quantity ?? this.quantity,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          price == other.price &&
          quantity == other.quantity;

  @override
  int get hashCode => Object.hash(id, title, price, quantity);
}

/// Zero-boilerplate composite state using Dart 3 records and FIC IMap.
typedef ShoppingCartState = ({
  IMap<String, CartItem> items,
  String? promoCode,
  bool isCheckingOut,
});
```

Now, look at the `ShoppingCartCubit`. Notice how inline `late final` signals derive computed business metrics declaratively directly from the underlying immutable map:

### Modern Dart 3.13 Syntax:

```dart
class ShoppingCartCubit() extends CubitSignal<ShoppingCartState> {
  this : super(
    initialState: (
      items: const IMap.empty(),
      promoCode: null,
      isCheckingOut: false,
    ),
  );

  // ✨ Declarative derived signals: computed once and cached lazily!
  late final subtotal = computed(() {
    return stateValue.items.values.fold(0.0, (sum, item) => sum + item.lineTotal);
  });

  late final totalItemCount = computed(() {
    return stateValue.items.values.fold(0, (sum, item) => sum + item.quantity);
  });

  late final isCartEmpty = computed(() {
    return stateValue.items.isEmpty;
  });

  void addItem(CartItem item) {
    final existing = stateValue.items[item.id];
    final updatedItem = existing != null
        ? existing.copyWith(quantity: existing.quantity + item.quantity)
        : item;

    emit((
      items: stateValue.items.add(item.id, updatedItem),
      promoCode: stateValue.promoCode,
      isCheckingOut: stateValue.isCheckingOut,
    ));
  }

  void updateQuantity(String itemId, int newQuantity) {
    if (newQuantity <= 0) {
      removeItem(itemId);
      return;
    }

    final existing = stateValue.items[itemId];
    if (existing == null || existing.quantity == newQuantity) return;

    emit((
      items: stateValue.items.add(itemId, existing.copyWith(quantity: newQuantity)),
      promoCode: stateValue.promoCode,
      isCheckingOut: stateValue.isCheckingOut,
    ));
  }

  void removeItem(String itemId) {
    if (!stateValue.items.containsKey(itemId)) return;

    emit((
      items: stateValue.items.remove(itemId),
      promoCode: stateValue.promoCode,
      isCheckingOut: stateValue.isCheckingOut,
    ));
  }

  void clearCart() {
    if (stateValue.items.isEmpty) return;

    emit((
      items: const IMap.empty(),
      promoCode: null,
      isCheckingOut: false,
    ));
  }
}
```

### Traditional Dart 3.5 Baseline Syntax:

```dart
class ShoppingCartCubit extends CubitSignal<ShoppingCartState> {
  ShoppingCartCubit()
      : super(
          initialState: (
            items: const IMap.empty(),
            promoCode: null,
            isCheckingOut: false,
          ),
        );

  // ✨ Declarative derived signals: computed once and cached lazily!
  late final subtotal = computed(() {
    return stateValue.items.values.fold(0.0, (sum, item) => sum + item.lineTotal);
  });

  late final totalItemCount = computed(() {
    return stateValue.items.values.fold(0, (sum, item) => sum + item.quantity);
  });

  late final isCartEmpty = computed(() {
    return stateValue.items.isEmpty;
  });

  void addItem(CartItem item) {
    final existing = stateValue.items[item.id];
    final updatedItem = existing != null
        ? existing.copyWith(quantity: existing.quantity + item.quantity)
        : item;

    emit((
      items: stateValue.items.add(item.id, updatedItem),
      promoCode: stateValue.promoCode,
      isCheckingOut: stateValue.isCheckingOut,
    ));
  }

  void updateQuantity(String itemId, int newQuantity) {
    if (newQuantity <= 0) {
      removeItem(itemId);
      return;
    }

    final existing = stateValue.items[itemId];
    if (existing == null || existing.quantity == newQuantity) return;

    emit((
      items: stateValue.items.add(itemId, existing.copyWith(quantity: newQuantity)),
      promoCode: stateValue.promoCode,
      isCheckingOut: stateValue.isCheckingOut,
    ));
  }

  void removeItem(String itemId) {
    if (!stateValue.items.containsKey(itemId)) return;

    emit((
      items: stateValue.items.remove(itemId),
      promoCode: stateValue.promoCode,
      isCheckingOut: stateValue.isCheckingOut,
    ));
  }

  void clearCart() {
    if (stateValue.items.isEmpty) return;

    emit((
      items: const IMap.empty(),
      promoCode: null,
      isCheckingOut: false,
    ));
  }
}
```

### Why This Architecture is "Unbreakable"

1. **Zero Defensive Copying**: When you add an item, `items.add(id, item)` updates an immutable trie node in O(log N) time. The rest of the map is reused without memory reallocations.
2. **Instant Derived Math**: The UI does not recalculate subtotals or item counts inside `Widget.build()`. The `subtotal` and `totalItemCount` signals evaluate lazily only when requested, caching their results until `items` changes.
3. **Flawless Flutter Rebuilds**:
   In your Flutter view, you read the cubit via `context.read<ShoppingCartCubit>()` and surgically bind the subtotal badge using `SignalBuilder`:

   ```dart
   class CartBadge extends StatelessWidget {
     const CartBadge({super.key});

     @override
     Widget build(BuildContext context) {
       final cubit = context.read<ShoppingCartCubit>();

       return SignalBuilder(
         builder: (context) {
           final count = cubit.totalItemCount.value;
           return Badge(
             isLabelVisible: count > 0,
             label: Text('$count'),
             child: const Icon(Icons.shopping_bag_outlined),
           );
         },
       );
     }
   }
   ```
   Updating the quantity of an item will re-evaluate `totalItemCount`, causing *only* the `CartBadge` widget to rebuild—leaving the rest of the checkout page untouched!

---

### Pairing with `bloc_signals_hydrate` (Persistent Carts)

In production apps, the shopping cart must survive app terminations. Using `package:bloc_signals_hydrate`, adding persistence requires merely mixing in `HydratedMixin` and defining JSON mappings:

```dart
class HydratedCartCubit extends CubitSignal<ShoppingCartState>
    with HydratedMixin<ShoppingCartState> {
  HydratedCartCubit()
      : super(
          initialState: (
            items: const IMap.empty(),
            promoCode: null,
            isCheckingOut: false,
          ),
        ) {
    hydrate(); // Restores cached cart synchronously on startup!
  }

  @override
  Map<String, dynamic>? toJson(ShoppingCartState state) {
    return {
      'promoCode': state.promoCode,
      'items': state.items.unlock.map(
        (key, item) => MapEntry(key, {
          'id': item.id,
          'title': item.title,
          'price': item.price,
          'quantity': item.quantity,
        }),
      ),
    };
  }

  @override
  ShoppingCartState? fromJson(dynamic data) {
    // 🛡️ Robust first-level pattern matching: crash-proof schema validation!
    if (data case {'items': final Map<String, dynamic> rawItems}) {
      final restoredItems = <String, CartItem>{};

      for (final MapEntry(:key, :value) in rawItems.entries) {
        if (value case {
          'id': final String id,
          'title': final String title,
          'price': final num price,
          'quantity': final int quantity,
        }) {
          restoredItems[key] = CartItem(
            id: id,
            title: title,
            price: price.toDouble(),
            quantity: quantity,
          );
        }
      }

      return (
        items: restoredItems.lock,
        promoCode: data case {'promoCode': final String promo} ? promo : null,
        isCheckingOut: false,
      );
    }
    return null;
  }
}
```

Because `state.items.unlock` provides a read-only Dart map view without copying elements, serializing to SQLite, Hive, or shared preferences is completely seamless. Moreover, pairing `fromJson(dynamic data)` with Dart 3 pattern matching guarantees that corrupted or partial local disk caches never trigger runtime `TypeError` crashes on startup.

---

### Pairing with `bloc_signals_replay` (Bulletproof Undo / Redo)

Now observe what happens when you want to provide an "Undo" feature when a customer accidentally swipes away an item:

```dart
class ReplayableCartCubit extends ReplayCubitSignal<ShoppingCartState> {
  ReplayableCartCubit()
      : super(
          initialState: (
            items: const IMap.empty(),
            promoCode: null,
            isCheckingOut: false,
          ),
        );

  void removeItem(String id) {
    emit((
      items: stateValue.items.remove(id),
      promoCode: stateValue.promoCode,
      isCheckingOut: stateValue.isCheckingOut,
    ));
  }
}
```

When the user taps "Undo" on a SnackBar:

```dart
cubit.undo();
```

Because `stateValue.items` is an immutable `IMap`, previous state snapshots in the `ReplayCubitSignal` history buffer were **never mutated**. Calling `cubit.undo()` restores the previous snapshot with 100% mathematical integrity. The history stack is physically uncorruptible!

---

## Pattern 4: The One-Liner Zero-Mock Testing Secret

When writing unit tests for state machines that depend on collection repositories, developers frequently waste days setting up mocking frameworks like `mockito` or `mocktail`. They mock repository interfaces, stub return values, and write complex verifications.

With `BlocSignal` and `fast_immutable_collections`, testing becomes refreshingly direct. Because `IList` and `IMap` can be converted into reactive state containers in a single line using `.toBlocSignal()`, you can construct real, deterministic, immutable test fixtures without a single line of mock code:

```dart
// ✨ One-liner deterministic test fixture: zero mocks needed!
final testCartSignal = [item1, item2].lock.toBlocSignal();
```

Here is a complete, declarative unit test suite using `package:bloc_signals_test`:

```dart
import 'package:bloc_signals_test/bloc_signals_test.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:test/test.dart';

void main() {
  group('ShoppingCartCubit Architecture Tests', () {
    const book = CartItem(id: '1', title: 'Dart Handbook', price: 29.99);
    const keyboard = CartItem(id: '2', title: 'Mechanical Keyboard', price: 99.00);

    test('derived computed signals calculate subtotals and counts correctly', () {
      final cubit = ShoppingCartCubit();

      expect(cubit.isCartEmpty.value, isTrue);
      expect(cubit.subtotal.value, equals(0.0));
      expect(cubit.totalItemCount.value, equals(0));

      cubit.addItem(book);

      expect(cubit.isCartEmpty.value, isFalse);
      expect(cubit.subtotal.value, equals(29.99));
      expect(cubit.totalItemCount.value, equals(1));

      // Adding the same item increments quantity rather than duplicating map keys
      cubit.addItem(book);
      expect(cubit.totalItemCount.value, equals(2));
      expect(cubit.subtotal.value, equals(59.98));
    });

    blocSignalTest<ShoppingCartCubit, ShoppingCartState>(
      'synchronously drops duplicate quantity updates in 0ms',
      build: () => ShoppingCartCubit(),
      seed: () => (
        items: IMap({'1': book}),
        promoCode: null,
        isCheckingOut: false,
      ),
      act: (cubit) {
        // Setting the exact same quantity that already exists:
        cubit.updateQuantity('1', 1);
      },
      // Because IMap equality evaluates as identical, zero transitions emit!
      expect: () => <ShoppingCartState>[],
    );

    blocSignalTest<ShoppingCartCubit, ShoppingCartState>(
      'removes item cleanly and updates state',
      build: () => ShoppingCartCubit(),
      seed: () => (
        items: IMap({'1': book, '2': keyboard}),
        promoCode: null,
        isCheckingOut: false,
      ),
      act: (cubit) => cubit.removeItem('1'),
      expect: () => [
        (
          items: IMap({'2': keyboard}),
          promoCode: null,
          isCheckingOut: false,
        ),
      ],
    );
  });
}
```

Notice what just happened in the de-duplication test:
- We seeded the cubit with a state containing `book` with quantity 1.
- We called `updateQuantity('1', 1)`.
- `cubit.updateQuantity` attempted to emit an identical state.
- `blocSignalTest` asserted that **zero transitions occurred** (`expect: () => []`).

All of this executed synchronously in 0ms without waiting for microtask queues or timer intervals!

---

## Architectural Comparison Table

To understand why pairing `BlocSignal` with `fast_immutable_collections` represents such a leap forward in Flutter architecture, consider how it compares to traditional approaches:

| Architectural Metric | Standard `List` / `Map` | `Equatable` + `List` | `freezed` + `List` | `BlocSignal` + FIC (`IList` / `IMap`) |
| :--- | :--- | :--- | :--- | :--- |
| **Value Equality (`==`)** | ❌ Reference identity only | ⚠️ Manual `props` definition | ✅ Generated in `.freezed.dart` | ✅ **Automatic out of the box** |
| **In-Place Mutation Defense** | ❌ None (accidental mutations pass) | ❌ None (runtime mutable) | ⚠️ Unmodifiable wrapper (runtime crash) | ✅ **Enforced by type system at compile-time** |
| **Code Generation Overhead** | ✅ None | ✅ None | ❌ Heavy (`build_runner` required) | ✅ **Zero (`build_runner` free)** |
| **Mutation Performance** | ❌ O(N) full defensive copy | ❌ O(N) full defensive copy | ❌ O(N) full defensive copy | ✅ **O(1) / O(log N) structural sharing** |
| **Garbage Collection (GC) Pressure** | ❌ High (allocates N items per change) | ❌ High (allocates N items per change) | ❌ High (allocates N items per change) | ✅ **Near-zero (tree node sharing)** |
| **Time-Travel / Undo Safety** | ❌ Corrupts historical stack | ❌ Corrupts historical stack | ⚠️ Requires deep cloning | ✅ **100% mathematically safe** |
| **Synchronous 0ms De-duplication** | ❌ Fails (triggers ghost or redundant rebuilds) | ⚠️ Works if `props` are maintained | ✅ Works | ✅ **Instantaneous 0ms frame-0 drop** |

---

## Conclusion: Composition Over Framework Monoliths

In the early days of Flutter, solving collection state bugs required bringing in heavy, monolithic code generation tools like `freezed` or writing endless boilerplate with `Equatable`.

Modern Dart and `BlocSignal` show us a better way forward. By composing focused, specialized, pure Dart tools:
1. **`BlocSignal`** provides unidirectional data flow, frame-0 synchronous propagation, and enterprise observer tracing.
2. **`fast_immutable_collections`** provides structural sharing, compile-time immutability, and instant value equality.
3. **Dart 3 Records** provide zero-ceremony composite state types with automatic structural equality.

You get an unbreakable, 120 FPS reactive architecture with **zero code generation, zero macro dependencies, and zero runtime reflection**.

Try replacing a mutable `List` with an `IList` in your next Flutter feature—your UI, your undo stack, and your garbage collector will thank you!

---

### 🔗 Resources & Getting Started
- 📦 **`bloc_signals` on pub.dev**: [pub.dev/packages/bloc_signals](https://pub.dev/packages/bloc_signals)
- 📦 **`fast_immutable_collections` on pub.dev**: [pub.dev/packages/fast_immutable_collections](https://pub.dev/packages/fast_immutable_collections)
- 🌐 **Official Documentation & Recipes**: [blocsignal.dev](https://blocsignal.dev)
- 🐙 **GitHub Repository**: [github.com/RandalSchwartz/BlocSignal](https://github.com/RandalSchwartz/BlocSignal)
