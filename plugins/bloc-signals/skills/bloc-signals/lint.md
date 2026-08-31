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
| **`avoid_stream_transformers_on_bloc_signal`** | Warning | Flags stream transformer invocations (such as `.transform()`, `.debounce()`, `.switchMap()`) directly on synchronous `BlocSignalBase` instances. | — |
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
| **`avoid_context_watch_for_bloc_state`** | Warning | Flags `context.watch<T>()` on state containers inside `build()` methods to prevent missing state emission rebuilds. | `Cmd+.` -> Replace `watch` with `read` |
| **`avoid_unused_select_result`** | Warning | Flags calling `context.select(...)` as an unused expression statement where the result is discarded. | — |

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
