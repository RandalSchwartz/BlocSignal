# State Persistence & Hydration Guide (`package:bloc_signals_hydrate`)

This guide details state persistence and hydration in `BlocSignal` using `package:bloc_signals_hydrate`.

`HydratedCubitSignal` and `HydratedBlocSignal` automatically persist state changes to disk/storage and restore state synchronously during container instantiation across app restarts.

---

## 🚀 Key Features & Built-In Conveniences

- **Zero Overrides for Core & Primitive Types**:
  `HydratedMixin` provides default `fromJson` and `toJson` implementations that handle core primitives (`int`, `double`, `String`, `bool`, `Map`, `List`) with automatic type casting. Primitive state containers require **zero method overrides**!
- **Built-In Storage Adapters**:
  No need to manually write storage adapters! `package:bloc_signals_hydrate` provides tree-shakable adapters for `SharedPreferences` and `FlutterSecureStorage` via sub-library entrypoints:
  - `import 'package:bloc_signals_hydrate/shared_preferences.dart';`
  - `import 'package:bloc_signals_hydrate/secure_storage.dart';`
- **Synchronous Initial Hydration**:
  State is restored synchronously during constructor execution—meaning initial widget builds render hydrated data immediately with **zero frame flicker**.

---

## 1. Primitive State Hydration (such as `int`, `String`, `bool`)

Primitive and collection state containers require **zero method overrides** for `fromJson` or `toJson`. `HydratedMixin` handles serialization and deserialization out-of-the-box!

```dart
import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';

// Primitive cubits require ZERO fromJson/toJson overrides!
class CounterCubit extends HydratedCubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void increment() => emit(stateValue + 1);
}
```

---

## 2. Complex Object Hydration (`UserModel`, `CustomState`)

For custom class states or complex domain models, override `fromJson` and `toJson` on your `HydratedCubitSignal` or `HydratedBlocSignal`:

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

---

## 3. Storage Keys (`storageToken`) & Instance Scoping

Persistent keys in storage are determined by the `storageToken` getter on `HydratedMixin`:

```dart
String get storageToken => '$storagePrefix${id != null ? '_$id' : ''}';
```

- **`storagePrefix`**: Defaults to `runtimeType.toString()` (for example `'CounterCubit'`).
- **`id`**: An optional instance identifier (defaults to `null`).

### Singletons vs Multi-Instance Cubits
- **Global / Singleton Cubits**: Leave `id` as `null` (default). Storage key is simply the class name (for example `'CounterCubit'`).
- **Multi-Instance / Scoped Cubits**: Pass `id: 'user_123'` or `id: 'tab_home'`. The storage keys will be `'CounterCubit_user_123'` and `'CounterCubit_tab_home'` without collisions.

---

## 4. Troubleshooting & Best Practices

- **Frame 1 Synchronous Hydration**: Because hydration happens during class constructor execution (`initHydratedState`), your initial UI frame always displays restored state directly—no loading spinner or initial state flicker.
- **Listing Stored Keys**: The `HydratedStorage` interface (`read`, `write`, `delete`, `clear`) does not include a `listKeys()` method to keep storage contracts backend-agnostic. Query the underlying storage engine directly (for example `prefs.getKeys()`).
- **Test Tear-Down**: Always invoke `HydratedStorage.reset()` inside `tearDown(() => ...)` in tests to prevent cross-test storage leakage.

---

## 5. Wiring Storage Adapters (`SharedPreferences` & `FlutterSecureStorage`)

Use the built-in storage adapters exported directly from sub-libraries in `package:bloc_signals_hydrate`:

### `SharedPreferences`
```dart
import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';
import 'package:bloc_signals_hydrate/shared_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  
  // Use the built-in SharedPreferencesHydratedStorage adapter directly!
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
  
  // Pre-load secure storage map for zero-flicker synchronous frame 1 hydration
  final secureStorage = const FlutterSecureStorage();
  HydratedStorage.storage = await SecureHydratedStorage.build(secureStorage);

  runApp(const MyApp());
}
```

---

## 5. Complete Flutter Hydrated Counter App

```dart
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';
import 'package:bloc_signals_hydrate/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 1. Primitive Cubit requires ZERO fromJson/toJson overrides!
class CounterCubit extends HydratedCubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void increment() => emit(stateValue + 1);
}

// 2. Entrypoint
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  
  // 3. Use built-in SharedPreferencesHydratedStorage adapter
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

## 6. Persisted Form Field Synchronization (`TextFormField` with `ValueKey`)

When hydrating form fields (`TextFormField`) with `HydratedCubitSignal`, avoid mutating a `TextEditingController.text` property inside a `build` method or `useEffect` hook:

```dart
BlocSignalBuilder<SettingsCubit, SettingsState>(
  builder: (context, state) {
    return TextFormField(
      // Pair ValueKey with initialValue to re-initialize input field on state hydration
      key: ValueKey('username_${state.username}'),
      initialValue: state.username,
      onChanged: (value) {
        context.read<SettingsCubit>().updateUsername(value);
      },
    );
  },
);
```

Pairing `initialValue` with a state-derived `ValueKey` allows fields to hydrate cleanly without triggering Flutter's `setState() called during build` assertion.

---

## 7. `HydratedCubitSignal` vs `PersistentSignal` (`signals.dart`)

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
