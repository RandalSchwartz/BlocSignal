# BlocSignal Custom Lint Guidelines (`bloc_signals_lint`)

`bloc_signals_lint` provides static analysis lints and IDE diagnostics for `BlocSignal` and `CubitSignal` codebases.

---

## 📋 Rules & Quick-Fixes

All rules are **enabled by default** once `custom_lint` is configured in `analysis_options.yaml`.

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
