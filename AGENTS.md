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
    bloc_signals: ^1.0.0
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

### 8. Observability & OpenTelemetry (`bloc_signals_otel`)
When designing telemetry observers (such as `OtelBlocSignalObserver`):
- **Leak Prevention**: Because `onTransition` is not guaranteed to fire for every event (e.g., on de-duplicated states or errors), active span maps MUST be capped in size (default 100) and evict oldest keys. Furthermore, `onClose(BlocSignalBase)` MUST purge and end lingering spans to prevent memory accumulation upon container disposal.
- **Span Correlation on Errors**: Route exceptions directly to the active event span inside `onError` using identity hash-matching, rather than creating disconnected transient error spans.

### 9. String Representation (`toString()`)
`BlocSignalBase` overrides `toString()` to output `$runtimeType($stateValue)`, providing immediate diagnostic visibility across all `CubitSignal` and `BlocSignal` subclasses.

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
* **Constructor Parameter vs. Field Naming (`equality:` vs `.equalityCheck`)**: Note that `SignalOptions` uses `equality:` as its constructor parameter name, but exposes the getter field name on `SignalOptions` as `.equalityCheck`.
* **Equality Evaluation Precedence**: `options?.equalityCheck` takes precedence over the constructor `equals:` parameter or subclass `@override bool equals(StateType previous, StateType current)`.

### 15. Pub.dev Transitive Dependency Enforcement
When publishing packages to pub.dev:
* **Explicit Dependency Declaration**: Any package directly imported in `lib/` (even if imported only for a type annotation like `SignalEquality` or re-exported transitively) MUST be explicitly listed under `dependencies:` in `pubspec.yaml`. Otherwise, `flutter pub publish` validation fails with missing dependency errors.

### 16. GitHub Actions Inline Script Syntax Safety
When writing inline Node.js scripts in `.github/workflows/*.yml` via `actions/github-script`:
* **Avoid `${...}` Interpolation**: Avoid JS template literal `${variable}` syntax inside YAML block scalars (`script: |`), as GitHub Actions attempts to parse `${...}` as GitHub Actions expressions. Use standard string concatenation (`'hello ' + name`) instead.

### 17. State Persistence & `Object?` Serialization (`bloc_signals_hydrate`)
When designing state persistence adapters (such as `HydratedCubitSignal` and `HydratedBlocSignal`):
* **`dynamic` / `Object?` Serialization**: Accept `dynamic` / `Object?` in `fromJson` and `toJson` rather than restricting to `Map<String, dynamic>`. Standard Dart `jsonDecode` returns primitives (`num`, `String`, `bool`, `List`, `Map`). Allowing `dynamic` enables primitive and collection cubits (`int`, `String`, `List<String>`) to hydrate cleanly without forcing artificial map wrappers (`{"value": 42}`).
* **Synchronous Constructor Hydration**: Hydrate state synchronously during container constructor execution (`initHydratedState`) so initial widget builds render hydrated data on frame 1 without UI flickers.
* **Super Emission on Clear**: Use `super.emit(initialState)` inside `clear()` to reset state value without re-persisting `initialState` back into storage.

### 18. Universal DevTools Telemetry & Multi-Model Fallbacks (`DevToolsBlocSignalObserver`)
When implementing developer tools and telemetry observers:
* **Core Package Placement**: Place `developer.postEvent` observers in core Dart packages using `dart:developer` (standard Dart SDK) rather than restricting to Flutter UI packages. This unlocks DevTools telemetry for all Dart environments (CLI, server, Jaspr web apps, Flutter) with zero Flutter SDK overhead.
* **Multi-Model API Resilience**: In automated GitHub Action API workflows querying LLMs, iterate across candidate models (`gemini-1.5-flash-002`, `gemini-2.5-flash`) for fallback resilience against model deprecations or endpoint migration changes.

