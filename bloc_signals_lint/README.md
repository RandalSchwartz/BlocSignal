<table border="0">
  <tr>
    <td width="230" align="center" valign="middle">
      <img src="https://raw.githubusercontent.com/RandalSchwartz/BlocSignal/main/assets/logo.png" width="210" alt="bloc_signals_lint" />
    </td>
    <td valign="middle">
      <h1>⚡ bloc_signals_lint</h1>
      <p><strong><em>"With the rigor of BLoC and the flex and speed of Signals"</em></strong></p>
      <p>
        Custom static analysis lints, diagnostics, and automated IDE quick-fixes 
        for <a href="https://pub.dev/packages/bloc_signals">bloc_signals</a>.
      </p>
    </td>
  </tr>
</table>

Built on top of [`custom_lint`](https://pub.dev/packages/custom_lint), `bloc_signals_lint` catches common framework misuse, preserves Zone-context transition tracing, and enforces `BlocSignal` architectural invariants directly inside your IDE.

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

## ⚡ Rules & Quick-Fixes

### Core Framework Rules

| Rule | Default Severity | Description | Automated Fix |
| :--- | :--- | :--- | :--- |
| **`avoid_duplicate_event_handlers`** | Warning | Flags multiple `on<E>` registrations for the exact same event type `E` within a `BlocSignal` constructor. | — |
| **`require_super_on_event`** | Warning | Enforces calling `super.onEvent(event)` inside `onEvent` overrides to preserve Zone event context. | `Cmd+.` -> Add `super.onEvent(event);` |
| **`avoid_stream_transformers_on_bloc_signal`** | Warning | Flags stream transformer invocations (for example `.transform()`, `.debounce()`, `.switchMap()`) directly on synchronous `BlocSignalBase` instances. | — |
| **`avoid_direct_signal_mutation_outside_bloc`** | Warning | Prevents external code outside the state container class from calling protected `emit()` or mutating internal signal state. | — |
| **`avoid_top_level_bloc_signal_instances`** | Warning | Flags top-level variables and static fields declared directly as `BlocSignal` / `CubitSignal` instances. | — |
| **`require_cubit_signal_mixin_init`** | Warning | Enforces calling `initCubitSignal(initialState: ...)` in constructors of classes mixing in `CubitSignalMixin` or `BlocSignalMixin`. | `Cmd+.` -> Add `initCubitSignal(initialState: ...);` |
| **`avoid_raw_signal_effects_in_bloc`** | Warning | Flags unmanaged top-level `effect()` calls inside `BlocSignalBase` containers, recommending `createEffect()`. | `Cmd+.` -> Replace `effect` with `createEffect` |

### Flutter UI Rules

| Rule | Default Severity | Description | Automated Fix |
| :--- | :--- | :--- | :--- |
| **`avoid_emit_in_build`** | Warning | Flags calls to `emit()` or `add()` on state containers directly inside Flutter `Widget.build()` methods. | — |
| **`avoid_unmanaged_signal_effects`** | Warning | Flags unmanaged `effect()` calls created inside Flutter `Widget` or `State` methods without lifecycle cleanup. | — |
| **`prefer_bloc_signal_provider_read_in_callbacks`** | Warning | Warns when `context.watch<T>()` is used inside event callback closures (for example `onPressed`), suggesting `context.read<T>()`. | `Cmd+.` -> Replace `watch` with `read` |
| **`avoid_providing_existing_instance_with_create`** | Warning | Flags passing existing variable references to `BlocSignalProvider(create: ...)` instead of `BlocSignalProvider.value(value: ...)`. | `Cmd+.` -> Replace `create:` with `value:` |
| **`avoid_manual_close_on_provided_bloc`** | Warning | Flags calling `.close()` manually on state containers retrieved via `context.read<T>()` or `BlocSignalProvider.of(context)`. | — |
| **`avoid_invalid_context_select_generics`** | Warning | Flags `context.select<B, R>` where generic parameters are omitted or invalid. | — |
| **`avoid_context_watch_for_bloc_state`** | Warning | Flags `context.watch<T>()` on state containers inside `build()` methods to prevent missing state emission rebuilds. | `Cmd+.` -> Replace `watch` with `read` |
| **`avoid_unused_select_result`** | Warning | Flags calling `context.select(...)` as an unused expression statement where the result is discarded. | — |

---

## 🚀 Quick Setup

1. Add `custom_lint` and `bloc_signals_lint` to your `pubspec.yaml`:

```yaml
dev_dependencies:
  custom_lint: ^0.7.0
  bloc_signals_lint: ^1.0.0
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
