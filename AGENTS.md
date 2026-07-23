# AI Agent Developer Handbook (`AGENTS.md`)

Welcome, agent! This document details the development standards, architectural designs, and workspace configurations of the `BlocSignal` monorepo. Please review and align all your code changes with these guidelines.

---

## 🏗️ Workspace Layout & Monorepo Structure

We use a native Dart workspace (supported in Dart 3.5+) instead of Melos.
- **Root Configuration**: [pubspec.yaml](pubspec.yaml) defines the workspace.
- **Members**:
  - `bloc_signals` (Core pure Dart package)
  - `bloc_signals_flutter` (Flutter bindings & Listenable interop)
  - `bloc_signals_flutter/example` (Example Flutter application)
  - `bloc_signals_riverpod` (Bidirectional Riverpod interop adapters)
  - `bloc_signals_test` (Declarative unit testing utilities)
  - `bloc_signals_lint` (Static analysis lints & IDE diagnostics)




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
To support BLoC-style syntax, events can be registered using `on<E>((event, emit) => ..., transformer: ...)` inside constructor scopes:
- **Single Registration**: Enforces that each event type `E` is registered at most once; duplicates throw a `StateError` in debug mode.
- **Concurrent Future Coordination**: By default, multiple matching event handlers have their returned futures orchestrated concurrently using `Future.wait`.
- **Event Concurrency Transformers**: Handlers accept an optional `transformer` (such as `droppable()`, `sequential()`, `restartable()`, or a custom `Mutex` lock) to control execution strategy without Rx streams.
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

---

## 🧠 Compounded Learnings & Best Practices

### 1. Overriding `@mustCallSuper` Methods
When overriding a method annotated with `@mustCallSuper` (e.g., `onEvent`), you MUST invoke `super.<method>`.
* If the method returns `FutureOr<void>` (like `onEvent`), invoking it directly in a synchronous context will trigger `discarded_futures` lints.
* To resolve this:
  * If the override does not need to be async, wrap the call as: `unawaited(Future.value(super.onEvent(event)));` (requires importing `dart:async`).
  * If the override is async, declare the signature as:
    ```dart
    @override
    Future<void> onEvent(Event event) async {
      await super.onEvent(event);
      // Custom async handling
    }
    ```

### 2. O(1) InheritedWidget Lookup
When retrieving a parent `InheritedWidget` from `BuildContext` without registering a rebuild dependency (e.g., inside a `read()` or non-listening `of()` method), do **NOT** use `findAncestorWidgetOfExactType` (which runs in O(N) by traversing the tree). Instead, use `getElementForInheritedWidgetOfExactType` which resolves in O(1) time and extracts the widget from the element:
```dart
final provider = context
    .getElementForInheritedWidgetOfExactType<MyInheritedWidget>()
    ?.widget as MyInheritedWidget?;
```

### 3. InheritedWidget Dependency Registration on Swapping
When widgets resolve an ancestor provider from `BuildContext` (e.g., resolving `BlocSignalProvider` in a builder or listener), always use `listen: true` (which calls `dependOnInheritedWidgetOfExactType`) if the widget subtree might be cached (like `const` widgets or cached builders) and the provided instance could change. If `listen: false` is used, the widget will not register a dependency and will fail to rebuild/update if a parent widget swaps the provided instance.

### 4. Optimized Rebuilds via Computed and State
Using `SignalBuilder` directly with a `computed` signal inside a build method can trigger redundant builds. Even if the computed output value is unchanged, the dirty status of its dependencies will trigger the `SignalBuilder` to rebuild. For optimal performance, wrap selection logic in a `StatefulWidget` that manually subscribes to the computed signal inside an `effect()` callback, and calls `setState` **only** if the evaluated value actually changed. Ensure that you also re-initialize the computed signal in `didUpdateWidget` if the selector callback closure changes to prevent using stale references.

### 5. Memory Leaks in Expando Values (WeakReference Solution)
When using an `Expando` mapping a key (e.g. `Element`) to some state/subscription object, ensure the stored object does NOT hold a strong reference back to the key (either directly or transitively inside closures/effects). Doing so creates a strong reference cycle that prevents garbage collection of both the key and the value from the `Expando`. Always wrap references to the key inside the value object with a `WeakReference<Key>` to allow natural garbage collection.

### 6. Declarative Testing & Observer Scoping (`bloc_signals_test`)
When orchestrating test helpers like `blocSignalTest`:
* Set `BlocSignalObserver.observer` to a test observer **before** invoking `build()` so that `onCreate` lifecycle events are captured.
* Maintain the test observer active through `await bloc.close()` so `onClose` is captured, and restore the previous observer in a `finally` block.
* Pass parent observer calls down to `previousObserver` to prevent breaking global telemetry or logging set up outside individual tests.
* State seeding is performed directly in `build()` (e.g. `build: () => CounterBloc(initialState: 5)`).

