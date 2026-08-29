<table border="0">
  <tr>
    <td width="230" align="center" valign="middle">
      <img src="https://raw.githubusercontent.com/RandalSchwartz/BlocSignal/main/assets/logo.png" width="210" alt="bloc_signals_bloc" />
    </td>
    <td valign="middle">
      <h1>⚡ bloc_signals_bloc</h1>
      <p><strong><em>"With the rigor of BLoC and the flex and speed of Signals"</em></strong></p>
      <p>
        Bidirectional interoperability adapters and extensions connecting <code>BlocSignal</code> / <code>CubitSignal</code> 
        state containers with classic <a href="https://pub.dev/packages/bloc">package:bloc</a> and <a href="https://pub.dev/packages/flutter_bloc">flutter_bloc</a>.
      </p>
    </td>
  </tr>
</table>

Supports both **bloc 8.x** and **bloc 9.x** out of the box.

---

## 🌐 Ecosystem Packages

The `BlocSignal` monorepo consists of 11 modular packages:

| Package | Version | Description |
| :--- | :--- | :--- |
| **`bloc_signals`** | [![pub](https://img.shields.io/pub/v/bloc_signals.svg)](https://pub.dev/packages/bloc_signals) | Core pure Dart reactive state primitives bridging BLoC & Signals |
| **`bloc_signals_flutter`** | [![pub](https://img.shields.io/pub/v/bloc_signals_flutter.svg)](https://pub.dev/packages/bloc_signals_flutter) | Flutter UI bindings, providers, builders, listeners & selectors |
| **`bloc_signals_bloc`** | [![pub](https://img.shields.io/pub/v/bloc_signals_bloc.svg)](https://pub.dev/packages/bloc_signals_bloc) | Classic BLoC 8/9 interop adapters & bidirectional event bridges |
| **`bloc_signals_riverpod`** | [![pub](https://img.shields.io/pub/v/bloc_signals_riverpod.svg)](https://pub.dev/packages/bloc_signals_riverpod) | Bidirectional Riverpod 2/3 interop adapters & provider extensions |
| **`bloc_signals_jaspr`** | [![pub](https://img.shields.io/pub/v/bloc_signals_jaspr.svg)](https://pub.dev/packages/bloc_signals_jaspr) | Jaspr web component integration and state binding for BlocSignal |
| **`bloc_signals_hydrate`** | [![pub](https://img.shields.io/pub/v/bloc_signals_hydrate.svg)](https://pub.dev/packages/bloc_signals_hydrate) | Automated synchronous local state persistence & hydration |
| **`bloc_signals_replay`** | [![pub](https://img.shields.io/pub/v/bloc_signals_replay.svg)](https://pub.dev/packages/bloc_signals_replay) | Undo & redo state history tracking for CubitSignal and BlocSignal |
| **`bloc_signals_otel`** | [![pub](https://img.shields.io/pub/v/bloc_signals_otel.svg)](https://pub.dev/packages/bloc_signals_otel) | OpenTelemetry tracing and span generation for state transitions |
| **`bloc_signals_devtools`** | [![pub](https://img.shields.io/pub/v/bloc_signals_devtools.svg)](https://pub.dev/packages/bloc_signals_devtools) | Universal DevTools telemetry observer using `dart:developer` |
| **`bloc_signals_test`** | [![pub](https://img.shields.io/pub/v/bloc_signals_test.svg)](https://pub.dev/packages/bloc_signals_test) | Declarative unit testing utilities (`blocSignalTest`) |
| **`bloc_signals_lint`** | [![pub](https://img.shields.io/pub/v/bloc_signals_lint.svg)](https://pub.dev/packages/bloc_signals_lint) | Custom analyzer lint rules & automated IDE quick-fixes |

---

## ⚡ Key Features

- 🔄 **Bidirectional `classicBloc.toBlocSignal()`**: Convert any classic `Bloc` into a `ClassicBlocSignal` exposing synchronous reactive signal reading (`.stateValue` / `.state`) and mutation via `.add(event)`.
- 🔀 **Bidirectional `classicCubit.toBlocSignal()`**: Convert any classic `Cubit` into a `ClassicCubitSignal` exposing typed `.cubit` method access alongside reactive signals.
- ⚡ **Reverse `blocSignal.toClassicBloc()` / `.toClassicCubit()`**: Drop modern streamless `BlocSignal` containers directly into legacy `flutter_bloc` UI widgets (`BlocBuilder`, `BlocListener`, `BlocConsumer`, `BlocSelector`) with zero widget rewrites.
- 🎯 **Eliminate Stream Delay**: Provide instant, glitch-free synchronous UI rebuilds on classic Blocs without microtask queue latency.
- 🔒 **Lifecycle & AutoClose**: Configurable `autoClose: true` for clean scoped disposal.

---

## 🚀 Getting Started

Add `bloc_signals_bloc` to your `pubspec.yaml`:

```yaml
dependencies:
  bloc: ^8.1.0 # or ^9.0.0
  bloc_signals: ^1.0.0
  bloc_signals_bloc: ^1.0.0
```

---

## 💡 Quick Examples

### 1. Classic BLoC → `BlocSignal` (Bidirectional Read & Mutate)

```dart
import 'package:bloc_signals_bloc/bloc_signals_bloc.dart';

final classicBloc = CounterBloc();

// Convert classic Bloc into a synchronous BlocSignal:
final blocSignal = classicBloc.toBlocSignal();

// 1. Synchronous reactive read:
print(blocSignal.stateValue);

// 2. Dispatch events directly through the signal container:
blocSignal.add(IncrementEvent());
```

### 2. Modern `BlocSignal` → Classic BLoC (Legacy UI Compatibility)

```dart
import 'package:bloc_signals_bloc/bloc_signals_bloc.dart';

final modernBloc = ModernCounterBloc();

// Adapt modern BlocSignal into a classic Bloc for legacy widgets:
final classicAdapter = modernBloc.toClassicBloc();

// Consumed directly by legacy flutter_bloc widgets:
BlocBuilder<BlocSignalToClassicBloc<CounterEvent, int>, int>(
  bloc: classicAdapter,
  builder: (context, state) => Text('$state'),
);
```

---

## 🔄 Lifecycle Semantics

| Direction | Mechanism | Lifecycle Coupling |
| :--- | :--- | :--- |
| **Classic → `BlocSignal`** <br> (`toBlocSignal`) | Subscribes to `bloc.stream` and forwards state emissions. | `autoClose: false` (default) keeps the classic Bloc open. `autoClose: true` closes the underlying classic Bloc when the adapter closes. |
| **`BlocSignal` → Classic** <br> (`toClassicBloc`) | Subscribes to `blocSignal.state` and emits classic stream events. | `autoClose: false` (default) keeps the `BlocSignal` open. `autoClose: true` closes the `BlocSignal` when the classic adapter closes. |

---

## 🤖 AI Coding Assistant Skill

This package is supported by an official pre-packaged [AI Coding Skill](https://github.com/RandalSchwartz/BlocSignal/tree/main/plugins/bloc-signals/skills/bloc-signals) representing architectural best practices, migration patterns, and bidirectional state bridge rules for `BlocSignal`.
