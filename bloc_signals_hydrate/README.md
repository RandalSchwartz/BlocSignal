<table border="0">
  <tr>
    <td width="230" align="center" valign="middle">
      <img src="https://raw.githubusercontent.com/RandalSchwartz/BlocSignal/main/assets/logo.png" width="210" alt="bloc_signals_hydrate" />
    </td>
    <td valign="middle">
      <h1>⚡ bloc_signals_hydrate</h1>
      <p><strong><em>"With the rigor of BLoC and the flex and speed of Signals"</em></strong></p>
      <p>
        State persistence and hydration adapters for <code>BlocSignal</code> state containers.
      </p>
    </td>
  </tr>
</table>

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
| **`bloc_signals_otel`** | OpenTelemetry tracing observers | 📦 [pub.dev](https://pub.dev/packages/bloc_signals_otel) |

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

### 3. Storage Keys & Instance Scoping

Storage keys are derived via the `storageToken` getter (`'$storagePrefix${id != null ? '_$id' : ''}'`).

* **Singletons**: Omit `id` (defaults to `null`). Storage key automatically uses the class name (e.g. `'CounterCubit'`).
* **Multi-Instance**: Pass `id` via constructor to scope storage per user/session (`CounterCubit(id: 'user_123')` -> key `'CounterCubit_user_123'`).
* **Custom Keys**: Override `storageToken` or `storagePrefix` directly for custom key formats:

```dart
class CounterCubit extends HydratedCubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  // 100% custom storage key stored in SharedPreferences
  @override
  String get storageToken => 'app_v2_counter_key';
}
```

### 4. Wiring Custom Storage (`SharedPreferences`)

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

## ⚖️ `HydratedCubitSignal` vs `PersistentSignal` (`signals.dart`)

If you are evaluating state persistence approaches, both `bloc_signals_hydrate` and `signals.dart`'s native `PersistentSignal` provide state persistence, but cater to different architectural patterns:

| Feature | `HydratedCubitSignal` / `HydratedBlocSignal` | `PersistentSignal` (`signals.dart`) |
| :--- | :--- | :--- |
| **Architecture Pattern** | BLoC container pattern (`fromJson` / `toJson`) | Raw key-value signal primitive |
| **Hydration Timing** | Synchronous during constructor execution (zero frame flicker) | Asynchronous or synchronous depending on adapter |
| **Observer Telemetry** | Integrated into BLoC `onError` / `onChange` observer pipeline | Handled per-signal or via storage callbacks |
| **Primitive Support** | Direct primitive return (`toJson(int state) => state`) | Value adapter layers |

### Interoperability: Bridging `PersistentSignal` into `BlocSignal`

If you already use `PersistentSignal` from `package:signals`, you can easily bridge it into a `CubitSignal` using an `effect()`:

```dart
class CounterCubit extends CubitSignal<int> {
  CounterCubit(this.persistent) : super(initialState: persistent.value) {
    // Sync updates from PersistentSignal into Cubit state
    effect(() => emit(persistent.value));
  }

  final PersistentSignal<int> persistent;

  void increment() => persistent.value++;
}
```

---

## 🤖 AI Coding Assistant Skill

This package is supported by an official pre-packaged [AI Coding Skill](https://github.com/RandalSchwartz/BlocSignal/tree/main/plugins/bloc-signals/skills/bloc-signals) representing state persistence guidelines, synchronous initial hydration semantics, and storage adapter rules for `BlocSignal`.

If you develop with AI coding assistants (such as Claude Code, Antigravity, Gemini, Cursor, or Codex), you can load the [`bloc-signals`](https://github.com/RandalSchwartz/BlocSignal/tree/main/plugins/bloc-signals/skills/bloc-signals) skill bundle to guide your assistant's code generation and analysis.

---

## 📜 License

MIT License. See [LICENSE](LICENSE) for details.
