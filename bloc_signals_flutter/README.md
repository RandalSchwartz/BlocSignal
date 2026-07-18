# bloc_signals_flutter

Flutter extensions and reactive bindings for the [bloc_signals](https://pub.dev/packages/bloc_signals) state management library.

This companion package provides dependency injection widgets and reactive UI builders to bridge your `BlocSignal` components seamlessly with the Flutter widget tree.

---

## Features

- 📦 **BlocSignalProvider**: An `InheritedWidget` wrapper that provides a `BlocSignal` to its descendants and automatically disposes of it when removed from the tree.
- 🔗 **MultiBlocSignalProvider**: Merges multiple `BlocSignalProvider`s to avoid deep widget tree nesting.
- ⚡ **BlocSignalBuilder**: A widget that watches a specific `BlocSignal` state changes and triggers fine-grained rebuilds using signals reactivity.
- 🛠️ **Context Extensions**: Quick accessors (`context.read<T>()` and `context.watch<T>()`) to access and subscribe to blocs.

---

## Getting Started

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  bloc_signals_flutter: ^0.1.0
```

Or run:

```bash
flutter pub add bloc_signals_flutter
```

---

## Usage

### 1. Provide the BlocSignal
Wrap your widget subtree with a `BlocSignalProvider` to supply your bloc instance down the tree:

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
```

### 2. Build the UI
Use `BlocSignalBuilder` to consume state values and rebuild the widget hierarchy whenever the state updates:

```dart
class CounterScreen extends StatelessWidget {
  const CounterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BlocSignal Counter')),
      body: Center(
        child: BlocSignalBuilder<CounterBloc, int>(
          builder: (context, state) {
            return Text(
              'Count: $state',
              style: Theme.of(context).textTheme.headlineMedium,
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Trigger state changes without rebuild dependencies
          context.read<CounterBloc>().add(Increment());
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

### 3. Injecting Multiple Blocs
Avoid deep nesting by using `MultiBlocSignalProvider`:

```dart
MultiBlocSignalProvider(
  providers: [
    BlocSignalProvider<AuthBloc>(create: (context) => AuthBloc()),
    BlocSignalProvider<ThemeBloc>(create: (context) => ThemeBloc()),
  ],
  child: const AppShell(),
)
```

---

## Additional Information

- **Core Package**: [bloc_signals](https://pub.dev/packages/bloc_signals)
- **Migration Guide**: Transitioning from classic BLoC? Check out the [Migration Guide](https://github.com/RandalSchwartz/BlocSignal/blob/main/MIGRATION.md).

---

## Credits & Acknowledgements

This package is heavily inspired by and builds upon the original **[flutter_bloc](https://pub.dev/packages/flutter_bloc)** library by **[Felix Angelov](https://github.com/felangel)**, combined with the reactive Flutter bindings of the **[signals_flutter](https://pub.dev/packages/signals)** library by **[Rody Davis](https://github.com/roddydavis)**.

