# BlocSignal Custom Lint Guidelines (`bloc_signals_lint`)

`bloc_signals_lint` provides static analysis lints and IDE diagnostics for `BlocSignal` and `CubitSignal` codebases.

---

## 📋 Rules & Quick-Fixes

All rules are **enabled by default** once `bloc_signals_lint` is configured under `plugins:` in `analysis_options.yaml`.

### Core Framework Rules

| Rule | Default Severity | Description | Automated Fix |
| :--- | :--- | :--- | :--- |
| **`avoid_duplicate_event_handlers`** | Warning | Flags multiple `on<E>` registrations for the exact same event type `E` within a `BlocSignal` or `BlocSignalMixin` class or mixin declaration. | `Cmd+.` -> Remove duplicate event handler |
| **`require_super_on_event`** | Warning | Enforces calling `super.onEvent(event)` inside `onEvent` overrides to preserve Zone event context. | `Cmd+.` -> Add `super.onEvent(event);` |
| **`avoid_stream_transformers_on_bloc_signal`** | Warning | Flags stream transformer invocations (such as `.transform()`, `.debounce()`, `.switchMap()`) directly on synchronous `BlocSignalBase` instances. | `Cmd+.` -> Insert `.toStream()` |
| **`avoid_direct_signal_mutation_outside_bloc`** | Warning | Prevents external code outside the state container class from calling protected `emit()` or mutating internal signal state. | — |
| **`avoid_top_level_bloc_signal_instances`** | Warning | Flags top-level variables and static fields declared directly as `BlocSignal` / `CubitSignal` instances. | — |
| **`require_cubit_signal_mixin_init`** | Warning | Enforces calling `initCubitSignal(initialState: ...)` in constructors of classes mixing in `CubitSignalMixin` or `BlocSignalMixin`. | `Cmd+.` -> Add `initCubitSignal(initialState: ...);` |
| **`avoid_raw_signal_effects_in_bloc`** | Warning | Flags unmanaged top-level `effect()` calls inside `BlocSignalBase` containers, recommending `createEffect()`. | `Cmd+.` -> Replace `effect` with `createEffect` |
| **`prefer_named_replay_constructor`** | Warning | Flags `super.positional(...)` invocations in `ReplayCubit` and `ReplayBloc` subclasses, recommending `super(initialState: ...)`. | `Cmd+.` -> Replace `super.positional(...)` with `super(initialState: ...)` |
| **`require_emit_in_helper_name`** | Warning | Flags private helper methods calling `emit()` whose names do not reflect state emission. | `Cmd+.` -> Rename to `...AndEmit` |
| **`avoid_multiple_synchronous_emits`** | Warning | Flags multiple synchronous `emit()` calls along the same linear execution path without an intervening `await` (treating `catch` clauses after an `await`-containing `try` body, outside nested closures including `await for`, as starting after a suspension boundary). | — |
| **`avoid_primitive_event_types`** | Warning | Flags `BlocSignal<Event, State>` or `BlocSignalMixin` using primitive or untyped types (`int`, `String`, `bool`, `dynamic`, etc.) as event types. | — |
| **`avoid_pseudo_events_in_telemetry`** | Warning | Flags `emitTelemetry('...')` calls inside `CubitSignal` where the name matches UI event action patterns (`Pressed`, `Clicked`, `Submitted`, etc.). | — |
| **`avoid_emit_or_add_in_computed`** | Error | Flags `emit()` or `add()` calls on state containers inside `computed()` callbacks. | — |
| **`require_hydrated_storage_prefix`** | Warning | Requires concrete `HydratedCubitSignal`, `HydratedBlocSignal`, and `HydratedMixin` classes to override `storagePrefix`. | `Cmd+.` -> Add `@override String get storagePrefix` |
| **`require_hydrated_mixin_init`** | Warning | Requires classes mixing in `HydratedMixin` with `CubitSignalMixin` or `BlocSignalMixin` to call `hydrate()` in constructors. | `Cmd+.` -> Add `hydrate();` |
| **`avoid_unmanaged_signal_subscription`** | Warning | Flags discarded `ReadonlySignal.subscribe(...)` calls whose cleanup closure is not retained. | — |

### Flutter UI Rules


