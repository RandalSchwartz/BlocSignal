# AI Agent Developer Handbook (`AGENTS.md`)

Welcome, agent! This document defines the core workspace constitution, SDK baselines, code quality standards, and on-demand guidance routing for the `BlocSignal` monorepo. Align all code changes with these guidelines.

---

## 🏗️ Workspace Layout & Monorepo Structure

We use a native Dart workspace (supported in Dart 3.5+) instead of Melos.
- **Root Configuration**: [pubspec.yaml](pubspec.yaml) defines the workspace.
- **Member Packages**:
  - `bloc_signals` (Core pure Dart package)
  - `bloc_signals_flutter` (Flutter bindings & Listenable interop)
  - `bloc_signals_riverpod` (Bidirectional Riverpod interop adapters)
  - `bloc_signals_test` (Declarative unit testing utilities)
  - `bloc_signals_lint` (Static analysis lints & IDE diagnostics)
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
- [devtools.md](plugins/bloc-signals/skills/bloc-signals/devtools.md), [lint.md](plugins/bloc-signals/skills/bloc-signals/lint.md), [otel.md](plugins/bloc-signals/skills/bloc-signals/otel.md): DevTools extensions, custom linter rules, and OpenTelemetry.

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
