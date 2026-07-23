# BlocSignal Interoperability Guide

This guide details how `BlocSignal` acts as the **universal synchronous state bridge** connecting the three primary Flutter state management ecosystems: **BLoC**, **Riverpod**, and **Provider** (`Listenable`).

Interoperability allows features built with different state management tools to live side-by-side in the same codebase, sharing state synchronously without forced rewrites or migration refactors.

---

## 🏗️ The Interoperability Matrix

| Ecosystem | From Target ➔ `BlocSignal` | From `BlocSignal` ➔ Target | Package |
| :--- | :--- | :--- | :--- |
| **BLoC** (Stream) | `StreamBlocSignal(stream)` | `blocSignal.toStream()` | `bloc_signals` |
| **Redux** | `StreamBlocSignal(store.onChange, initialState: store.state)` | `blocSignal.toStream()` | `bloc_signals` |
| **Riverpod** | `provider.toBlocSignal(ref)` | `blocSignal.toProvider()` | `bloc_signals_riverpod` |
| **Provider** (Listenable) | `listenable.toBlocSignal()` | `blocSignal.toValueListenable()` | `bloc_signals_flutter` |
| **Riverpod Async** | `asyncValue.toAsyncState()` | `asyncState.toAsyncValue()` | `bloc_signals_riverpod` |

> [!TIP]
> **Custom Equality Support Across All Bridges**:
> All `.toBlocSignal()` extensions and adapter constructors (`StreamBlocSignal`, `ListenableBlocSignal`, `RiverpodBlocSignal`) accept an optional `equals: (prev, next) => ...` comparator parameter so you can customize state de-duplication rules (e.g. identity comparison `identical(prev, next)`) when bridging external state containers into `BlocSignal`.

---

## 1. BLoC, Redux & Stream Interoperability (`package:bloc_signals`)

Bridge classic stream-based BLoC components, Redux stores, RxDart observables, or `StreamBuilder` widgets:

### Stream / Redux ➔ `BlocSignal`
```dart
// Standard Stream / RxDart -> BlocSignal
final streamBlocSignal = StreamBlocSignal<int>(
  stream: legacyStream,
  initialState: 0,
);

// Redux Store -> BlocSignal
final reduxBlocSignal = StreamBlocSignal<AppState>(
  store.onChange,
  initialState: store.state,
);
```

### `BlocSignal` ➔ Stream
```dart
final Stream<int> stream = myBlocSignal.toStream();
```

---

## 2. Riverpod Interoperability (`package:bloc_signals_riverpod`)

Bridge Riverpod providers, Notifiers, `ProviderContainer`, and `WidgetRef` instances:

### Riverpod Provider ➔ `BlocSignal`
```dart
// Auto-registers ref.onDispose(bloc.close)
final blocSignal = riverpodProvider.toBlocSignal(ref);
```

### `BlocSignal` ➔ Riverpod `NotifierProvider`
```dart
final NotifierProvider<Notifier<int>, int> riverpodProvider = myBlocSignal.toProvider();
```

### `AsyncValue` (Riverpod 3 Sealed Class) ↔ `AsyncState` (Signals)
```dart
final AsyncState<T> signalsState = riverpodAsyncValue.toAsyncState();
final AsyncValue<T> riverpodValue = signalsAsyncState.toAsyncValue();
```

---

## 3. Flutter `Listenable` & `package:provider` Interoperability (`package:bloc_signals_flutter`)

Bridge Flutter's native `ChangeNotifier`, `ValueNotifier`, `AnimationController`, and `package:provider`:

### `Listenable` / `ValueListenable` ➔ `BlocSignal`
```dart
// ValueNotifier -> BlocSignal
final blocSignal = myValueNotifier.toBlocSignal();

// ChangeNotifier -> BlocSignal
final blocSignal = myChangeNotifier.toBlocSignal(
  readState: () => myChangeNotifier.state,
);
```

### `BlocSignal` ➔ `ValueListenable`
```dart
// Exposes ValueListenable for ValueListenableBuilder or ChangeNotifierProvider
final ValueListenable<int> listenable = myBlocSignal.toValueListenable();
```

---

## ✈️ Cross-Ecosystem State Bridges ("Changing Planes in BlocSignal")

You can bridge state across ecosystems in a single pipeline:

### Provider ➔ `BlocSignal` ➔ Riverpod
```dart
final cubit = changeNotifier.toBlocSignal(readState: () => changeNotifier.count);
final riverpodProvider = cubit.toProvider();
```

### Riverpod ➔ `BlocSignal` ➔ Provider
```dart
final cubit = riverpodProvider.toBlocSignal(ref);
final ValueListenable<int> listenable = cubit.toValueListenable();
```
