# BlocSignal Interoperability Guide

This guide details how `BlocSignal` acts as the **universal synchronous state bridge** connecting the three primary Flutter state management ecosystems: **BLoC**, **Riverpod**, and **Provider** (`Listenable`).

Interoperability allows features built with different state management tools to live side-by-side in the same codebase, sharing state synchronously without forced rewrites or migration refactors.

---

## 🏗️ The Universal Interoperability Matrix

| Ecosystem / Primitive | From Target ➔ `BlocSignal` | From `BlocSignal` ➔ Target | Package |
| :--- | :--- | :--- | :--- |
| **Classic BLoC (`package:bloc`)** | `classicBloc.toBlocSignal()` / `classicCubit.toBlocSignal()` | `blocSignal.toClassicBloc()` / `cubitSignal.toClassicCubit()` | `bloc_signals_bloc` |
| **Dart Future (Raw Value `T`)** | `future.toBlocSignal(initialState: ...)` | `blocSignal.stream.first` | `bloc_signals` |
| **Dart Future (AsyncState)** | `future.toAsyncBlocSignal()` | `blocSignal.stream.first` | `bloc_signals` |
| **Dart Stream (Raw Value `T`)** | `stream.toBlocSignal(initialState: ...)` | `blocSignal.toStream()` / `blocSignal.stream` | `bloc_signals` |
| **Dart Stream (AsyncState)** | `stream.toAsyncBlocSignal()` | `blocSignal.toStream()` / `blocSignal.stream` | `bloc_signals` |
| **Signals Primitives** | `signal.toBlocSignal()` / `value.$.toBlocSignal()` | Direct `blocSignal.state` signal | `bloc_signals` |
| **Signals Computed** | `computedSignal.toBlocSignal()` | Direct `blocSignal.state` signal | `bloc_signals` |
| **Signals Async / StreamSignal** | `streamSignal.toBlocSignal()` | Direct `blocSignal.state` signal | `bloc_signals` |
| **Generic Stream / Redux** | `StreamBlocSignal(stream, initialState: ...)` | `blocSignal.toStream()` | `bloc_signals` |
| **Riverpod** | `provider.toBlocSignal(ref)` | `blocSignal.toProvider()` | `bloc_signals_riverpod` |
| **Provider (Listenable)** | `listenable.toBlocSignal()` | `blocSignal.toValueListenable()` | `bloc_signals_flutter` |
| **Riverpod Async** | `asyncValue.toAsyncState()` | `asyncState.toAsyncValue()` | `bloc_signals_riverpod` |
| **Flutter Hooks** | `useSignal(initial)` / `useSignalValue(signal)` | Direct `blocSignal.state` consumption | `signals_hooks` |


> [!TIP]
> **Custom Equality Support Across All Bridges**:
> All `.toBlocSignal()` and `.toAsyncBlocSignal()` extensions and adapter constructors (`SignalBlocSignal`, `FutureBlocSignal`, `StreamBlocSignal`, `ListenableBlocSignal`, `RiverpodBlocSignal`) accept an optional `equals: (prev, next) => ...` comparator parameter so you can customize state de-duplication rules (such as identity comparison `identical(prev, next)`) when bridging external state containers into `BlocSignal`.

---

## 1. Signals & Future Interoperability (`package:bloc_signals`)

Adapt raw signals, computed expressions, and asynchronous futures directly into synchronous `BlocSignalBase` containers:

### Signal & Computed ➔ `BlocSignal`
```dart
// 1. Raw Signal -> BlocSignal
final countSignal = signal<int>(0);
final countBloc = countSignal.toBlocSignal();

// 2. Computed Signal -> BlocSignal
final firstName = signal('Grace');
final lastName = signal('Hopper');
final fullNameBloc = computed(() => '${firstName()} ${lastName()}').toBlocSignal();

// 3. Lifted Primitive (.$) -> BlocSignal
final priceBloc = 49.99.$.toBlocSignal();
```

