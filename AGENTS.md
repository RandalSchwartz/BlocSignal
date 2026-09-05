# AI Agent Developer Handbook (`AGENTS.md`)

Welcome, agent! This document defines the core workspace constitution, SDK baselines, code quality standards, and on-demand guidance routing for the `BlocSignal` monorepo. Align all code changes with these guidelines.

---

## 🏗️ Workspace Layout & Monorepo Structure

We use a native Dart workspace (supported in Dart 3.5+) instead of Melos.
- **Root Configuration**: [pubspec.yaml](pubspec.yaml) defines the workspace.
- **Member Packages**:
  - `bloc_signals` (Core pure Dart package)
  - `bloc_signals_flutter` (Flutter bindings & Listenable interop)
  - `bloc_signals_bloc` (Classic BLoC 8/9 interop adapters)
  - `bloc_signals_riverpod` (Bidirectional Riverpod interop adapters)
  - `bloc_signals_test` (Declarative unit testing utilities)
  - `bloc_signals_lint` (Static analysis lints & IDE diagnostics - 15 rules & automated quick-fixes)
  - `bloc_signals_hydrate` (Persistent state storage adapters)
  - `bloc_signals_otel` (OpenTelemetry tracing & metrics)
  - `bloc_signals_replay` (State history & undo/redo tracking)
  - `bloc_signals_jaspr` (Jaspr web component bindings)
  - `bloc_signals_devtools` (DevTools extension & VM Service RPC)

### Intra-Workspace Dependency Management
To satisfy pub.dev publishing requirements while maintaining local developer workspaces, **always use version constraints rather than path dependencies for intra-workspace dependencies** (for example `bloc_signals: ^1.0.0` in `bloc_signals_flutter/pubspec.yaml`). The Dart workspace compiler routes this constraint to the local workspace folder automatically during development.

### SDK & Language Versioning Policy
- **Monorepo Workspace, Tooling & Website (`/`, `tool/`, `website/`, `benchmarks/`)**:
  - Requires `sdk: ^3.13.0` for development, website tooling, CI orchestration, and benchmarks.
  - Allows full use of modern Dart 3.13 language ergonomics (primary constructors, parameter shorthands, newer core library APIs).
- **Published Packages (`bloc_signals*`)**:
  - Must specify and strictly conform to `sdk: ^3.5.0`.
  - Must NOT use Dart language features or APIs introduced after Dart 3.5 (for example primary constructors).
- **Examples, Demos & Documentation**:
  - Show both Dart 3.5 (traditional syntax) and Dart 3.13 (modern syntax) side-by-side whenever feasible to highlight modern developer ergonomics while preserving baseline reference patterns.

---

## ⚡ Core Framework Principles

1. **Synchronous Propagation**: State updates propagate synchronously in the exact same frame on `emit(newState)`.
2. **Automatic De-duplication**: Transitions skip when `newState == currentState` by default.
3. **Streamless Execution**: No Rx streams or microtask queues under the hood; event transformers use higher-order functions and async `Mutex` locks.
4. **Constructor & State Ergonomics**: Constructors require named parameter `initialState:` (`: super(initialState: ...)`). Use `stateValue` for raw value access (`emit(stateValue + 1)`); `state` exposes `ReadonlySignal<StateType>` for reactive subscriptions.
5. **Lifecycle & Disposal**: `close()` marks `isClosed = true` and cleans up effects. Subsequent `add()` or `emit()` calls are safely dropped.
6. **Prefer Inline `late final` Computed Properties**: For derived, observable state properties on a `CubitSignal` or `BlocSignal`, prefer declaring and initializing them directly as fields using type inference (for example `late final isCartEmpty = computed(() => stateValue.items.isEmpty);`) rather than two-step manual type declarations and constructor-body assignments (`late final ReadonlySignal<bool> isCartEmpty;` + `isCartEmpty = computed(...)`).

---

## 🧪 Code Quality Standards

1. **Strict Linting**: We use `very_good_analysis`. All public member APIs must have complete doc comments (`///`) with runnable code examples.
2. **100% Test Coverage**: Maintain **100% line coverage** across all packages.
   - Core packages: `dart test --coverage=coverage`
   - Flutter packages: `flutter test --coverage`
   - Monorepo runner: `dart run tool/run_workspace_tests.dart`