### 19. Pure Dart vs. Flutter Signal Factory Isolation (`signals_core` vs `signals_flutter`)
When importing signal packages:
* **Core Dart Import (`signals_core`)**: Core packages (`bloc_signals`, `bloc_signals_riverpod`, `bloc_signals_hydrate`, `bloc_signals_otel`) MUST import `package:signals_core/signals_core.dart` exclusively so signals remain pure Dart primitives without linking to the Flutter SDK.
* **Flutter Integration Hook (`signals_flutter`)**: Flutter UI packages (`bloc_signals_flutter`) import `package:signals_flutter/signals_flutter.dart`. When included in a Flutter application, `signals_flutter` hooks global signal creation factories (`signal()`, `computed()`) to produce Flutter-bound signals capable of automatically notifying Flutter elements and triggering widget rebuilds.

### 20. `dart_test.yaml` Test Discovery Path Restriction
When configuring test runners in packages with `_test.dart` entrypoints:
* **`_test.dart` Entrypoint Discovery Conflict**: Package entrypoint libraries ending in `_test.dart` (such as `package:bloc_signals_test`'s `lib/bloc_signals_test.dart`) match test runner globs when discovered recursively.
* **Path Restriction Configuration**: To prevent test discovery failures, ensure `dart_test.yaml` is present specifying `paths: [test/]` to restrict test runner path matching strictly to `test/` directories.

### 21. Diagnostic String Representation (`toString()`)
When working with or debugging state containers:
* **Baseline Output**: `BlocSignalBase` overrides `toString()` to output `$runtimeType($stateValue)`, providing immediate diagnostic visibility across all `CubitSignal` and `BlocSignal` subclasses.

### 22. Website Structure, Publications Sync & Deployment Protocol (`blocsignal.dev`)
When updating or publishing changes to the `blocsignal.dev` website (`website/`):
* **Page Architecture & Routing**: The Jaspr web application supports `HomePage` (`/`), `ShowcasePage` (`/showcase`), `PortedExamplesPage` (`/ported-examples`), `MinesweeperPage` (`/minesweeper`), and `PublicationsPage` (`/publications`). Routes support both HTML5 history API pathnames and `/#<route>` hash routing.
* **Automated DEV.to Publications Sync Tool (`website/tool/update_publications.dart`)**:
  - `website/tool/update_publications.dart` queries the DEV.to public API (`https://dev.to/api/articles?username=randalschwartz&per_page=50`), extracts canonical article URLs, titles, descriptions, reading times, publish dates, and tags, and automatically regenerates `website/lib/src/pages/publications_page.dart`.
  - **Execution Command**: Run `cd website && dart run tool/update_publications.dart` whenever new DEV.to articles or media are published.
* **Version Alignment**: `website/lib/src/components/package_catalog.dart` MUST be updated with newly published package version numbers.
* **Hero Snippet Alignment**: `website/lib/src/components/hero.dart` code snippets MUST reflect published pubspec dependency constraints.
* **Re-compile & Deploy Protocol**:
  1. Compile static bundle and generate route fallback index files for static servers (`dhttpd` and Firebase Hosting):
     ```bash
     cd website && dart run tool/update_publications.dart && mkdir -p build/www && dart compile js lib/main.dart -o build/www/main.dart.js && cp -r web/* build/www/ && cp build/www/index.html build/www/publications/index.html && cp build/www/index.html build/www/showcase/index.html && cp build/www/index.html build/www/ported-examples/index.html && cp build/www/index.html build/www/minesweeper/index.html
     ```
  2. Deploy to Firebase Hosting: `npx -y firebase-tools deploy --only hosting`.

### 23. Replay State History Architecture (`bloc_signals_replay`)
When implementing state history and undo/redo capabilities:
* **`ReplayCubit` & `ReplayCubitMixin`**: Wrap `CubitSignal` to provide undo and redo history queues (`_ChangeStack`).
* **`ReplayBloc` & `ReplayBlocMixin`**: Wrap `BlocSignal` to provide undo/redo history. Synthetic `_Undo` and `_Redo` events subclass `ReplayEvent`.
* **Covariant Event Routing**: `ReplayBlocMixin` overrides `onTransition` and `onEvent` using `covariant ReplayEvent` to route synthetic events to `BlocSignalObserver` without requiring `_Undo` / `_Redo` to subclass user event types.
* **Super Method Forwarding in `onEvent`**: `onEvent` overrides must call `super.onEvent(event)` for user events to route them to registered `on<E>` handlers.

### 24. Pub.dev Package Publishing Requirement
When publishing packages to pub.dev:
* **Mandatory `LICENSE` File**: Every published package root directory MUST contain a `LICENSE` file in addition to `pubspec.yaml`, `README.md`, and `CHANGELOG.md`.

### 25. Jaspr Web Component Reactivity & Element Hierarchy (`bloc_signals_jaspr`)
When implementing or working with Jaspr web component bindings:
* **Component Instance Getter**: In Jaspr `State<T extends StatefulComponent>`, the target component instance getter is `.component` (unlike Flutter's `.widget`).
* **Component Lifecycle Updates**: Component updates use `didUpdateComponent(T oldComponent)` (unlike Flutter's `didUpdateWidget(T oldWidget)`).
* **Element Mount Check**: In Jaspr `Element`, element mounting state is checked via `element.binding != null` or `context.binding != null`.
* **Text Node Declarations**: Text nodes in Jaspr `package:jaspr/dom.dart` are declared via `Component.text('...')` (deprecated top-level `text('...')` should be avoided).

### 26. Jaspr `InheritedComponent` Resolution & Ergonomics (`bloc_signals_jaspr`)
When designing Jaspr `InheritedComponent` providers and multi-providers:
* **O(1) Context Lookups**: Unlistened context lookups (`listen: false`) use `getElementForInheritedComponentOfExactType` (O(1) resolution), while listened lookups (`listen: true`) use `dependOnInheritedComponentOfExactType`.
* **Null Child Composition Ergonomics**: Optional `child` parameters defaulting to `const _NullComponent()` (where `_NullComponent` returns `const Component.empty()`) enable clean array syntax inside `MultiBlocSignalProvider` and `MultiBlocSignalListener` without requiring dummy child elements at call sites.

### 27. Pub.dev 160 Pub Points Scoring & Documentation Requirements
When publishing packages to pub.dev to satisfy all 160/160 pub points quality scoring metrics:
* **Explicit Constructors for Dartdoc Analysis**: Implicit default constructors on classes without explicit constructors (e.g. `abstract class BlocSignalObserver` or `class Mutex`) are treated as un-documented symbols by `dartdoc` analysis when re-exported. Always declare explicit documented constructors (e.g. `const BlocSignalObserver();` and `Mutex();`).
* **Package Example Requirement**: Every published pub.dev package MUST include a runnable `example/example.dart` top-level file under `example/` in the package root to satisfy the 10/10 points "Package has an example" score checklist rule.

### 28. Monorepo README Package Catalog Consistency
When standardizing or updating package documentation across the monorepo:
* **Uniform Package Catalog Table**: Ensure all 10 workspace package README files feature the exact same uniform 10-package ecosystem catalog table with pub version badges and descriptions.

### 29. `context.select` Generic Type Signature Ergonomics
When using `context.select` in `bloc_signals_flutter`:
* **2 Generic Type Parameters**: Pass exactly **2** generic type parameters: `<B, R>` where `B` is the `BlocSignalBase` container type (for example, `UserCubit`) and `R` is the selected value type (for example, `bool`).
* **Callback Receives Container**: The selector callback receives the **`bloc` container instance** as its single parameter (`(bloc) => bloc.stateValue.property`), not the state object directly. This allows selecting computed properties, signals, or state fields cleanly.

### 30. Phrasing & Style Standard (No "e.g." or "i.e.")
When authoring code, documentation, comments, pull requests, or article content:
* **No `e.g.`**: Never use the abbreviation `e.g.`. Always write out **"for example"**.
* **No `i.e.`**: Never use the abbreviation `i.e.`. Always write out **"that is"**.

### 31. Constructor Parameter and State Access Differences from Felix BLoC (`package:bloc`)
When migrating code or authoring state containers:
* **Named Constructor Parameter**: `BlocSignal` and `CubitSignal` constructors use named parameter `initialState:` (for example, `: super(initialState: 0)`), NOT positional `: super(0)`.
* **`stateValue` vs `state`**: `state` exposes `ReadonlySignal<StateType>` for signals reactivity. To access the current raw state value inside methods or event handlers, use `stateValue` (for example, `emit(stateValue + 1)`). Writing `emit(state + 1)` causes a type compilation error.


