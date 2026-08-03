# State Persistence & Hydration Guide (`package:bloc_signals_hydrate`)

This guide details state persistence and hydration in `BlocSignal` using `package:bloc_signals_hydrate`.

`HydratedCubitSignal` and `HydratedBlocSignal` automatically persist state changes to disk/storage and restore state synchronously during container instantiation across app restarts.

---

## 🚀 Key Improvements Over `hydrated_bloc`

- **`dynamic` / `Object?` JSON Support**:
  `fromJson(dynamic json)` and `toJson(StateType state)` accept any valid JSON primitive or collection (`Map`, `List`, `String`, `num`, `bool`, `null`). Primitive states (e.g. `int`, `String`, `List<String>`) do **not** require map wrappers like `{"value": 42}`!
- **Synchronous Initial Hydration**:
  State is restored synchronously during constructor execution—meaning initial widget builds render hydrated data immediately with **zero frame flicker**.

---

## 1. Primitive State Hydration (e.g. `int`, `String`, `bool`)

Primitive state types require **zero method overrides**! Default `fromJson` and `toJson` implementations automatically pass primitive values through safely:

```dart
import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';

class CounterCubit extends HydratedCubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void increment() => emit(stateValue + 1);

  // fromJson and toJson default to identity casting for primitives!
  // No overrides needed!
}
```

---

## 2. Collection & Map State Hydration

Collection states (`List<T>`, `Map<K, V>`) also require **zero method overrides** for standard primitive elements! `HydratedMixin.fromJson` automatically casts raw `jsonDecode` outputs (`List<dynamic>`, `Map<dynamic, dynamic>`) to typed collections:

```dart
class TodosCubit extends HydratedCubitSignal<List<String>> {
  TodosCubit() : super(initialState: const []);

  void addTodo(String text) => emit([...stateValue, text]);

  // fromJson and toJson default to smart collection type casting!
  // No overrides needed!
}
```

---

## 3. Storage Keys (`storageToken`) & Instance Scoping

Persistent keys in storage are determined by the `storageToken` getter on `HydratedMixin`:

```dart
String get storageToken => '$storagePrefix${id != null ? '_$id' : ''}';
```

- **`storagePrefix`**: Defaults to `runtimeType.toString()` (e.g. `'CounterCubit'`).
- **`id`**: An optional instance identifier (defaults to `null`).

### Singletons vs Multi-Instance Cubits
- **Global / Singleton Cubits**: Leave `id` as `null` (default). Storage key is simply the class name (e.g. `'CounterCubit'`).
- **Multi-Instance Cubits**: Pass `id` via constructor to prevent key collisions across instances:

```dart
// Generated keys: "CounterCubit_user_123" vs "CounterCubit_user_456"
final user1Cubit = CounterCubit(id: 'user_123');
final user2Cubit = CounterCubit(id: 'user_456');

// Delete stored key and reset state to initialState
await user1Cubit.clear();
```

### Custom Storage Key Overrides
You can override `storageToken` or `storagePrefix` for custom storage key naming:

```dart
class CounterCubit extends HydratedCubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  // Custom key stored in SharedPreferences
  @override
  String get storageToken => 'custom_counter_v1';
}
```

### Key Resolution & Storage Inspection
- **Listing Stored Keys**: The `HydratedStorage` interface (`read`, `write`, `delete`, `clear`) does not include a `listKeys()` method to keep storage contracts backend-agnostic. Query the underlying storage engine directly (e.g., `prefs.getKeys()`).
- **Instance Lookup**: `HydratedCubitSignal` does not maintain a global static instance registry by key to prevent memory leaks. Manage cubit instances using standard DI (`BlocSignalProvider`) or factory caches.


---

## 4. Built-in Storage Adapters (`SharedPreferences` & `FlutterSecureStorage`)

`package:bloc_signals_hydrate` provides pre-built, tree-shakable adapters for `SharedPreferences` and `FlutterSecureStorage` via sub-library entrypoints:

### `SharedPreferences`
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

### `FlutterSecureStorage` (Keychain / KeyStore / Web Crypto)
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

## 5. Complete Flutter Hydrated Counter App

```dart
import 'dart:convert';
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 1. Define your Hydrated Cubit with zero map-wrapping!
class CounterCubit extends HydratedCubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void increment() => emit(stateValue + 1);

  @override
  int? fromJson(dynamic json) => json as int?;

  @override
  dynamic toJson(int state) => state;
}

// 2. Storage Adapter
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

// 3. Entrypoint
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  HydratedStorage.storage = SharedPreferencesHydratedStorage(prefs);

  runApp(
    MaterialApp(
      home: BlocSignalProvider<CounterCubit>(
        create: (context) => CounterCubit(),
        child: const CounterScreen(),
      ),
    ),
  );
}

class CounterScreen extends StatelessWidget {
  const CounterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final counterCubit = context.read<CounterCubit>();

    return Scaffold(
      appBar: AppBar(title: const Text('Hydrated Counter')),
      body: Center(
        child: BlocSignalBuilder<CounterCubit, int>(
          builder: (context, count) {
            return Text(
              '$count',
              style: Theme.of(context).textTheme.headlineLarge,
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: counterCubit.increment,
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

---

## 6. `HydratedCubitSignal` vs `PersistentSignal` (`signals.dart`)

If evaluating state persistence approaches, `bloc_signals_hydrate` and `signals.dart`'s native `PersistentSignal` cater to different architectural patterns:

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