3. **Format**: Always run `dart format .` to maintain uniform formatting before committing.
4. **Phrasing Standard**: Never use the abbreviation `e.g.` (write **"for example"**) or `i.e.` (write **"that is"**).

---

## 📚 On-Demand Guidance & Routing

Detailed architecture guides and maintainer operations are maintained in dedicated reference documents. **Read the relevant document on demand using `view_file` when executing specialized tasks**:

### Public Framework Skills (`plugins/bloc-signals/skills/bloc-signals/`)
- [SKILL.md](plugins/bloc-signals/skills/bloc-signals/SKILL.md): Plugin skill entrypoint and router.
- [decision_matrix.md](plugins/bloc-signals/skills/bloc-signals/decision_matrix.md): State modeling decision rubric, container comparison matrix, and heuristics.
- [core.md](plugins/bloc-signals/skills/bloc-signals/core.md): Core event dispatch, equality, `@mustCallSuper`, error handling, and reactive ownership.
- [flutter.md](plugins/bloc-signals/skills/bloc-signals/flutter.md): Providers, listeners, builders, consumers, `context.select<B, R>`, and widget rebuild optimizations.
- [testing.md](plugins/bloc-signals/skills/bloc-signals/testing.md): Declarative unit testing (`blocSignalTest`), observer scoping, and test runners.
- [jaspr.md](plugins/bloc-signals/skills/bloc-signals/jaspr.md): Jaspr web components, reactivity, and HTML bindings.
- [hydration.md](plugins/bloc-signals/skills/bloc-signals/hydration.md): Hydrated state persistence and JSON serialization.
- [replay.md](plugins/bloc-signals/skills/bloc-signals/replay.md): Undo/redo state history and replay architecture.
- [interoperability.md](plugins/bloc-signals/skills/bloc-signals/interoperability.md) & [riverpod_migration.md](plugins/bloc-signals/skills/bloc-signals/riverpod_migration.md): Riverpod, Flutter Listenable, and Stream bridges.
- [devtools.md](plugins/bloc-signals/skills/bloc-signals/devtools.md), [lint.md](plugins/bloc-signals/skills/bloc-signals/lint.md), [otel.md](plugins/bloc-signals/skills/bloc-signals/otel.md): DevTools extensions, custom linter rules (15 rules and automated IDE quick-fixes), and OpenTelemetry.

### Internal Maintainer Operations (`doc/internals/`)
- [website_and_publications.md](doc/internals/website_and_publications.md): `blocsignal.dev` architecture, DEV.to publication sync tools, static compilation, local preview, and Firebase deployment.
- [publishing_and_scoring.md](doc/internals/publishing_and_scoring.md): 160/160 pub.dev points checklist, explicit constructors for dartdoc, package examples, and README catalog tables.
- [benchmarks_and_workflow.md](doc/internals/benchmarks_and_workflow.md): Benchmark microtask draining, batch UI updates, GitHub Actions script safety, and maintainer delivery protocols.
- **Article Archive Maintenance (`doc/articles/`)**: Always maintain the local markdown archive in `doc/articles/` with every newly published DEV.to article by running `dart run tool/sync_all_articles.dart` to provide rich contextual knowledge for developers and AI agents.

---

## 🩹 Repository Scars & Crash Defenses

### 🩹 Scar: Dart 3.13 Primary Constructor Super-Invocation Trap
- **The Wound**: Documentation code samples placed constructor invocations directly in `extends` clauses (such as `extends CubitSignal<int>(initialState: 0)`) or wrote `this() : super(...)`, resulting in syntax errors for developers copying documentation samples.
- **The Trap / Suboptimal Local Minimum**: Writing code samples as unvalidated string literals in documentation components without automated compiler or AST/regex validation.
- **The Permanent Reflex**: In Dart 3.13, an `extends` clause only accepts a type name; super-initialization must use in-body `this : super(...)` or header `super.param`. All documentation code blocks must be protected by automated component-scanning unit tests in CI (`website/test/docs_code_snippets_syntax_test.dart`).

