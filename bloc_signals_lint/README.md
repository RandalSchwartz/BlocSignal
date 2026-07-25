# ⚡ bloc_signals_lint

> *"With the rigor of Bloc and the flex and speed of Signal"*

Custom static analysis lints, diagnostics, and automated IDE quick-fixes for [`bloc_signals`](https://pub.dev/packages/bloc_signals).

Built on top of [`custom_lint`](https://pub.dev/packages/custom_lint), `bloc_signals_lint` catches common framework misuse, preserves Zone-context transition tracing, and enforces `BlocSignal` architectural invariants directly inside your IDE.

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

## ⚡ Rules & Quick-Fixes

### Core Framework Rules

| Rule | Default Severity | Description | Automated Fix |
| :--- | :--- | :--- | :--- |
| **`avoid_duplicate_event_handlers`** | Warning | Flags multiple `on<E>` registrations for the exact same event type `E` within a `BlocSignal` constructor. | — |
| **`require_super_on_event`** | Warning | Enforces calling `super.onEvent(event)` inside `onEvent` overrides to preserve Zone event context. | `Cmd+.` -> Add `super.onEvent(event);` |
| **`avoid_stream_transformers_on_bloc_signal`** | Warning | Flags stream transformer invocations (e.g. `.transform()`, `.debounce()`, `.switchMap()`) directly on synchronous `BlocSignalBase` instances. | — |
| **`avoid_direct_signal_mutation_outside_bloc`** | Warning | Prevents external code outside the state container class from calling protected `emit()` or mutating internal signal state. | — |
| **`avoid_top_level_bloc_signal_instances`** | Warning | Flags top-level variables and static fields declared directly as `BlocSignal` / `CubitSignal` instances. | — |

### Flutter UI Rules

| Rule | Default Severity | Description | Automated Fix |
| :--- | :--- | :--- | :--- |
| **`avoid_emit_in_build`** | Warning | Flags calls to `emit()` or `add()` on state containers directly inside Flutter `Widget.build()` methods. | — |
| **`avoid_unmanaged_signal_effects`** | Warning | Flags unmanaged `effect()` calls created inside Flutter `Widget` or `State` methods without lifecycle cleanup. | — |
| **`prefer_bloc_signal_provider_read_in_callbacks`** | Warning | Warns when `context.watch<T>()` is used inside event callback closures (e.g. `onPressed`), suggesting `context.read<T>()`. | `Cmd+.` -> Replace `watch` with `read` |
| **`avoid_providing_existing_instance_with_create`** | Warning | Flags passing existing variable references to `BlocSignalProvider(create: ...)` instead of `BlocSignalProvider.value(value: ...)`. | — |
| **`avoid_manual_close_on_provided_bloc`** | Warning | Flags calling `.close()` manually on state containers retrieved via `context.read<T>()` or `BlocSignalProvider.of(context)`. | — |

---

## 🚀 Quick Setup

1. Add `custom_lint` and `bloc_signals_lint` to your `pubspec.yaml`:

```yaml
dev_dependencies:
  custom_lint: ^0.7.0
  bloc_signals_lint: ^0.1.0
```

2. Enable `custom_lint` in your `analysis_options.yaml`:

```yaml
analyzer:
  plugins:
    - custom_lint
```

---

## ⚙️ Customization & Inline Ignores

Disable or customize severity in `analysis_options.yaml`:

```yaml
custom_lint:
  rules:
    - avoid_duplicate_event_handlers: false
    - require_super_on_event: error
```

Or ignore inline in code:

```dart
// ignore: avoid_duplicate_event_handlers
on<Increment>((event, emit) => emit(stateValue + 1));
```

---

## 🤖 AI Coding Assistant Skill

This package is supported by an official pre-packaged [AI Coding Skill](https://github.com/RandalSchwartz/BlocSignal/tree/main/plugins/bloc-signals/skills/bloc-signals) representing analyzer rules, IDE diagnostics, and automated quick-fix rules for `BlocSignal`.

If you develop with AI coding assistants (such as Claude Code, Antigravity, Gemini, Cursor, or Codex), you can load the [`bloc-signals`](https://github.com/RandalSchwartz/BlocSignal/tree/main/plugins/bloc-signals/skills/bloc-signals) skill bundle to guide your assistant's code generation and analysis.
