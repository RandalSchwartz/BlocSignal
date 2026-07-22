# `bloc_signals_riverpod`

Bidirectional interoperability adapters and extensions connecting `BlocSignal` / `CubitSignal` state containers with [Riverpod](https://riverpod.dev) providers.

---

## ⚡ Features

- **`ProviderListenable.toBlocSignal(refOrContainer)`**: Convert any Riverpod `ProviderListenable` (`Notifier`, `Provider`, `.select()`) into a `BlocSignalBase`.
- **Automatic `ref.onDispose` Registration**: Passing `ref` into `toBlocSignal(ref)` automatically binds `ref.onDispose(bloc.close)` for zero-boilerplate lifecycle management.
- **`BlocSignalBase.toProvider()`**: Expose any `BlocSignal` or `CubitSignal` as a standard Riverpod `Provider<T>`.
- **Universal Riverpod Support**: Built for `riverpod: ">=2.5.0 <4.0.0"`, supporting Riverpod 2.x and Riverpod 3.x.

---

## 🚀 Usage

### 1. Riverpod → `BlocSignal`

Adapt any Riverpod provider into a `BlocSignalBase` inside a Riverpod provider using `ref`:

```dart
import 'package:bloc_signals_riverpod/bloc_signals_riverpod.dart';

final userNotifierProvider = NotifierProvider<UserNotifier, User>(UserNotifier.new);

// Convert Riverpod provider to BlocSignal container with automatic ref.onDispose binding
final userBlocProvider = Provider.autoDispose<BlocSignalBase<User>>((ref) {
  return userNotifierProvider.toBlocSignal(ref);
});
```

Or using a pure `ProviderContainer`:

```dart
final container = ProviderContainer();
final riverpodBloc = userNotifierProvider.toBlocSignal(container);

// State is in sync with Riverpod!
print(riverpodBloc.stateValue);

// Clean up subscription when finished:
riverpodBloc.close();
```

---

### 2. `BlocSignal` → Riverpod

Expose a `BlocSignalBase` state container as a standard Riverpod `Provider`:

```dart
import 'package:bloc_signals_riverpod/bloc_signals_riverpod.dart';

final counterCubit = CounterCubit();

// Convert to Riverpod Provider
final counterProvider = counterCubit.toProvider();

// Watch in Riverpod context:
final count = ref.watch(counterProvider);
```

---

## 🔄 Lifecycle & AutoDispose Semantics

Understanding the disposal relationship between Riverpod and `BlocSignal` is essential for memory safety:

| Direction | Mechanism | Lifecycle Coupling |
| :--- | :--- | :--- |
| **Riverpod → `BlocSignal`** <br> (`toBlocSignal`) | Creates an active `ProviderSubscription` via `container.listen()`. | **Coupled**: Holding `RiverpodBlocSignal` open retains an `autoDispose` Riverpod provider. Calling `toBlocSignal(ref)` automatically registers `ref.onDispose(bloc.close)` to release the Riverpod provider when the scope unmounts. |
| **`BlocSignal` → Riverpod** <br> (`toProvider()`) | Subscribes to `blocSignal.state` via `state.subscribe()`. | **Uncoupled (One-way Observer)**: Disposing the Riverpod provider detaches its listener cleanly via `ref.onDispose`, leaving the underlying `BlocSignal` instance completely untouched. |
