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

The `BlocSignal` monorepo consists of 11 modular packages:

| Package | Version | Description |
| :--- | :--- | :--- |
| **`bloc_signals`** | [![pub](https://img.shields.io/pub/v/bloc_signals.svg)](https://pub.dev/packages/bloc_signals) | Core pure Dart reactive state primitives bridging BLoC & Signals |
| **`bloc_signals_flutter`** | [![pub](https://img.shields.io/pub/v/bloc_signals_flutter.svg)](https://pub.dev/packages/bloc_signals_flutter) | Flutter UI bindings, providers, builders, listeners & selectors |
| **`bloc_signals_bloc`** | [![pub](https://img.shields.io/pub/v/bloc_signals_bloc.svg)](https://pub.dev/packages/bloc_signals_bloc) | Classic BLoC 8/9 interop adapters & bidirectional event bridges |
| **`bloc_signals_riverpod`** | [![pub](https://img.shields.io/pub/v/bloc_signals_riverpod.svg)](https://pub.dev/packages/bloc_signals_riverpod) | Bidirectional Riverpod 2/3 interop adapters & provider extensions |
| **`bloc_signals_jaspr`** | [![pub](https://img.shields.io/pub/v/bloc_signals_jaspr.svg)](https://pub.dev/packages/bloc_signals_jaspr) | Jaspr web component integration and state binding for BlocSignal |
| **`bloc_signals_hydrate`** | [![pub](https://img.shields.io/pub/v/bloc_signals_hydrate.svg)](https://pub.dev/packages/bloc_signals_hydrate) | Automated synchronous local state persistence & hydration |
| **`bloc_signals_replay`** | [![pub](https://img.shields.io/pub/v/bloc_signals_replay.svg)](https://pub.dev/packages/bloc_signals_replay) | Undo & redo state history tracking for CubitSignal and BlocSignal |
| **`bloc_signals_otel`** | [![pub](https://img.shields.io/pub/v/bloc_signals_otel.svg)](https://pub.dev/packages/bloc_signals_otel) | OpenTelemetry tracing and span generation for state transitions |
| **`bloc_signals_devtools`** | [![pub](https://img.shields.io/pub/v/bloc_signals_devtools.svg)](https://pub.dev/packages/bloc_signals_devtools) | Universal DevTools telemetry observer using `dart:developer` |
| **`bloc_signals_test`** | [![pub](https://img.shields.io/pub/v/bloc_signals_test.svg)](https://pub.dev/packages/bloc_signals_test) | Declarative unit testing utilities (`blocSignalTest`) |
| **`bloc_signals_lint`** | [![pub](https://img.shields.io/pub/v/bloc_signals_lint.svg)](https://pub.dev/packages/bloc_signals_lint) | Custom analyzer lint rules & automated IDE quick-fixes |

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
  bloc_signals: ^1.0.0
  bloc_signals_hydrate: ^1.0.0
```

---

## 💡 Quick Examples

### 1. Primitive State Hydration (`HydratedCubitSignal`)

Primitive and collection state containers (`int`, `double`, `String`, `bool`, `Map`, `List`) require **zero method overrides** for `fromJson` or `toJson`!

```dart
import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';

// Zero fromJson/toJson overrides required for primitive state types!
class CounterCubit extends HydratedCubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void increment() => emit(stateValue + 1);
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

* **Singletons**: Omit `id` (defaults to `null`). Storage key automatically uses the class name (for example `'CounterCubit'`).
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

### 4. Built-in Storage Adapters (`SharedPreferences` & `FlutterSecureStorage`)

`package:bloc_signals_hydrate` provides pre-built, tree-shakable adapters for `SharedPreferences` and `FlutterSecureStorage` via sub-library entrypoints:

#### `SharedPreferences`
```dart
import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';
import 'package:bloc_signals_hydrate/shared_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  HydratedStorage.storage = SharedPreferencesHydratedStorage(prefs);

  runApp(const MyApp());
}
```

#### `FlutterSecureStorage` (Keychain / KeyStore / Web Crypto)
```dart
import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';
import 'package:bloc_signals_hydrate/secure_storage.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Pre-load secure storage map for synchronous frame 1 hydration
  final secureStorage = const FlutterSecureStorage();
  HydratedStorage.storage = await SecureHydratedStorage.build(secureStorage);

  runApp(const MyApp());
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
