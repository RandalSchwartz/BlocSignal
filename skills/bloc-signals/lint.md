# BlocSignal Custom Lint Guidelines (`bloc_signals_lint`)

`bloc_signals_lint` provides static analysis lints and IDE diagnostics for `BlocSignal` and `CubitSignal` codebases.

---

## 📋 Core Framework Rules

All rules are **enabled by default** once `custom_lint` is configured in `analysis_options.yaml`.

| Rule | Default Severity | Description |
| :--- | :--- | :--- |
| **`avoid_duplicate_event_handlers`** | Warning | Flags multiple `on<E>` registrations for the exact same event type `E` within a `BlocSignal` constructor. |
| **`require_super_on_event`** | Warning | Enforces calling `super.onEvent(event)` inside `onEvent` overrides to preserve Zone event context. |
| **`avoid_stream_transformers_on_bloc_signal`** | Warning | Flags stream transformer invocations (e.g. `.transform()`, `.debounce()`, `.switchMap()`) directly on synchronous `BlocSignalBase` instances. |
| **`avoid_direct_signal_mutation_outside_bloc`** | Warning | Prevents external code outside the state container class from calling protected `emit()` or mutating internal signal state. |

---

## ⚙️ Configuration & Customization

### Enabling/Disabling Rules in `analysis_options.yaml`

To enable, disable, or customize severity for specific rules, add a `custom_lint` section in your project's `analysis_options.yaml`:

```yaml
analyzer:
  plugins:
    - custom_lint

custom_lint:
  rules:
    # Disable a rule
    - avoid_duplicate_event_handlers: false

    # Change severity to error
    - require_super_on_event: error
```

### Disabling Rules in Code

To ignore a rule for a specific line or file:

```dart
// Single line ignore
// ignore: avoid_duplicate_event_handlers
on<Increment>((event, emit) => emit(stateValue + 1));

// File-wide ignore
// ignore_for_file: avoid_stream_transformers_on_bloc_signal
```
