# Auth Flow Example (`BlocSignal` & `HydratedCubitSignal`)

An authentication flow example in Flutter demonstrating state persistence and reactive routing with `BlocSignal` and `HydratedCubitSignal`.

## ✨ Features

- **Reactive State Management**: Built with `HydratedCubitSignal` for instant state transitions.
- **Synchronous State Persistence**: User authentication tokens and profile data persist across app restarts using `HydratedStorage` without frame flickers.
- **Sealed State Hierarchy**: Expressive, type-safe states (`Unauthenticated`, `Authenticating`, `Authenticated`) handled with Dart 3 pattern matching.
- **Declarative Navigation**: Switches seamlessly between `LoginView` and `HomeView` using `BlocSignalBuilder`.

## 🔗 Upstream Reference

- Inspired by the classic [flutter_login / auth flow](https://bloclibrary.dev/tutorials/flutter-login/) from `felangel/bloc`.

## 🚀 Running the Example

```bash
cd examples/auth_flow
flutter run
```

## 🧪 Running Tests

```bash
cd examples/auth_flow
flutter test
```