### Future ➔ `BlocSignal` (Pushing Async to the Boundary)
```dart
// 1. Raw State: Converts Future<T> to BlocSignalBase<T> with required initialState
final userBloc = api.fetchUser(id).toBlocSignal(initialState: User.anonymous());

// 2. Async State: Converts Future<T> to BlocSignalBase<AsyncState<T>>
final userProfileBloc = api.fetchUserProfile(userId).toAsyncBlocSignal();

// UI consumes the synchronous state transitions via BlocSignalBuilder:
BlocSignalBuilder(
  bloc: userProfileBloc,
  builder: (context, state) => switch (state) {
    AsyncData(:final value) => ProfileView(user: value),
    AsyncLoading() => const ShimmerLoading(),
    AsyncError(:final error) => ErrorCard(error: error),
  },
);
```

---

## 2. Classic BLoC 8/9 Interoperability (`package:bloc_signals_bloc`)

The dedicated `bloc_signals_bloc` package provides full bidirectional read-and-mutate bridges between classic `package:bloc` components (`Bloc`, `Cubit`, `BlocBase`) and modern `BlocSignal` containers:

### Classic BLoC ➔ `BlocSignal` (Bidirectional Read & Mutate)
```dart
import 'package:bloc_signals_bloc/bloc_signals_bloc.dart';

final classicBloc = CounterBloc();

// 1. Convert classic Bloc into a synchronous BlocSignal:
final blocSignal = classicBloc.toBlocSignal();

// Synchronous reactive read:
print(blocSignal.stateValue);

// Direct event dispatch forwarded to underlying classic Bloc:
blocSignal.add(const IncrementEvent());
```

### Classic Cubit ➔ `CubitSignal` (Bidirectional Read & Mutate)
```dart
final classicCubit = CounterCubit();

// 1. Convert classic Cubit into a synchronous CubitSignal:
final cubitSignal = classicCubit.toBlocSignal();

// Synchronous reactive read:
print(cubitSignal.stateValue);

// Direct typed method invocation on underlying Cubit:
cubitSignal.cubit.increment();
```

### Modern `BlocSignal` ➔ Classic BLoC (Legacy UI Compatibility)
Drop modern streamless `BlocSignal` or `CubitSignal` containers directly into legacy `flutter_bloc` UI widgets without rewriting existing presentation trees:

```dart
final modernBloc = ModernCounterBloc();

// Adapt into a classic Bloc instance:
final classicAdapter = modernBloc.toClassicBloc();

// Consumed directly by legacy flutter_bloc widgets:
BlocBuilder<BlocSignalToClassicBloc<CounterEvent, int>, int>(
  bloc: classicAdapter,
  builder: (context, state) => Text('$state'),
);
```

---

## 3. Generic Stream & Redux Interoperability (`package:bloc_signals`)

Bridge raw streams, Redux stores, RxDart observables, or generic stream architectures:

### Stream / Redux ➔ `BlocSignal`
```dart
// 1. Raw State: Standard Stream / RxDart -> BlocSignalBase<T>
final streamBlocSignal = stream.toBlocSignal(initialState: 0);

// 2. Async State: Stream -> BlocSignalBase<AsyncState<T>>
final asyncStreamBloc = stream.toAsyncBlocSignal();

// 3. Redux Store -> BlocSignal
final reduxBlocSignal = store.onChange.toBlocSignal(
  initialState: store.state,
);
```

### `BlocSignal` ➔ Stream
```dart
final Stream<int> stream = myBlocSignal.toStream();
```

---

## 4. Riverpod Interoperability (`package:bloc_signals_riverpod`)

Bridge Riverpod providers, Notifiers, `ProviderContainer`, and `WidgetRef` instances with full bidirectional read-and-mutate support:

### Riverpod Provider ➔ `BlocSignal` (Read & Mutate)
```dart
// 1. Adapts Riverpod NotifierProvider to RiverpodNotifierBlocSignal<Notifier, State>
final counterBloc = counterProvider.toBlocSignal(ref);

// Synchronous reactive state access:
print(counterBloc.stateValue); // 0

// Direct mutation via typed .notifier getter:
counterBloc.notifier.increment();

// Auto-disposal binds to ref lifecycle:
// ref.onDispose(counterBloc.close); is automatically registered!
```

