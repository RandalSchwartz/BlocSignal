# ⚡ bloc_signals_hydrate

> *"With the rigor of Bloc and the flex and speed of Signal"*

State persistence and hydration adapters for `BlocSignal` state containers.

`HydratedCubitSignal` and `HydratedBlocSignal` automatically persist state changes to storage and restore state synchronously during container instantiation across app restarts.

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

- 📦 **`dynamic` / `Object?` JSON Support**: `fromJson(dynamic json)` and `toJson(StateType state)` accept primitives (`num`, `String`, `bool`, `List`, `Map`). Primitive states do **not** require map wrappers like `{"value": 42}`!
- ⚡ **Synchronous Initial Hydration**: State is restored synchronously during constructor execution—meaning initial widget builds render hydrated data immediately with **zero frame flicker**.
- 🛠️ **Zero-Dependency Default**: Ships with `MemoryHydratedStorage` for fast in-memory unit testing out-of-the-box.

---

## 🚀 Getting Started

Add `bloc_signals_hydrate` to your `pubspec.yaml`:

```yaml
dependencies:
  bloc_signals: ^0.2.5
  bloc_signals_hydrate: ^0.1.1
```

---

## 💡 Quick Examples

### 1. Primitive State Hydration (`HydratedCubitSignal`)

```dart
import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';

class CounterCubit extends HydratedCubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void increment() => emit(stateValue + 1);

  @override
  int? fromJson(dynamic json) => json as int?;

  @override
  dynamic toJson(int state) => state; // Return primitive directly!
}
```

### 2. Complex Object Hydration (`HydratedBlocSignal`)

```dart
import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';

class UserCubit extends HydratedCubitSignal<UserModel> {
  UserCubit() : super(initialState: UserModel.anonymous);

  @override
  UserModel? fromJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      return UserModel.fromJson(json);
    }
    return null;
  }

  @override
  dynamic toJson(UserModel state) => state.toJson();
}
```

### 3. Wiring Custom Storage (`SharedPreferences`)

```dart
import 'dart:convert';
import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesHydratedStorage implements HydratedStorage {
  SharedPreferencesHydratedStorage(this.prefs);
  final SharedPreferences prefs;

  @override
  dynamic read(String key) {
    final value = prefs.getString(key);
    return value != null ? jsonDecode(value) : null;
  }

  @override
  Future<void> write(String key, dynamic value) async =>
      prefs.setString(key, jsonEncode(value));

  @override
  Future<void> delete(String key) async => prefs.remove(key);

  @override
  Future<void> clear() async => prefs.clear();
}

void main() async {
  final prefs = await SharedPreferences.getInstance();
  HydratedStorage.storage = SharedPreferencesHydratedStorage(prefs);
}
```

---

## 📜 License

MIT License. See [LICENSE](LICENSE) for details.
