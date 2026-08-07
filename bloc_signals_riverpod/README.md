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

- 🔄 **`ProviderListenable.toBlocSignal(refOrContainer)`**: Convert any Riverpod `ProviderListenable` (`Notifier`, `Provider`, `.select()`) into a `BlocSignalBase`.
- 🔒 **Automatic `ref.onDispose` Registration**: Passing `ref` into `toBlocSignal(ref)` automatically binds `ref.onDispose(bloc.close)` for zero-boilerplate lifecycle management.
- 🔀 **`BlocSignalBase.toProvider()`**: Expose any `BlocSignal` or `CubitSignal` as a standard Riverpod `Provider<T>`.
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

### 1. Riverpod → `BlocSignal` (Inside Provider)

Adapt any Riverpod provider into a `BlocSignalBase` inside a Riverpod provider using `ref`:

```dart
import 'package:bloc_signals_riverpod/bloc_signals_riverpod.dart';
import 'package:riverpod/riverpod.dart';

final userNotifierProvider = NotifierProvider<UserNotifier, User>(UserNotifier.new);

// Convert Riverpod provider to BlocSignal container with automatic ref.onDispose binding
final userBlocProvider = Provider.autoDispose<BlocSignalBase<User>>((ref) {
  return userNotifierProvider.toBlocSignal(ref);
});
```

### 2. Riverpod → `BlocSignal` (Container)

Using a standalone `ProviderContainer`:

```dart
final container = ProviderContainer();
final riverpodBloc = userNotifierProvider.toBlocSignal(container);

// State is synchronously in sync with Riverpod!
print(riverpodBloc.stateValue);

// Clean up subscription when finished:
riverpodBloc.close();
```

### 3. `BlocSignal` → Riverpod

Expose a `BlocSignalBase` state container as a standard Riverpod `Provider`:

```dart
import 'package:bloc_signals_riverpod/bloc_signals_riverpod.dart';
import 'package:riverpod/riverpod.dart';

final counterCubit = CounterCubit();

// Convert to Riverpod Provider
final counterProvider = counterCubit.toProvider();

// Watch in Riverpod context:
final count = ref.watch(counterProvider);
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

