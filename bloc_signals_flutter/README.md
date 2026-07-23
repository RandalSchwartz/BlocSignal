# ⚡ bloc_signals_flutter

> *"With the rigor of Bloc and the flex and speed of Signal"*

Flutter extensions, UI widgets, dependency injection providers, and reactive bindings for the [bloc_signals](https://pub.dev/packages/bloc_signals) state management library.

This companion package provides `BlocSignalProvider`, `MultiBlocSignalProvider`, `BlocSignalBuilder`, `BlocSignalListener`, `BlocSignalConsumer`, `BlocSignalSelector`, `BuildContext` extensions (`read()`, `watch()`), and Flutter `Listenable` interop helpers.

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

- 📦 **`BlocSignalProvider`**: Dependency injection `InheritedWidget` with automatic container disposal on unmount.
- 🔗 **`MultiBlocSignalProvider`**: Nesting-free multi-bloc provider wrapper.
- ⚡ **`BlocSignalBuilder`**: Fine-grained reactive UI widget triggered synchronously on state changes.
- 👂 **`BlocSignalListener`**: Side-effect listener widget for snackbars, dialogs, and navigation.
- 🔀 **`BlocSignalConsumer`**: Combines builder and listener into a single widget.
- 🔍 **`BlocSignalSelector`**: Rebuilds ONLY when a derived state slice changes.

---

## 🚀 Getting Started

Add `bloc_signals_flutter` to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  bloc_signals_flutter: ^0.2.5
```

---

## 💡 Quick Examples

### 1. Providing & Building (`BlocSignalProvider` & `BlocSignalBuilder`)

```dart
import 'package:flutter/material.dart';
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';

void main() {
  runApp(
    MaterialApp(
      home: BlocSignalProvider(
        create: (context) => CounterBloc(),
        child: const CounterScreen(),
      ),
    ),
  );
}

class CounterScreen extends StatelessWidget {
  const CounterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BlocSignal Counter')),
      body: Center(
        child: BlocSignalBuilder<CounterBloc, int>(
          builder: (context, state) => Text('Count: $state'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.read<CounterBloc>().add(Increment()),
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

### 2. Side-Effect Listener (`BlocSignalListener`)

```dart
BlocSignalListener<AuthBloc, AuthState>(
  listener: (context, state) {
    if (state is AuthFailure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.error)),
      );
    }
  },
  child: const LoginForm(),
)
```

### 3. Combined Consumer (`BlocSignalConsumer`)

```dart
BlocSignalConsumer<CartBloc, CartState>(
  listener: (context, state) {
    if (state.itemAdded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item added to cart!')),
      );
    }
  },
  builder: (context, state) {
    return Text('Cart items: ${state.items.length}');
  },
)
```

### 4. Selective Rebuilds (`BlocSignalSelector`)

```dart
BlocSignalSelector<UserBloc, UserState, String>(
  selector: (state) => state.username, // Rebuilds ONLY if username changes
  builder: (context, username) {
    return Text('Hello, $username!');
  },
)
```

### 5. MultiBlocSignalProvider

```dart
MultiBlocSignalProvider(
  providers: [
    BlocSignalProvider<AuthBloc>(create: (context) => AuthBloc()),
    BlocSignalProvider<ThemeBloc>(create: (context) => ThemeBloc()),
  ],
  child: const AppShell(),
)
```

### 6. Flutter `Listenable` & `ChangeNotifier` Interop

```dart
// Convert any ChangeNotifier into a CubitSignal
final ChangeNotifier notifier = MyChangeNotifier();
final cubit = notifier.toBlocSignal(initialState: 0);

// Convert any CubitSignal into a Flutter ValueListenable
final ValueListenable<int> listenable = cubit.toValueListenable();
```

---

## 📜 Credits & Acknowledgements

Inspired by **[flutter_bloc](https://pub.dev/packages/flutter_bloc)** by **[Felix Angelov](https://github.com/felangel)** and **[signals_flutter](https://pub.dev/packages/signals)** by **[Rody Davis](https://github.com/roddydavis)**.
