# bloc_signals_lint

Custom static analysis lints and diagnostics for [`bloc_signals`](https://pub.dev/packages/bloc_signals).

Built on top of [`custom_lint`](https://pub.dev/packages/custom_lint), `bloc_signals_lint` catches common framework misuse, preserves Zone-context transition tracing, and enforces `BlocSignal` architectural invariants directly inside your IDE.

## Core Rules

All rules are **enabled by default** once the plugin is activated.

| Rule | Default Severity | Description |
| :--- | :--- | :--- |
| **`avoid_duplicate_event_handlers`** | Warning | Flags multiple `on<E>` registrations for the exact same event type `E` within a `BlocSignal` constructor. |
| **`require_super_on_event`** | Warning | Enforces calling `super.onEvent(event)` inside `onEvent` overrides to preserve Zone event context. |
| **`avoid_stream_transformers_on_bloc_signal`** | Warning | Flags stream transformer invocations (e.g. `.transform()`, `.debounce()`, `.switchMap()`) directly on synchronous `BlocSignalBase` instances. |
| **`avoid_direct_signal_mutation_outside_bloc`** | Warning | Prevents external code outside the state container class from calling protected `emit()` or mutating internal signal state. |

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