### `BlocSignal` ➔ Riverpod `NotifierProvider` (Read & Mutate)
```dart
// 1. Adapts Cubit/Bloc to Riverpod NotifierProvider
final countCubit = CounterCubit();
final counterProvider = countCubit.toProvider();

// In Riverpod UI / Widget:
Widget build(BuildContext context, WidgetRef ref) {
  // Read state reactively:
  final count = ref.watch(counterProvider);
  
  // Mutate via typed .cubit or .bloc notifier aliases:
  return ElevatedButton(
    onPressed: () => ref.read(counterProvider.notifier).cubit.increment(),
    child: Text('Count: $count'),
  );
}
```

### `AsyncValue` (Riverpod Sealed Class) ↔ `AsyncState` (Signals)
```dart
final AsyncState<T> signalsState = riverpodAsyncValue.toAsyncState();
final AsyncValue<T> riverpodValue = signalsAsyncState.toAsyncValue();
```

---

## 5. Flutter `Listenable` & `package:provider` Interoperability (`package:bloc_signals_flutter`)

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
Exposes a `ValueListenable<T>` for Flutter's `ValueListenableBuilder` or `package:provider`:

```dart
final ValueListenable<int> listenable = myBlocSignal.toValueListenable();

// 1. Consume state T via package:provider's ValueListenableProvider
ValueListenableProvider<int>.value(
  value: listenable,
  child: Builder(
    builder: (context) {
      final count = context.watch<int>();
      return Text('$count');
    },
  ),
);

// 2. Consume state T via Flutter's built-in ValueListenableBuilder
ValueListenableBuilder<int>(
  valueListenable: listenable,
  builder: (context, value, child) {
    return Text('$value');
  },
);
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

---

## 🛡️ Migrating Away from FutureBuilder & StreamBuilder (Quarantining Async at the Perimeter)

Embedding `FutureBuilder` or `StreamBuilder` directly inside widget `build()` methods introduces raw execution time, socket lifecycle, and accidental network refetches on every rebuild frame into the presentation layer.

With `BlocSignal`, asynchronous operations are quarantined at the architectural perimeter:

### 1. Migrating `FutureBuilder<T>` ➔ `Future.toAsyncBlocSignal()`

```dart
// ❌ ANTI-PATTERN: Raw Future instantiated inside Flutter build()
class LegacyProfilePage extends StatelessWidget {
  const LegacyProfilePage({super.key, required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile>(
      future: api.fetchUserProfile(userId), // ⚠️ DANGER: Re-invoked on every rebuild
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }
        return ProfileContent(profile: snapshot.data!);
      },
    );
  }
}

// ✅ BLOCSIGNAL PATTERN: Synchronous projection of asynchronous state
class ModernProfilePage extends StatelessWidget {
  const ModernProfilePage({super.key, required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => api.fetchUserProfile(userId).toAsyncBlocSignal(),
      child: BlocSignalBuilder<BlocSignalBase<AsyncState<UserProfile>>, AsyncState<UserProfile>>(
        builder: (context, state) => switch (state) {
          AsyncData(:final value) => ProfileContent(profile: value),
          AsyncLoading() => const CircularProgressIndicator(),
          AsyncError(:final error) => Text('Error: $error'),
        },
      ),
    );
  }
}
```

### 2. Migrating `StreamBuilder<T>` ➔ `Stream.toBlocSignal()`

```dart
// ❌ ANTI-PATTERN: Stream subscription lifecycle entangled with widget tree
StreamBuilder<int>(
  stream: sensorService.temperatureStream,
  builder: (context, snapshot) {
    if (!snapshot.hasData) return const CircularProgressIndicator();
    return Text('${snapshot.data}°C');
  },
);

// ✅ BLOCSIGNAL PATTERN: Clean synchronous container with automatic de-duplication
final tempBloc = sensorService.temperatureStream.toBlocSignal(initialState: 0);

BlocSignalBuilder(
  bloc: tempBloc,
  builder: (context, temp) => Text('$temp°C'),
);
```
