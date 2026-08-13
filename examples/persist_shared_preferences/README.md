# SharedPreferences State Persistence Example (`HydratedCubitSignal`)

A state persistence example in Flutter demonstrating synchronous hydration and storage resets using `HydratedCubitSignal`.

## ✨ Features

- **Zero-Override Primitive Hydration**: Unlike classic `hydrated_bloc` which requires overriding `fromJson` and `toJson` with `Map<String, dynamic>` conversions, `HydratedCubitSignal` persists primitive types (`bool`, `int`, `String`, `double`) with **zero boilerplate method overrides**.
- **Synchronous App Startup**: State hydrates synchronously in the constructor, guaranteeing frame-1 theme accuracy without visual flickering.
- **Persistent Theme Toggle**: Persists dark/light theme preferences across full application restarts.
- **Storage Reset (`clear()`)**: Demonstrates resetting persisted values back to initial defaults using `.clear()`.

## 🚀 Running the Example

```bash
cd examples/persist_shared_preferences
flutter run
```

## 🧪 Running Tests

```bash
cd examples/persist_shared_preferences
flutter test
```
