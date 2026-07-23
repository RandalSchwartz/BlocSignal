# ⚡ bloc_signals_riverpod

> *"With the rigor of Bloc and the flex and speed of Signal"*

Bidirectional interoperability adapters and extensions connecting `BlocSignal` / `CubitSignal` state containers with [Riverpod](https://riverpod.dev) providers.

Supports both **Riverpod 2.x** and **Riverpod 3.x** out of the box.

---

## 🌐 Ecosystem Packages

| Package | Purpose | Pub.dev Link |
| :--- | :--- | :--- |
| **`bloc_signals`** | Core pure-Dart state containers, event registry, & VM Service telemetry | 📦 [pub.dev](https://pub.dev/packages/bloc_signals) |
| **`bloc_signals_flutter`** | Flutter UI widgets (`BlocSignalProvider`, `BlocSignalBuilder`, `BlocSignalListener`, `BlocSignalConsumer`, `BlocSignalSelector`) | 📦 [pub.dev](https://pub.dev/packages/bloc_signals_flutter) |
| **`bloc_signals_riverpod`** | Bidirectional Riverpod interop adapters (`toBlocSignal(ref)`, `toProvider()`) | 📦 [pub.dev](https://pub.dev/packages/bloc_signals_riverpod) |
| **`bloc_signals_hydrate`** | Persistent state storage (`HydratedCubitSignal`, `HydratedBlocSignal`) | 📦 [pub.dev](https://pub.dev/packages/bloc_signals_hydrate) |
| **`bloc_signals_devtools`** | Dedicated Flutter DevTools extension inspector UI | 📦 [pub.dev](https://pub.dev/packages/bloc_signals_devtools) |
| **`bloc_signals_test`** | Declarative unit testing helpers (`blocSignalTest`) | 📦 [pub.dev](https://pub.dev/packages/bloc_signals_test) |
| **`bloc_signals_lint`** | Static analysis lints & IDE quick-fixes | 📦 [pub.dev](https://pub.dev/packages/bloc_signals_lint) |
| **`otel_bloc_signals`** | OpenTelemetry tracing observers | 📦 [pub.dev](https://pub.dev/packages/otel_bloc_signals) |

---

## ⚡ Key Features

- 🔄 **`ProviderListenable.toBlocSignal(refOrContainer)`**: Convert any Riverpod `ProviderListenable` (`Notifier`, `Provider`, `.select()`) into a `BlocSignalBase`.
- 🔒 **Automatic `ref.onDispose` Registration**: Passing `ref` into `toBlocSignal(ref)` automatically binds `ref.onDispose(bloc.close)` for zero-boilerplate lifecycle management.
- 🔀 **`BlocSignalBase.toProvider()`**: Expose any `BlocSignal` or `CubitSignal` as a standard Riverpod `Provider<T>`.
- ⚡ **Universal Riverpod Support**: Built for `riverpod: ">=2.5.0 <4.0.0"`, supporting Riverpod 2.x and Riverpod 3.x seamlessly.

---

## 🚀 Getting Started

Add `bloc_signals_riverpod` to your `pubspec.yaml`:

```yaml
dependencies:
  riverpod: ^2.5.0 # or ^3.0.0
  bloc_signals: ^0.2.5
  bloc_signals_riverpod: ^0.1.0
```

---

## 💡 Quick Examples

### 1. Riverpod → `BlocSignal` (Inside Provider)

Adapt any Riverpod provider into a `BlocSignalBase` inside a Riverpod provider using `ref`:

```dart
import 'package:bloc_signals_riverpod/bloc_signals_riverpod.dart';
import 'package:riverpod/riverpod.dart';

final userNotifierProvider = NotifierProvider<UserNotifier, User>(UserNotifier.new);

// Convert Riverpod provider to BlocSignal container with automatic ref.onDispose binding
final userBlocProvider = Provider.autoDispose<BlocSignalBase<User>>((ref) {
  return userNotifierProvider.toBlocSignal(ref);
});
```

### 2. Riverpod → `BlocSignal` (Container)

Using a standalone `ProviderContainer`:

```dart
final container = ProviderContainer();
final riverpodBloc = userNotifierProvider.toBlocSignal(container);

// State is synchronously in sync with Riverpod!
print(riverpodBloc.stateValue);

// Clean up subscription when finished:
riverpodBloc.close();
```

### 3. `BlocSignal` → Riverpod

Expose a `BlocSignalBase` state container as a standard Riverpod `Provider`:

```dart
import 'package:bloc_signals_riverpod/bloc_signals_riverpod.dart';
import 'package:riverpod/riverpod.dart';

final counterCubit = CounterCubit();

// Convert to Riverpod Provider
final counterProvider = counterCubit.toProvider();

// Watch in Riverpod context:
final count = ref.watch(counterProvider);
```

---

## 🔄 Lifecycle & AutoDispose Semantics

| Direction | Mechanism | Lifecycle Coupling |
| :--- | :--- | :--- |
| **Riverpod → `BlocSignal`** <br> (`toBlocSignal`) | Creates an active `ProviderSubscription` via `container.listen()`. | **Coupled**: Holding `RiverpodBlocSignal` open retains an `autoDispose` Riverpod provider. Calling `toBlocSignal(ref)` automatically registers `ref.onDispose(bloc.close)` to release the Riverpod provider when the scope unmounts. |
| **`BlocSignal` → Riverpod** <br> (`toProvider()`) | Subscribes to `blocSignal.state` via `state.subscribe()`. | **Uncoupled (One-way Observer)**: Disposing the Riverpod provider detaches its listener cleanly via `ref.onDispose`, leaving the underlying `BlocSignal` instance completely untouched. |
