<table border="0">
  <tr>
    <td width="230" align="center" valign="middle">
      <img src="https://raw.githubusercontent.com/RandalSchwartz/BlocSignal/main/assets/logo.png" width="210" alt="bloc_signals_riverpod" />
    </td>
    <td valign="middle">
      <h1>⚡ bloc_signals_riverpod</h1>
      <p><strong><em>"With the rigor of BLoC and the flex and speed of Signals"</em></strong></p>
      <p>
        Bidirectional interoperability adapters and extensions connecting <code>BlocSignal</code> / <code>CubitSignal</code> 
        state containers with <a href="https://riverpod.dev">Riverpod</a> providers.
      </p>
    </td>
  </tr>
</table>

Supports both **Riverpod 2.x** and **Riverpod 3.x** out of the box.

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

- 🔄 **Bidirectional `toBlocSignal(refOrContainer)`**: Convert any Riverpod `NotifierProvider`, `AsyncNotifierProvider`, `StateNotifierProvider`, `StateProvider`, or `StreamNotifierProvider` into a `RiverpodNotifierBlocSignal` exposing the typed `.notifier` to trigger mutations directly from BlocSignal consumers.
- 🔀 **Bidirectional `BlocSignalBase.toProvider()`**: Expose any `BlocSignal` or `CubitSignal` as a Riverpod `NotifierProvider`, giving Riverpod widgets direct read access and typed `.notifier.cubit` / `.notifier.bloc` mutation handles.
- 🔒 **Automatic `ref.onDispose` Registration**: Passing `ref` or Flutter Riverpod `WidgetRef` into `toBlocSignal(ref)` automatically binds `ref.onDispose(bloc.close)` for zero-boilerplate lifecycle management.
- ⚡ **Universal Riverpod Support**: Built for `riverpod: ">=2.5.0 <4.0.0"`, supporting Riverpod 2.x and Riverpod 3.x seamlessly.

---

## 🚀 Getting Started

Add `bloc_signals_riverpod` to your `pubspec.yaml`:

```yaml
dependencies:
  riverpod: ^2.5.0 # or ^3.0.0
  bloc_signals: ^1.0.0
  bloc_signals_riverpod: ^1.0.0
```

---

## 💡 Quick Examples

### 1. Riverpod → `BlocSignal` (Bidirectional Read & Mutate)

Adapt any Riverpod notifier provider into a `RiverpodNotifierBlocSignal` inside a Riverpod provider using `ref`:

```dart
import 'package:bloc_signals_riverpod/bloc_signals_riverpod.dart';
import 'package:riverpod/riverpod.dart';

final counterProvider = NotifierProvider<CounterNotifier, int>(
  CounterNotifier.new,
);

// Convert Riverpod provider to BlocSignal container with automatic ref.onDispose binding
final counterBlocProvider = Provider.autoDispose<
    RiverpodNotifierBlocSignal<CounterNotifier, int>>((ref) {
  return counterProvider.toBlocSignal(ref);
});

// In your BlocSignal consumer or widget:
final bloc = ref.watch(counterBlocProvider);

// Read reactive state:
print(bloc.stateValue);

// Mutate upstream Riverpod notifier directly:
bloc.notifier.increment();
```

### 2. Riverpod → `BlocSignal` (ProviderContainer)

Using a standalone `ProviderContainer`:

```dart
final container = ProviderContainer();
final riverpodBloc = counterProvider.toBlocSignal(container);

// State is synchronously in sync with Riverpod!
print(riverpodBloc.stateValue);

// Mutate Riverpod notifier:
riverpodBloc.notifier.increment();

// Clean up subscription when finished:
await riverpodBloc.close();
```

### 3. `BlocSignal` → Riverpod (Bidirectional Read & Mutate)

Expose a `BlocSignalBase` state container as a standard Riverpod `NotifierProvider`:

```dart
import 'package:bloc_signals_riverpod/bloc_signals_riverpod.dart';
import 'package:riverpod/riverpod.dart';

final counterCubit = CounterCubit(initialState: 0);

// Convert to Riverpod NotifierProvider
final counterProvider = counterCubit.toProvider();

// Watch state in Riverpod context:
final count = ref.watch(counterProvider);

// Mutate cubit/bloc directly via Riverpod notifier handle:
ref.read(counterProvider.notifier).cubit.increment();
// Or for event-based blocs:
// ref.read(counterProvider.notifier).bloc.add(const IncrementEvent());
```

---

## 🔄 Lifecycle & AutoDispose Semantics

| Direction | Mechanism | Lifecycle Coupling |
| :--- | :--- | :--- |
| **Riverpod → `BlocSignal`** <br> (`toBlocSignal`) | Creates an active `ProviderSubscription` via `container.listen()`. | **Coupled**: Holding `RiverpodBlocSignal` open retains an `autoDispose` Riverpod provider. Calling `toBlocSignal(ref)` automatically registers `ref.onDispose(bloc.close)` to release the Riverpod provider when the scope unmounts. |
---

## 🤖 AI Coding Assistant Skill

This package is supported by an official pre-packaged [AI Coding Skill](https://github.com/RandalSchwartz/BlocSignal/tree/main/plugins/bloc-signals/skills/bloc-signals) representing architectural best practices, Riverpod 2/3 migration patterns, and bidirectional state bridge rules for `BlocSignal`.

If you develop with AI coding assistants (such as Claude Code, Antigravity, Gemini, Cursor, or Codex), you can load the [`bloc-signals`](https://github.com/RandalSchwartz/BlocSignal/tree/main/plugins/bloc-signals/skills/bloc-signals) skill bundle to guide your assistant's code generation and analysis.

