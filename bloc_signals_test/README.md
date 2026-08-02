<table border="0">
  <tr>
    <td width="230" align="center" valign="middle">
      <img src="https://raw.githubusercontent.com/RandalSchwartz/BlocSignal/main/assets/logo.png" width="210" alt="bloc_signals_test" />
    </td>
    <td valign="middle">
      <h1>⚡ bloc_signals_test</h1>
      <p><strong><em>"With the rigor of BLoC and the flex and speed of Signals"</em></strong></p>
      <p>
        Declarative unit testing utilities for <a href="https://pub.dev/packages/bloc_signals">bloc_signals</a> 
        and <code>CubitSignal</code> instances.
      </p>
    </td>
  </tr>
</table>

`bloc_signals_test` provides `blocSignalTest`, a declarative helper tailored specifically for synchronous reactive signal state propagation, state de-duplication, and observer isolation.

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

- 🎯 **Declarative Assertions**: Verify emitted states in exact order using `expect`.
- ⏱️ **Async Support**: Await asynchronous event handlers or timers using `wait`.
- ⏭️ **State Skipping**: Skip initial emissions using `skip`.
- 🚨 **Error Testing**: Verify exceptions caught in `onError` using `errors`.
- 🧹 **Automatic Cleanup**: Guarantees observer restoration and `bloc.close()` post-test.

---

## 🚀 Getting Started

Add `bloc_signals_test` to your `pubspec.yaml`:

```yaml
dev_dependencies:
  bloc_signals_test: ^0.1.0
  test: ^1.24.0
```

---

## 💡 Quick Examples

### 1. Cubit Unit Test (`blocSignalTest`)

```dart
import 'package:bloc_signals_test/bloc_signals_test.dart';
import 'package:test/test.dart';

void main() {
  group('CounterCubit', () {
    blocSignalTest<CounterCubit, int>(
      'emits [1] when increment is called',
      build: CounterCubit.new,
      act: (cubit) => cubit.increment(),
      expect: () => [1],
    );
  });
}
```

### 2. Async Event Bloc Test (`wait` & `errors`)

```dart
blocSignalTest<DataBloc, DataState>(
  'emits [DataLoading, DataLoaded] when FetchData succeeds',
  build: () => DataBloc(repository: mockRepo),
  act: (bloc) => bloc.add(FetchData()),
  wait: const Duration(milliseconds: 100),
  expect: () => [
    const DataLoading(),
    const DataLoaded('sample_data'),
  ],
);
```

---

## 🤖 AI Coding Assistant Skill

This package is supported by an official pre-packaged [AI Coding Skill](https://github.com/RandalSchwartz/BlocSignal/tree/main/plugins/bloc-signals/skills/bloc-signals) representing unit testing patterns, observer isolation, and synchronous assertion guidelines for `BlocSignal`.

If you develop with AI coding assistants (such as Claude Code, Antigravity, Gemini, Cursor, or Codex), you can load the [`bloc-signals`](https://github.com/RandalSchwartz/BlocSignal/tree/main/plugins/bloc-signals/skills/bloc-signals) skill bundle to guide your assistant's code generation and analysis.

---

## 📜 License

MIT License. See [LICENSE](LICENSE) for details.