| Rule | Default Severity | Description | Automated Fix |
| :--- | :--- | :--- | :--- |
| **`avoid_emit_in_build`** | Warning | Flags calls to `emit()` or `add()` on state containers directly inside Flutter `Widget.build()` methods. | — |
| **`avoid_unmanaged_signal_effects`** | Warning | Flags unmanaged `effect()` calls inside Flutter `Widget`/`HookWidget`/`State` or Jaspr `Component`/`State` methods outside `build()`. | — |
| **`prefer_bloc_signal_provider_read_in_callbacks`** | Warning | Warns when `context.watch<T>()` is used inside event callback closures (for example `onPressed`), suggesting `context.read<T>()`. | `Cmd+.` -> Replace `watch` with `read` |
| **`avoid_providing_existing_instance_with_create`** | Warning | Flags passing existing variable references to `BlocSignalProvider(create: ...)` instead of `BlocSignalProvider.value(value: ...)`. | `Cmd+.` -> Replace `create:` with `value:` |
| **`avoid_manual_close_on_provided_bloc`** | Warning | Flags calling `.close()` manually on state containers retrieved via `context.read<T>()` or `BlocSignalProvider.of(context)`. | `Cmd+.` -> Remove manual `close()` call |
| **`avoid_invalid_context_select_generics`** | Warning | Flags `context.select<B, R>` where generic parameters are omitted or invalid. | `Cmd+.` -> Reduce type arguments to `<B, R>` |
| **`avoid_context_watch_for_bloc_state`** | Warning | Flags `context.watch<T>()` on state containers inside `build()` methods to prevent missing state emission rebuilds. | `Cmd+.` -> Replace `watch` with `read` / `value<B, S>()` |
| **`avoid_unused_select_result`** | Warning | Flags calling `context.select(...)` as an unused expression statement where the result is discarded. | `Cmd+.` -> Bind result to `final value` |
| **`avoid_bridging_in_build`** | Warning | Flags `.toBlocSignal()`, `.toAsyncBlocSignal()`, `.toValueListenable()`, and `ListenableBlocSignal` calls directly inside UI `build()` methods. | — |
| **`require_child_outside_multi_bloc_signal`** | Warning | Flags `BlocSignalProvider`, `BlocSignalProvider.value`, and `BlocSignalListener` omitting `child:` outside `MultiBlocSignalProvider` / `MultiBlocSignalListener`. | — |
| **`avoid_signal_creation_in_build`** | Warning | Flags direct `signal()`, `computed()`, and `effect()` allocations inside `build()` methods. | — |
| **`avoid_context_select_outside_build`** | Warning | Flags `context.select(...)` and `context.value(...)` calls outside `build()` (callbacks, closures, `computed`/`effect`, or non-`build` lifecycle methods). | `Cmd+.` -> Replace with `context.read<B>()` |

---

## ⚙️ Configuration & Customization

### Enabling/Disabling Rules in `analysis_options.yaml`

To enable or disable specific rules, configure `diagnostics:` under `plugins.bloc_signals_lint` in your root `analysis_options.yaml` (no `dev_dependencies:` entry is needed; use `path:` for local unreleased workspaces):

```yaml
plugins:
  bloc_signals_lint:
    version: ^2.0.0
    diagnostics:
      # Disable a rule
      avoid_duplicate_event_handlers: false
```

### Disabling Rules in Code

To ignore a rule for a specific line or file:

```dart
// Single line ignore
// ignore: bloc_signals_lint/avoid_duplicate_event_handlers
on<Increment>((event, emit) => emit(stateValue + 1));

// File-wide ignore
// ignore_for_file: bloc_signals_lint/avoid_stream_transformers_on_bloc_signal
```

---

## 🧪 Testing Custom Lint Rules (`SCAR-TEST-23`)

When authoring or modifying rules in `bloc_signals_lint`, never test rules using syntactic `parseString()` ASTs or test-local `RecursiveAstVisitor` stubs. Always execute the production `AnalysisRule.registerNodeProcessors(...)` pipeline against a semantically resolved AST using `runLintRule` (and `runLintFix` for `ResolvedCorrectionProducer` quick-fixes) and `disposeLintTestHarness` in `bloc_signals_lint/test/src/lint_test_harness.dart`:

- **End-to-End Semantic Resolution**: `runLintRule(MyLintRule(), sourceCode)` and `runLintFix(MyLintRule(), MyLintFix.new, sourceCode)` provision a temporary workspace with `.dart_tool/package_config.json` (`package:bloc_signals`, `package:bloc_signals_replay`, `package:flutter`), resolve full semantic types (`DartType`, `InterfaceElement`, `TypeChecker`) via `AnalysisContextCollection` and `getResolvedUnit`, and return reported `ReportedLint` diagnostics or transformed source code.
- **`flutter_tester` SDK Discovery**: `lint_test_harness.dart` automatically walks up from `Platform.resolvedExecutable` to locate `dart-sdk/lib/_internal/allowed_experiments.json` when invoked under `flutter test`.
- **Lifecycle Cleanup**: Always register `tearDownAll(disposeLintTestHarness);` at the top of `main()` in lint test suites to delete the temporary workspace directory and reset the shared `AnalysisContextCollection`.
