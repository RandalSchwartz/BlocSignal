# AI Agent Developer Handbook (`AGENTS.md`)

Welcome, agent! This document details the development standards, architectural designs, and workspace configurations of the `BlocSignal` monorepo. Please review and align all your code changes with these guidelines.

---

## 🏗️ Workspace Layout & Monorepo Structure

We use a native Dart workspace (supported in Dart 3.5+) instead of Melos.
- **Root Configuration**: [pubspec.yaml](pubspec.yaml) defines the workspace.
- **Members**:
  - `bloc_signals` (Core pure Dart package)
  - `bloc_signals_flutter` (Flutter bindings)
  - `bloc_signals_flutter/example` (Example Flutter application)


### Dependency Management
To satisfy pub.dev publishing requirements while maintaining local developer workspaces, **always use version constraints rather than path dependencies for intra-workspace dependencies**. 
- Example in `bloc_signals_flutter/pubspec.yaml`:
  ```yaml
  dependencies:
    bloc_signals: ^0.1.0
  ```
- The native Dart workspace compiler will automatically route this constraint to the local workspace folder during development.

---

## ⚡ Architectural Guidelines

`BlocSignal` bridges the BLoC pattern with Rody Davis's signals v7 primitives.

### 1. Synchronous Propagation
Unlike classic BLoC which runs asynchronously on microtask-queue Streams, state updates in `BlocSignal` propagate **synchronously**. Calling `emit(newState)` triggers downstream recalculations and rebuilds in the exact same frame. Keep this synchronous behavior in mind when designing state relationships and test expectations.

### 2. Automatic De-duplication
Signals automatically de-duplicate identical states using `==` equality. If you call `emit()` with a state that is equal to the current state, downstream effects and widget builders will **not** trigger.

### 3. Stream Transformations
Because `BlocSignal` does not use streams under the hood, standard stream-transformer properties (e.g. `debounce`, `throttle`, `switchMap`) are not available. Use custom timing triggers or signal effects to reproduce these behaviors.

### 4. Lifecycle & Disposal (`isClosed`)
Calling `close()` disposes of the underlying `SignalModel` effect tracking and marks the bloc as closed (`isClosed = true`). Subsequent calls to `add(event)` or `emit(state)` are dropped automatically to prevent memory leaks and unexpected side-effects. The state remains readable after closure to align with classic BLoC semantics.

### 5. Asynchronous Event Handling
We support `FutureOr<void>` handlers in `onEvent(event)`. If an event handler triggers asynchronous processes (Futures), operational exceptions are captured and reported via `onError` automatically, while programmer faults (`Error` objects) are rethrown to fail fast.

### 6. Transition Event Tracing
Transitions triggered via `emit()` are associated with their causing `event` using dynamic Zone context values (`Zone.current[_zoneEventKey]`). This provides full event traceability to observers without modifying the signature of `emit()`.

### 7. Event Handler Registry (`on<Event>`)
To support BLoC-style syntax, events can be registered using `on<E>((event, emit) => ...)` inside constructor scopes:
- **Single Registration**: Enforces that each event type `E` is registered at most once; duplicates throw a `StateError` in debug mode.
- **Concurrent Future Coordination**: Multiple matching event handlers have their returned futures orchestrated concurrently using `Future.wait` rather than sequential chaining.
- **Backwards Compatibility**: Subclasses can continue to override `onEvent(event)` manually if they do not wish to use the registry.

### 8. Observability & OpenTelemetry (`otel_bloc_signals`)
When designing telemetry observers:
- **Leak Prevention**: Because `onTransition` is not guaranteed to fire for every event (e.g., on de-duplicated states or when errors bypass transition logic), ensure any active span maps are capped in size (e.g., 1000 items) and evict oldest keys to prevent memory leaks.
- **Span Correlation on Errors**: Route exceptions directly to the active event span inside `onError` using identity hash-matching, rather than creating disconnected transient error spans.

---

## 🛠️ Agent Plugin Maintenance

The public agent plugin owns its skill bundle at `plugins/bloc-signals/skills/bloc-signals/`. Run `dart run tool/validate_agent_plugin.dart` after changing the plugin or either marketplace catalog.

**Crucial Agent Instruction**:
* Whenever you modify the framework architecture, introduce new UI builders/providers, change testing conventions, or update telemetry spans, **you must update the corresponding skill file(s)** under `plugins/bloc-signals/skills/bloc-signals/`.
* Keep the main API examples, FAQs, and migration path snippets in sync with the codebase state.


---

## 🧪 Code Quality Standards


We maintain a production-grade codebase with strict enforcement rules:

1. **Strict Linting**: We use `very_good_analysis` for code analysis. Ensure all public member APIs are documented with complete doc comments (`///`) and examples.
2. **100% Test Coverage**: We maintain **100% line coverage** for both packages. If you modify or add features, write unit tests to keep coverage at 100%.
   - **Running Coverage (Core)**:
     ```bash
     dart test --coverage=coverage
     dart run coverage:format_coverage --report-on=lib --in=coverage --out=coverage/lcov.info --lcov
     ```
   - **Running Coverage (Flutter)**:
     ```bash
     flutter test --coverage
     ```
3. **Format**: Always run `dart format .` to maintain uniform formatting before committing.
