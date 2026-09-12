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
  - `bloc_signals_lint` (Static analysis lints & IDE diagnostics - 20 rules & 8 automated quick-fixes)
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
4. **Constructor & State Ergonomics**: Constructors require named parameter `initialState:` (`: super(initialState: ...)`). Use `value` (the preferred modern getter) or `stateValue` (permanent alias for backward compatibility) for raw value access (`emit(value + 1)`); `state` exposes `ReadonlySignal<StateType>` for reactive subscriptions.
5. **Lifecycle & Disposal**: `close()` marks `isClosed = true` and cleans up effects. Subsequent `add()` or `emit()` calls are safely dropped.
6. **Prefer Inline `late final` Computed Properties**: For derived, observable state properties on a `CubitSignal` or `BlocSignal`, prefer declaring and initializing them directly as fields using type inference (for example `late final isCartEmpty = computed(() => stateValue.items.isEmpty);`) rather than two-step manual type declarations and constructor-body assignments (`late final ReadonlySignal<bool> isCartEmpty;` + `isCartEmpty = computed(...)`).
7. **Compose Complex Domain Logic via Targeted Mixins**: To avoid bloating state containers into god-objects, encapsulate complex business rules (for example discounts, taxes, shipping, or calculated projections) into mixins targeted onto the container (`mixin CartPricingMixin on CubitSignal<ShoppingCartState>`). This provides typed access to `stateValue`, leverages cascading `late final computed(...)` signals, decouples domain math from storage/replay, and enables isolated testing on lightweight stub cubits.
8. **Atomic State Transitions & Explicit Helper Emission Naming**: Because state transitions propagate synchronously and immediately in the exact same frame, maintain state atomicity ($S_n \to S_{n+1}$) by consolidating multiple synchronous `emit()` calls along the same linear path into a single emission (enforced by `avoid_multiple_synchronous_emits`). Any private helper method in a state container that invokes `emit()` internally must explicitly declare state emission in its name (for example `_pruneAndEmit()` or `_emitPosition()`) so callers are never caught off guard by hidden state mutations and subscriber reactions (enforced by `require_emit_in_helper_name`).
9. **Frame Budget Defense (Isolate Moat, Batch Shield, Cooperative Time-Slice)**: State updates in `BlocSignal` propagate synchronously within the same frame. For heavy CPU workloads, large dataset transformations, or high-frequency loops, defend the 16.6ms (60 FPS) or 8.3ms (120 FPS) frame budget using three canonical lines of defense: (1) **The Isolate Moat** (`Isolate.run`) for CPU-bound computations off the UI isolate; (2) **The Batch Shield** (`batch(() => ...)`) to collapse multi-signal emissions into a single UI frame; and (3) **The Cooperative Time-Slice** (`Stopwatch` + `await Future.pause()` in Dart 3.13+ or `await Future<void>.delayed(Duration.zero)` in Dart 3.5) when processing large collections on the main isolate. Never use event loop delays as a crutch to wait for state transitions to settle.

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
- [scars.md](plugins/bloc-signals/skills/bloc-signals/scars.md): Full repository scars, crash post-mortems, and defensive invariants.
- [SKILL.md](plugins/bloc-signals/skills/bloc-signals/SKILL.md): Plugin skill entrypoint and router.
- [decision_matrix.md](plugins/bloc-signals/skills/bloc-signals/decision_matrix.md): State modeling decision rubric, container comparison matrix, and heuristics.
- [core.md](plugins/bloc-signals/skills/bloc-signals/core.md): Core event dispatch, equality, `@mustCallSuper`, error handling, and reactive ownership.
- [flutter.md](plugins/bloc-signals/skills/bloc-signals/flutter.md): Providers, listeners, builders, consumers, `context.select<B, R>`, and widget rebuild optimizations.
- [testing.md](plugins/bloc-signals/skills/bloc-signals/testing.md): Declarative unit testing (`blocSignalTest`), observer scoping, and test runners.
- [jaspr.md](plugins/bloc-signals/skills/bloc-signals/jaspr.md): Jaspr web components, reactivity, and HTML bindings.
- [hydration.md](plugins/bloc-signals/skills/bloc-signals/hydration.md): Hydrated state persistence and JSON serialization.
- [replay.md](plugins/bloc-signals/skills/bloc-signals/replay.md): Undo/redo state history and replay architecture.
- [interoperability.md](plugins/bloc-signals/skills/bloc-signals/interoperability.md) & [riverpod_migration.md](plugins/bloc-signals/skills/bloc-signals/riverpod_migration.md): Riverpod, Flutter Listenable, and Stream bridges.
- [devtools.md](plugins/bloc-signals/skills/bloc-signals/devtools.md), [lint.md](plugins/bloc-signals/skills/bloc-signals/lint.md), [otel.md](plugins/bloc-signals/skills/bloc-signals/otel.md): DevTools extensions, custom linter rules (20 rules and 8 automated IDE quick-fixes), and OpenTelemetry.