### 7. Analyzer Rule Testing ("When testing rules, test the rules")
When authoring custom lint plugins or analyzer diagnostics:
* Do not rely solely on unit tests that verify `PluginBase` registration or rule metadata.
* Always write sample code AST integration tests (e.g. using `package:analyzer/dart/analysis/utilities.dart`'s `parseString` or custom lint test runners).
* Test both **negative cases** (sample problem code that must trigger detection) and **positive cases** (sample valid code that must pass without flags).

### 8. Extension-Based Interop Protocols & Stream Auto-Disposal
When designing interop adapters, conversion helpers, or external protocol bridges (e.g., `toStream()`, `toBlocSignal()`):
* Do **NOT** pollute or burden core base class interfaces (`BlocSignalBase`). Implement conversion helpers as **Dart Extensions** exported from the main library entrypoint (`package:bloc_signals/bloc_signals.dart`). This keeps base class contracts unburdened while giving developers out-of-the-box IDE autocomplete convenience.
* When wrapping external event streams (e.g., `StreamBlocSignal`), always handle `onDone` in `stream.listen()` to automatically close the container instance when the source stream completes (`onDone: () => unawaited(close());`).

### 9. Riverpod Interoperability & Subscription Duplication Prevention (`bloc_signals_riverpod`)
When creating Riverpod interop bridges:
* **`ProviderListenable` as Pivot**: Use `ProviderListenable<T>` to adapt Riverpod state into `BlocSignalBase`. Use `ProviderContainer.listen` to sync state changes synchronously.
* **Auto-Disposal Binding**: Automatically bind `ref.onDispose(bloc.close)` when passing a `Ref` or `WidgetRef` to `.toBlocSignal(ref)` to prevent `autoDispose` retain count leaks.
* **Avoiding Subscription Duplication in Provider Callbacks**: Never call `state.subscribe(...)` inside standard `Provider((ref) => ...)` closures if `ref.invalidateSelf()` is called inside the callback, as Riverpod re-executes the closure on invalidation, duplicating listeners exponentially. Use `Notifier` / `NotifierProvider` where `build()` runs once.
* **Riverpod 3 Export Compatibility**: In Riverpod 3.3+, `ProviderListenable` is exported via `package:riverpod/src/internals.dart`. Importing `src/internals.dart` ensures cross-version compatibility for Riverpod 2 and 3.

### 10. Flutter `Listenable` & `package:provider` Interoperability (`bloc_signals_flutter`)
When bridging Flutter `Listenable` / `ChangeNotifier` / `ValueListenable`:
* **Static Extension Resolution**: Flutter's `Listenable` (`package:flutter/foundation.dart`) and Riverpod's `ProviderListenable` (`package:riverpod`) are separate interfaces in Dart. Extension methods resolve statically based on the target type with zero collisions.
* **Listener Teardown**: `ListenableBlocSignal.close()` invokes `listenable.removeListener(_onListenableChanged)`. `_BlocSignalValueListenable.dispose()` unsubscribes from `bloc.state.subscribe(...)`.

### 11. Workflow Protocol: Delivery Path Verification & Mandatory Bot Review
When managing tickets:
* **Verify Delivery Path Early**: Immediately after ticket selection (Gate 1), clarify whether the change will be delivered via a GitHub Pull Request (PR) or direct commit to `main`.
* **Mandatory Bot Review (GCA Persona)**: Even when bypassing a GitHub PR for direct commits to `main`, NEVER skip the automated Bot Triage Simulation (GCA Persona). Objective GCA review must always be performed before committing and publishing to catch boundary edge cases (such as missing `onError` exception routing).

### 12. Streamless Event Concurrency & Closure Allocation Optimization
When designing event concurrency transformers for `BlocSignal`:
* **Streamless Higher-Order Functions**: Do not depend on Rx Streams or `package:bloc_concurrency`. Use pure Dart higher-order functions (`(event, handler, emit) => ...`) and `Mutex` locks for zero-stream-allocation event coordination on `on<E>(..., transformer: ...)`.
* **Inlined Closure Guards**: Avoid creating tear-off functions or intermediate closures inside transformer callbacks (such as `restartable`). Inline conditional checks `(state) { if (currentToken == executionToken) emit(state); }` directly to prevent per-event heap allocations during high-frequency event bursts.

### 13. Benchmarking Rigor & Stream Microtask Draining
When authoring performance benchmarks or execution throughput measurements (`package:benchmark_harness`):
* **Drained Stream Measurement**: Calling `bloc.add(event)` in classic BLoC only measures microtask queue insertion time. To measure true end-to-end event-to-state execution latency, always await microtask queue draining (`await bloc.stream.take(N).drain()`) to compare fairly against synchronous `BlocSignal` emissions.
* **Flutter Engine Execution Environment**: Benchmark runners that import `package:flutter` UI bindings cannot run via bare `dart run`. Always provide a `flutter test` test wrapper (`test/benchmark_runner_test.dart`) to run benchmarks under the Flutter engine test environment.

### 14. Custom Equality & `SignalOptions` Delegation
When adding state container configuration options (such as custom equality comparators) to `BlocSignalBase`:
* **`SignalOptions` Delegation**: Always delegate directly to `SignalOptions<StateType>(equality: SignalEquality<StateType>.custom((a, b) => this.equals(a, b)))` from `preact_signals`.
* **Signal Graph Sync**: Passing custom equality directly to the underlying `signal` ensures that both container transition pipelines (`emit`) and downstream `ReadonlySignal` observers (`computed` derivations, `effect` callbacks, and `SignalBuilder` widgets) operate on 100% unified equality rules.

### 15. Pub.dev Transitive Dependency Enforcement
When publishing packages to pub.dev:
* **Explicit Dependency Declaration**: Any package directly imported in `lib/` (even if imported only for a type annotation like `SignalEquality` or re-exported transitively) MUST be explicitly listed under `dependencies:` in `pubspec.yaml`. Otherwise, `flutter pub publish` validation fails with missing dependency errors.




