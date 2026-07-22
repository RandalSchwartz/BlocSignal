# bloc_signals_lint

Custom static analysis lints and diagnostics for [`bloc_signals`](https://pub.dev/packages/bloc_signals).

Built on top of [`custom_lint`](https://pub.dev/packages/custom_lint), `bloc_signals_lint` catches common framework misuse, preserves Zone-context transition tracing, and enforces `BlocSignal` architectural invariants directly inside your IDE.

## Rules & Quick-Fixes

All rules are **enabled by default** once the plugin is activated.

### Core Framework Rules

| Rule | Default Severity | Description | Automated Fix |
| :--- | :--- | :--- | :--- |
| **`avoid_duplicate_event_handlers`** | Warning | Flags multiple `on<E>` registrations for the exact same event type `E` within a `BlocSignal` constructor. | — |
| **`require_super_on_event`** | Warning | Enforces calling `super.onEvent(event)` inside `onEvent` overrides to preserve Zone event context. | `Cmd+.` -> Add `super.onEvent(event);` |
| **`avoid_stream_transformers_on_bloc_signal`** | Warning | Flags stream transformer invocations (e.g. `.transform()`, `.debounce()`, `.switchMap()`) directly on synchronous `BlocSignalBase` instances. | — |
| **`avoid_direct_signal_mutation_outside_bloc`** | Warning | Prevents external code outside the state container class from calling protected `emit()` or mutating internal signal state. | — |

### Flutter UI Rules

| Rule | Default Severity | Description | Automated Fix |
| :--- | :--- | :--- | :--- |
| **`avoid_emit_in_build`** | Warning | Flags calls to `emit()` or `add()` on state containers directly inside Flutter `Widget.build()` methods. | — |
| **`avoid_unmanaged_signal_effects`** | Warning | Flags unmanaged `effect()` calls created inside Flutter `Widget` or `State` methods without lifecycle cleanup. | — |
| **`prefer_bloc_signal_provider_read_in_callbacks`** | Warning | Warns when `context.watch<T>()` is used inside event callback closures (e.g. `onPressed`), suggesting `context.read<T>()`. | `Cmd+.` -> Replace `watch` with `read` |

## Quick Setup

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

## Configuring Rules

### Disabling or Customizing Rules in `analysis_options.yaml`

To disable specific rules or customize their severity (`true`, `false`, `warning`, `error`, `info`), add a `custom_lint` section to your `analysis_options.yaml`:

```yaml
custom_lint:
  rules:
    # Disable a specific rule
    - avoid_duplicate_event_handlers: false

    # Customize rule severity
    - require_super_on_event: error
```

### Disabling Rules in Code (Inline Ignores)

You can ignore rules for a specific line or file using standard Dart analyzer comments:

```dart
// Ignore for a single line
// ignore: avoid_duplicate_event_handlers
on<Increment>((event, emit) => emit(stateValue + 1));

// Ignore for an entire file
// ignore_for_file: avoid_stream_transformers_on_bloc_signal
```