### Internal Maintainer Operations (`doc/internals/`)
- [website_and_publications.md](doc/internals/website_and_publications.md): `blocsignal.dev` architecture, DEV.to publication sync tools, static compilation, local preview, and Firebase deployment.
- [publishing_and_scoring.md](doc/internals/publishing_and_scoring.md): 160/160 pub.dev points checklist, explicit constructors for dartdoc, package examples, and README catalog tables.
- [benchmarks_and_workflow.md](doc/internals/benchmarks_and_workflow.md): Benchmark microtask draining, batch UI updates, GitHub Actions script safety, and maintainer delivery protocols.
- **Automated Gemini Code Review & Skill Ingestion (`.github/workflows/gemini-code-review.yml`)**: Automated PR code reviews dynamically ingest `AGENTS.md` and unconditionally load all public framework architectural skills from `plugins/bloc-signals/skills/bloc-signals/` (as well as matching `.agents/skills/`), evaluating incoming changes against the full domain corpus on every pull request.

---

## 🩹 Repository Scars & Cliff Tripwires

To protect developer context while preventing catastrophic regressions, full scar diagnostics are decoupled into [`scars.md`](plugins/bloc-signals/skills/bloc-signals/scars.md). **Before writing or modifying code in these domains, read the full 3-part invariant in `scars.md` using `view_file`**:

| Domain / Cliff Edge | Fatal Trap | Invariant & Defensive Reflex |
| :--- | :--- | :--- |
| **Dart 3.13 Syntax** | In-header super calls in doc samples | In `extends`, only type name allowed; use in-body `this : super(...)` or header `super.param`. Guarded by CI tests. |
| **UI State Rebuilds** | `context.watch<T>()` in widget build | In `bloc_signals_flutter`, `context.watch` only checks container swap. Use `context.read<T>()` + `BlocSignalBuilder` or `context.select`. |
| **Workspace Publishing** | `dart pub publish` in mixed workspaces | Always run `flutter pub publish [--dry-run]` in workspaces containing Flutter packages. |
| **Async Type Adapters** | Confusing raw value `T` vs `AsyncState<T>` | `.toBlocSignal()` strictly yields raw `T`; `.toAsyncBlocSignal()` strictly yields `AsyncState<T>`. |
| **`context.select` Subscriptions** | Zombie subscriptions on provider swap | In `context.select`, always call `BlocSignalProvider.of(this, listen: true)` to rebind on instance swap. |
| **Riverpod 3 Subtyping** | Ambiguous extension member access | Target base provider types (`NotifierProvider`, etc.) in extensions; Dart extension resolution handles subtypes cleanly. |
| **Classic BLoC Bridge** | `emit` visibility warnings & error loss | Use `// ignore: invalid_use_of_visible_for_testing_member`; route stream errors via `onError`. |
| **Multi-Major Lower Bounds** | Missing exports across major versions on downgrade | Import both `riverpod.dart` and `src/internals.dart` with `hide` clauses; test with `dart pub downgrade && pana`. |
| **AST Method Lint Visitors** | False positives in nested closures/callbacks | In lifecycle method visitors (for example `build()`), always check and ignore enclosing `FunctionExpression` closures. |
| **Signal Mixin Init** | Missing `initCubitSignal()` in constructors | Enforced by `require_cubit_signal_mixin_init` lint rule with automated IDE quick-fix. |
| **Kaisel 1.1 Guards** | Infinite redirect loops & initial auth flash | Dynamically compute `initial:` route from current state; route guards must have idempotent self-bypass. |
| **Constructor Migration** | Breaking changes on positional `super(...)` | Preserve backward compatibility via `@Deprecated` named positional constructors (`ReplayCubit.positional`). |
| **Website Docs TOC** | Missing switch cases in `docs_content.dart` | Map new sections in `_getHeadingsForSection` and `_getSourcePathForSection`; guarded by CI tests. |
| **Constructor Quick-Fixes** | Assuming first argument is always positional | Query `args.where((arg) => arg is! NamedExpression).firstOrNull`; handle leading named arguments cleanly. |
| **AST NamedType Tokens** | `.name` vs `.name2` across analyzer 6/7/8 | Query `type.toSource()` or `TypeChecker` instead of accessing `.name` / `.name2` directly. |
| **PR Review Skill Ingestion**| Missing domain rules via keyword routing | CI unconditionally ingests all `plugins/bloc-signals/skills/bloc-signals/*.md` files into review prompt. |
| **Lint Regex Wildcards** | `caseSensitive: false` wildcard substring leaks | Explicitly declare casing boundaries (`[a-z]Emit`); test with collision words (`_semitone`, `_demit`). |
| **OTel Concurrency Leaks** | Abandoned spans on dropped/preempted events | Intercept `eventDropped` and `taskPreempted` in `onTelemetry`, tag `'bloc.contention': true`, and end span. |
| **Synchronous Fast-Paths** | Async gaps delaying reentrancy flag reset | Never mark event transformer wrappers `async`; inspect `handler(...) is Future` and execute sync inline. |
| **Mutable Model Deduplication** | In-place mutations dropped by `identical()` | Maintain a monotonic `version` counter and deep map/list equality in state `==` operators. |
| **Stream Preemption Leaks** | Abandoned completer futures hanging in memory | Class-scope `_activeStreamCompleter` and explicitly resolve it on preemption or `close()`. |

For the complete post-mortems, stack traces, and historical case studies for any scar above, inspect [`plugins/bloc-signals/skills/bloc-signals/scars.md`](plugins/bloc-signals/skills/bloc-signals/scars.md).

