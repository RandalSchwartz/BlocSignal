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

## 1. Primitive State Hydration (e.g. `int`, `String`)

```dart
import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';

class CounterCubit extends HydratedCubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void increment() => emit(stateValue + 1);

  @override
  int? fromJson(dynamic json) => json as int?;

  @override
  dynamic toJson(int state) => state; // Directly return primitive value!
}
```

---

## 2. Collection & Map State Hydration

```dart
class TodosCubit extends HydratedCubitSignal<List<String>> {
  TodosCubit() : super(initialState: const []);

  void addTodo(String text) => emit([...stateValue, text]);

  @override
  List<String>? fromJson(dynamic json) =>
      (json as List?)?.map((e) => e.toString()).toList();

  @override
  dynamic toJson(List<String> state) => state;
}
```

---

## 3. Instance Scoping & Clearing State

```dart
// Scope storage by instance ID for multi-user/multi-account features
final user1Cubit = CounterCubit(id: 'user_123');
final user2Cubit = CounterCubit(id: 'user_456');

// Delete stored key and reset state to initialState
await user1Cubit.clear();

---

## 4. Wiring `SharedPreferences` as `HydratedStorage`

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
    if (value == null) return null;
    return jsonDecode(value);
  }

  @override
  Future<void> write(String key, dynamic value) async {
    await prefs.setString(key, jsonEncode(value));
  }

  @override
  Future<void> delete(String key) async {
    await prefs.remove(key);
  }

  @override
  Future<void> clear() async {
    await prefs.clear();
  }
}

// In main.dart before runApp():
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  HydratedStorage.storage = SharedPreferencesHydratedStorage(prefs);

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
```
