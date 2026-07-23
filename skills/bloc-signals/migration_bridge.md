# Progressive Migration Bridge Guide (`Stream` & `BlocSignal` Interop)

`bloc_signals` provides seamless, bidirectional stream interop extensions so you can adopt `BlocSignal` incrementally in existing Flutter codebases without rewriting legacy BLoC business logic or UI widgets all at once.

---

## 🔄 Bidirectional Interop Summary

| Conversion | Extension Method | Use Case |
| :--- | :--- | :--- |
| **`BlocSignal` -> `Stream`** | `blocSignal.toStream()` / `blocSignal.stream` | Consume state updates from a `BlocSignal` using standard `StreamBuilder`, RxDart, or legacy `BlocBuilder`. |
| **`Stream` / BLoC -> `BlocSignal`** | `legacyStream.toBlocSignal(initialState: ...)` | Wrap any standard Dart `Stream` or legacy `Bloc`/`Cubit` stream in a `BlocSignal` container for consumption in `BlocSignalBuilder` or reactive signals. |

---

## 1. Consuming `BlocSignal` in Legacy Stream / `BlocBuilder` Widgets

If you migrate a backend container to `BlocSignal` but want to keep existing UI widgets unchanged during early migration:

```dart
import 'package:bloc_signals/bloc_signals.dart';

final myBlocSignal = CounterBloc();

// 1. Standard Dart StreamBuilder
// (Store stream reference in initState or a State field to preserve stream identity across builds)
late final stream = myBlocSignal.toStream();

StreamBuilder<int>(
  stream: stream,
  builder: (context, snapshot) => Text('${snapshot.data}'),
);

// 2. RxDart / Stream transformations
myBlocSignal.toStream()
    .debounceTime(const Duration(milliseconds: 300))
    .listen((state) => print('Debounced: $state'));
```

---

## 2. Consuming Legacy BLoC / Cubits in `BlocSignalBuilder`

If you want to use reactive `BlocSignalBuilder` or signal effects with an existing legacy `Bloc` or `Cubit`:

```dart
import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';

final legacyBloc = LegacyCounterBloc();

// Convert legacy BLoC stream into a BlocSignal container
final blocSignal = legacyBloc.stream.toBlocSignal(
  initialState: legacyBloc.state,
);

// Consume directly in Flutter UI via BlocSignalBuilder
BlocSignalBuilder<StreamBlocSignal<int>, int>(
  bloc: blocSignal as StreamBlocSignal<int>,
  builder: (context, count) => Text('Count: $count'),
);
```

---

## 3. Automatic Cleanup

`StreamBlocSignal` automatically listens to the underlying stream when instantiated and cancels its stream subscription when `close()` is called on the container:

```dart
final signalContainer = legacyBloc.stream.toBlocSignal(initialState: legacyBloc.state);

// When done:
await signalContainer.close(); // Subscription cleanly cancelled!
```

---

## ⚠️ Common Interop Gotchas

1. **Do not call `.toStream()` inline in `build()`**: Returns a new `Stream` instance on every build pass, forcing `StreamBuilder` to re-subscribe and reset state. Store the stream in a `State` field / `initState()`.
2. **Do not call `.toBlocSignal(...)` inline in `build()`**: Subscribes to the underlying stream on creation. Creating instances inline in `build()` leaks subscriptions on every rebuild. Instantiate once in `initState()` and call `.close()` in `dispose()`.