### 🩹 Scar: context.watch vs State-Driven UI Rebuilds in Documentation Samples
- **The Wound**: Documentation code samples or recipes used `final cubit = context.watch<T>()` to read state or signal values in `StatelessWidget.build()`. In `bloc_signals_flutter`, `context.watch` tracks provider container instance swapping only, not state emissions, resulting in forms and views failing to rebuild when state changes.
- **The Trap / Suboptimal Local Minimum**: Conflating `context.watch` in BlocSignal with classic `flutter_bloc`'s stream-backed inherited widget rebuilds.
- **The Permanent Reflex**: In documentation snippets and client UI, always retrieve state containers via `context.read<T>()` and bind reactive UI rebuilds via `BlocSignalBuilder<B, S>` or `context.select<B, R>((bloc) => ...)`. Guarded continuously by automated CI component-scanning unit tests in `website/test/docs_code_snippets_syntax_test.dart`.

### 🩹 Scar: Flutter Pub vs Dart Pub in Monorepo Workspace Publishing
- **The Wound**: Running `dart pub publish` or `dart pub publish --dry-run` in member packages within a Dart workspace that contains Flutter packages (such as `riverpod_marvel_example` or `bloc_signals_flutter`) fails with `Because riverpod_marvel_example requires the Flutter SDK, version solving failed. Flutter users should use flutter pub instead of dart pub.`
- **The Trap / Suboptimal Local Minimum**: Assuming pure Dart member packages can be validated or published via `dart pub` when part of a mixed Dart/Flutter workspace.
- **The Permanent Reflex**: In Dart workspaces containing Flutter packages or examples, always execute `flutter pub publish [--dry-run]` rather than `dart pub publish` across all member packages.

### 🩹 Scar: Symmetrical Dual-Track Async Adapters & AsyncState Projection
- **The Wound**: Asymmetric conversion APIs where `Stream` supported raw `.toBlocSignal(initialState:)` while `Future` only supported `futureSignal`, causing confusion between raw values (`T`) and sealed state wrappers (`AsyncState<T>`), leading to messy widget-level `FutureBuilder`/`StreamBuilder` workarounds.
- **The Trap / Suboptimal Local Minimum**: Squeezing async types into a single rigid return type rather than providing clear, symmetric dual tracks for raw domain values vs. loading/error states.
- **The Permanent Reflex**: Enforce the dual-track invariant across all asynchronous sources: `.toBlocSignal(required initialState:)` strictly yields `BlocSignalBase<T>` (raw domain values), while `.toAsyncBlocSignal()` strictly yields `BlocSignalBase<AsyncState<T>>` (sealed async states starting with `AsyncLoading`).

### 🩹 Scar: context.select Zombie Subscriptions on Provider Container Swap
- **The Pathogen / Wound**: Calling `context.select<B, R>()` in widgets or Jaspr components within a subtree that does not otherwise rebuild (such as `const` child subtrees) failed to rebind its signal subscription when an ancestor `BlocSignalProvider` (or `.value()` provider) swapped its container instance. The widget held a zombie subscription listening to the discarded old container.
- **The Antigen / Vulnerability Vector**: Calling `BlocSignalProvider.of<T>(context)` without `listen: true` under the assumption that `context.select` only needs signal effects and shouldn't observe inherited changes, leaving subscriptions attached to stale provider instances when the provider rebuilds with a new instance.
- **The Antibody / Permanent Reflex**: Always use `BlocSignalProvider.of<T>(this, listen: true)` in `context.select`. Because `_BlocSignalProviderInherited.updateShouldNotify` returns `bloc != oldWidget.bloc`, `listen: true` has zero overhead during normal state emissions while guaranteeing that provider container swaps trigger a rebind of the underlying signal effect across all subtrees. Guarded by dedicated widget and component tests in Flutter and Jaspr.

### 🩹 Scar: Riverpod 3 Provider Subtyping & Dart Extension Member Ambiguity
- **The Pathogen / Wound**: Defining separate Dart extension methods on both Riverpod base provider types (for example, `NotifierProvider`) and their autoDispose subtypes (for example, `AutoDisposeNotifierProvider`) causes the Dart analyzer to fail with `ambiguous_extension_member_access` errors when invoking `.toBlocSignal()` on autoDispose provider instances.
- **The Trap / Suboptimal Local Minimum**: Writing duplicate or specialized extensions for both standard and autoDispose provider classes under the assumption that autoDispose variants require distinct extension dispatch.
- **The Permanent Reflex**: Target canonical base provider types (`NotifierProvider`, `AsyncNotifierProvider`, `StateNotifierProvider`, `StateProvider`, `StreamNotifierProvider`) in extensions. Because they extend `ProviderListenable`, Dart extension resolution prioritizes specific provider extensions over generic fallback extensions seamlessly across both standard and autoDispose providers without ambiguity.

