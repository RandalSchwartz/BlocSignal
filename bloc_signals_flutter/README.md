<table border="0">
  <tr>
    <td width="230" align="center" valign="middle">
      <img src="https://raw.githubusercontent.com/RandalSchwartz/BlocSignal/main/assets/logo.png" width="210" alt="bloc_signals_flutter" />
    </td>
    <td valign="middle">
      <h1>⚡ bloc_signals_flutter</h1>
      <p><strong><em>"With the rigor of BLoC and the flex and speed of Signals"</em></strong></p>
      <p>
        Flutter extensions, UI widgets, dependency injection providers, and reactive bindings 
        for the <a href="https://pub.dev/packages/bloc_signals">bloc_signals</a> state management library.
      </p>
    </td>
  </tr>
</table>

This companion package provides `BlocSignalProvider`, `MultiBlocSignalProvider`, `BlocSignalBuilder`, `BlocSignalListener`, `BlocSignalConsumer`, `BlocSignalSelector`, `BuildContext` extensions (`read()`, `watch()`), and Flutter `Listenable` interop helpers.

---

## 🌐 Ecosystem Packages

The `BlocSignal` monorepo consists of 10 modular packages:

| Package | Version | Description |
| :--- | :--- | :--- |
| **`bloc_signals`** | [![pub](https://img.shields.io/pub/v/bloc_signals.svg)](https://pub.dev/packages/bloc_signals) | Core pure Dart reactive state primitives bridging BLoC & Signals |
| **`bloc_signals_flutter`** | [![pub](https://img.shields.io/pub/v/bloc_signals_flutter.svg)](https://pub.dev/packages/bloc_signals_flutter) | Flutter UI bindings, providers, builders, listeners & selectors |
| **`bloc_signals_jaspr`** | [![pub](https://img.shields.io/pub/v/bloc_signals_jaspr.svg)](https://pub.dev/packages/bloc_signals_jaspr) | Jaspr web component integration and state binding for BlocSignal |
| **`bloc_signals_riverpod`** | [![pub](https://img.shields.io/pub/v/bloc_signals_riverpod.svg)](https://pub.dev/packages/bloc_signals_riverpod) | Bidirectional Riverpod 2/3 interop adapters & provider extensions |
| **`bloc_signals_hydrate`** | [![pub](https://img.shields.io/pub/v/bloc_signals_hydrate.svg)](https://pub.dev/packages/bloc_signals_hydrate) | Automated synchronous local state persistence & hydration |
| **`bloc_signals_replay`** | [![pub](https://img.shields.io/pub/v/bloc_signals_replay.svg)](https://pub.dev/packages/bloc_signals_replay) | Undo & redo state history tracking for CubitSignal and BlocSignal |
| **`bloc_signals_otel`** | [![pub](https://img.shields.io/pub/v/bloc_signals_otel.svg)](https://pub.dev/packages/bloc_signals_otel) | OpenTelemetry tracing and span generation for state transitions |
| **`bloc_signals_devtools`** | [![pub](https://img.shields.io/pub/v/bloc_signals_devtools.svg)](https://pub.dev/packages/bloc_signals_devtools) | Universal DevTools telemetry observer using `dart:developer` |
| **`bloc_signals_test`** | [![pub](https://img.shields.io/pub/v/bloc_signals_test.svg)](https://pub.dev/packages/bloc_signals_test) | Declarative unit testing utilities (`blocSignalTest`) |
| **`bloc_signals_lint`** | [![pub](https://img.shields.io/pub/v/bloc_signals_lint.svg)](https://pub.dev/packages/bloc_signals_lint) | Custom analyzer lint rules & automated IDE quick-fixes |

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
  bloc_signals_flutter: ^1.0.0
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

### 4. Selective Rebuilds (`BlocSignalSelector` & `context.select`)

```dart
BlocSignalSelector<UserBloc, UserState, String>(
  selector: (state) => state.username, // Rebuilds ONLY if username changes
  options: ComputedOptions(name: 'UsernameSelector'), // Optional debug name
  builder: (context, username) {
    return Text('Hello, $username!');
  },
)
```

Or directly via `BuildContext`:

```dart
final canSubmit = context.select<FormCubit, bool>(
  (cubit) => cubit.stateValue.canSubmit,
);
```

> [!TIP]
> **Generic Type Parameters for `context.select`**:
> Unlike Riverpod's 3-parameter `context.select` or `package:flutter_bloc`, `BlocSignal`'s `context.select` takes **2** generic type parameters:
> 1. `B`: The `BlocSignalBase` container type (e.g., `UserCubit` or `CounterBloc`)
> 2. `R`: The selected return value type (e.g., `String` or `bool`)
>
> The callback receives the **`bloc` instance** directly: `context.select<FormCubit, bool>((cubit) => cubit.stateValue.canSubmit)`.

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

## 🤖 AI Coding Assistant Skill & Guides

This package is supported by official pre-packaged AI Coding Skills and architectural documentation guides representing Flutter widget lifecycle patterns, UI binding rules, and migration paths for `BlocSignal`:

- 🔄 **[Migration Guide](https://github.com/RandalSchwartz/BlocSignal/blob/main/plugins/bloc-signals/skills/bloc-signals/migration.md)**: Transitioning from classic `package:flutter_bloc` / `package:bloc` to `BlocSignal`.
- 🌁 **[Universal Interoperability Guide](https://github.com/RandalSchwartz/BlocSignal/blob/main/plugins/bloc-signals/skills/bloc-signals/interoperability.md)**: Bridging state containers across BLoC, Riverpod, Provider, and Listenable primitives.
- 📦 **[AI Skill Bundle](https://github.com/RandalSchwartz/BlocSignal/tree/main/plugins/bloc-signals/skills/bloc-signals)**: Load the pre-packaged `bloc-signals` skill bundle for AI coding assistants (such as Claude Code, Antigravity, Gemini, Cursor, or Codex) to guide code generation and analysis.

---

## 📜 Credits & Acknowledgements

Inspired by **[flutter_bloc](https://pub.dev/packages/flutter_bloc)** by **[Felix Angelov](https://github.com/felangel)** and **[signals_flutter](https://pub.dev/packages/signals)** by **[Rody Davis](https://github.com/roddydavis)**.
