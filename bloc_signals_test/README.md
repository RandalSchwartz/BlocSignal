# ⚡ bloc_signals_test

> *"With the rigor of Bloc and the flex and speed of Signal"*

Declarative unit testing utilities for [`bloc_signals`](https://pub.dev/packages/bloc_signals) and `CubitSignal` instances.

`bloc_signals_test` provides `blocSignalTest`, a declarative helper tailored specifically for synchronous reactive signal state propagation, state de-duplication, and observer isolation.

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
| **`bloc_signals_otel`** | OpenTelemetry tracing observers | 📦 [pub.dev](https://pub.dev/packages/bloc_signals_otel) |

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