### 🩹 Scar: Classic BLoC emit Visibility in Signal Adapters & Stream Error Routing
- **The Pathogen / Wound**: Subclassing `package:bloc`'s `Bloc<Event, State>` to bridge external synchronous signal emissions into a classic `flutter_bloc` stream triggers analyzer warnings because `emit` is marked with `@visibleForTesting` in `package:bloc` (which expects emissions to occur solely inside `on<Event>((event, emit) => ...)` handlers). Additionally, `package:bloc` event handler exceptions route to `Bloc.onError` rather than stream errors, making classic stream error handlers ineffective for catching internal bloc event handler exceptions.
- **The Antigen / Vulnerability Vector**: Attempting to invoke `emit` from external signal effect subscriptions without documented analyzer suppression, or expecting `bloc.stream.listen(onError: ...)` to capture unhandled BLoC event exceptions.
- **The Antibody / Permanent Reflex**: When bridging modern `BlocSignal` containers into classic `Bloc` streams, use `// ignore: invalid_use_of_visible_for_testing_member` accompanied by an explicit explanatory architectural comment (`// package:bloc marks emit with @visibleForTesting in Bloc.`). For error handling, forward stream errors via `BlocSignal.onError` and test stream subscription error recovery with explicit broadcast StreamController fixtures.

### 🩹 Scar: Multi-Major Dependency Lower Bounds & Dual Entrypoint Imports on pub.dev
- **The Pathogen / Wound**: Releasing a package with a wide dependency constraint (for example `riverpod: ">=2.5.0 <4.0.0"`) where required public types shifted export locations across major versions (for example `StateNotifier` and `StateController` in `riverpod.dart` in 2.5 vs `src/internals.dart` in 3.x) caused `dart pub downgrade` static analysis on pub.dev to fail with undefined class errors, losing 20 pub points.
- **The Antigen / Vulnerability Vector**: Either relying solely on modern/latest exports (`src/internals.dart`) which are missing in older supported minor versions, or unnecessarily raising the lower bound to 3.0.0 and breaking downstream consumers still on 2.x.
- **The Antibody / Permanent Reflex**: Bridge multi-major dependency ranges by importing both export entrypoints (`package:riverpod/riverpod.dart` and `package:riverpod/src/internals.dart`) with explicit `hide` clauses for ambiguous symbols, and suppress `unnecessary_import: ignore` in `analysis_options.yaml` to maintain 0 static analysis diagnostics across both `dart pub downgrade` and `dart pub upgrade`. Always test with `dart pub global run pana` to verify 160/160 pub points before releasing.
### 🩹 Scar: AST Visitor Enclosing Closure Traversal in Method Lints
- **The Pathogen / Wound**: Analyzer lint rules targeting prohibited operations inside Flutter `Widget.build()` methods (such as `avoid_emit_in_build`, which flags direct `emit()` or `add()` mutations during widget building) emitted false-positive diagnostics when state mutations were triggered inside UI event callbacks and closures (for example `onPressed: () => bloc.add(Event())` or `onChanged: (val) => cubit.update(val)`). While synchronous execution directly in the `build()` body causes side effects and triggers Flutter build-phase assertion errors, event callbacks inside closures execute asynchronously upon user interaction outside the build lifecycle.
- **The Antigen / Vulnerability Vector**: Inspecting only whether an AST node has an ancestor `MethodDeclaration` named `build` (`node.thisOrAncestorOfType<MethodDeclaration>()`) without checking if the invocation is enclosed within an intervening `FunctionExpression` / callback closure.
- **The Antibody / Permanent Reflex**: When developing AST visitor lint rules targeting lifecycle methods (for example `build()`), always inspect whether the AST node is contained within an enclosing `FunctionExpression` (`final enclosingClosure = node.thisOrAncestorOfType<FunctionExpression>(); if (enclosingClosure != null) return;`). Ignore invocations inside nested closures unless the lint rule explicitly inspects event callbacks. Guard all custom lint rules with comprehensive AST unit test suites covering both direct method invocations and nested event closures.

### 🩹 Scar: Mixin State Initialization & Uninitialized Signal Traps
- **The Pathogen / Wound**: Classes adopting `CubitSignalMixin` or `BlocSignalMixin` (used when extending third-party base classes like `ChangeNotifier`, `TextEditingController`, or `BaseRepository`) that omitted calling `initCubitSignal(initialState: ...)` or `initBlocSignal(initialState: ...)` in their constructors produced `LateInitializationError` or null pointer crashes on first state access at runtime.
- **The Antigen / Vulnerability Vector**: Dart mixins cannot declare generative constructor initializer lists or enforce mandatory super-constructor invocations on host classes, leaving constructor initialization purely to developer convention without compiler-level enforcement.
- **The Antibody / Permanent Reflex**: Enforce constructor initialization via the `require_cubit_signal_mixin_init` custom lint rule with an automated IDE quick-fix (`RequireCubitSignalMixinInitFix`). The analyzer inspects all host class constructors (skipping factory redirects) to ensure `initCubitSignal` or `initBlocSignal` is invoked in the constructor body before state access.

### 🩹 Scar: Declarative Router Guards & Initial Route Gating in Kaisel 1.1
- **The Pathogen / Wound**: In Kaisel 1.1 declarative routing, initializing `KaiselRouterConfig` with a static initial route (such as `initial: const LoginRoute()`) without checking the initial authentication state causes pre-authenticated sessions or restored credentials to flash or boot into the unauthenticated screen because `KaiselRouter` initializes its entry stack directly before `guards` execute. Additionally, naive guard logic that redirects to a destination without allowing proposed stacks that already match that destination produces infinite redirect recursion loops.
- **The Antigen / Vulnerability Vector**: Assuming router guards automatically intercept and evaluate the initial route configuration synchronously at boot, or redirecting unconditionally without checking if the proposed stack already targets the destination route.
- **The Antibody / Permanent Reflex**: In Kaisel router configurations, dynamically compute `initial:` using the container's current state value (for example `loginBloc.stateValue.isLoggedIn ? HomeRoute(...) : const LoginRoute()`). In route guards, always implement an idempotent self-bypass (such as `if (!isLoggedIn && proposed.length == 1 && proposed.first is LoginRoute) return proposed;`) to prevent infinite redirect recursion, and wire reactive state re-evaluation using `bloc.toValueListenable()`.

### 🩹 Scar: Backward-Compatible Named Parameter Constructor Migration via @Deprecated Positional Constructors
- **The Pathogen / Wound**: Migrating public base class constructors (such as `ReplayCubit` and `ReplayBloc`) from positional parameter `super(initialState)` to named parameter `super({required initialState})` causes downstream subclasses extending the container to fail compilation with invalid constructor argument errors on minor version upgrades.
- **The Antigen / Vulnerability Vector**: Updating constructor parameters without providing a backward-compatible positional constructor overload, forcing breaking changes in minor releases.
- **The Antibody / Permanent Reflex**: When migrating generative constructors to named parameters, always preserve backward compatibility by adding an `@Deprecated('Use named parameter initialState: instead')` named constructor (for example `ReplayCubit.positional(State initialState, ...)`). Update `CHANGELOG.md` with explicit subclass migration guidance, test both variants in unit test suites with `// ignore: deprecated_member_use_from_same_package` preceded by explanatory comments for `document_ignores`, and publish under a minor SemVer bump.

### 🩹 Scar: Exhaustive Section Switch Mapping in Website TOC & Source Links (docs_content.dart)
- **The Pathogen / Wound**: Adding or registering new documentation pages in `DocsRegistry` (for example `/docs/decision-matrix`, `/docs/pkg-lint`, `/docs/pkg-jaspr`) without adding corresponding cases in `docs_content.dart`'s `_getHeadingsForSection` and `_getSourcePathForSection` switches silently renders empty Table of Contents sidebars and broken GitHub source links on `blocsignal.dev`.
- **The Antigen / Vulnerability Vector**: Decentralized routing where `DocsRegistry` registers pages, but TOC and source link builders use standalone `switch` statements without compile-time exhaustiveness checking.
- **The Antibody / Permanent Reflex**: Whenever adding or renaming documentation sections in `DocsRegistry`, immediately map their anchor headings in `_getHeadingsForSection` and repository file paths in `_getSourcePathForSection` in `docs_content.dart`. Guard this with automated unit tests in `website/test/docs_registry_test.dart` verifying all registered sections have matching TOC headings and non-empty source file paths.

