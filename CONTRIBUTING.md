# Contributing to BlocSignal

Thank you for your interest in contributing to **BlocSignal**! We welcome contributions from the community, including bug fixes, feature enhancements, documentation improvements, and sample applications.

This guide outlines our development workflow, workspace setup, code quality standards, and pull request procedures.

---

## 🏛️ Project Philosophy & Architecture

`BlocSignal` bridges two foundational pillars of the Dart and Flutter ecosystems:
1. **BLoC Discipline**: Explicit event-driven state transitions, separation of concerns, and universal observability via `BlocSignalObserver`.
2. **Signals Speed**: Fine-grained reactive dependency graphs, 0ms synchronous state propagation, and zero microtask queue latency.

All contributions should preserve this architectural rigor:
* **Synchronous Propagation**: State updates propagate synchronously in the exact same frame on `emit(newState)`.
* **Automatic De-duplication**: Transitions skip when `newState == currentState` by default.
* **Streamless Execution**: No Rx streams or microtask queues under the hood; event transformers use higher-order functions and async `Mutex` locks.
* **Constructor Ergonomics**: Constructors require named parameter `initialState:` (for example `: super(initialState: ...)`). Raw value access uses `stateValue`, while `state` exposes `ReadonlySignal<StateType>` for reactive subscriptions.

---

## 🏗️ Workspace Setup & Directory Layout

`BlocSignal` is organized as a **native Dart workspace** (Dart 3.5+):
- The root [pubspec.yaml](./pubspec.yaml) manages workspace member packages and tooling.

### Member Packages (`packages/` / root):
* `bloc_signals`: Core pure Dart reactive state primitives bridging BLoC and Signals.
* `bloc_signals_flutter`: Flutter UI bindings, providers, builders, listeners, and selectors.
* `bloc_signals_jaspr`: Jaspr web component bindings and state integrations.
* `bloc_signals_riverpod`: Bidirectional Riverpod 2/3 interop adapters and provider extensions.
* `bloc_signals_hydrate`: Automated synchronous local state persistence and hydration.
* `bloc_signals_replay`: Undo and redo state history tracking for CubitSignal and BlocSignal.
* `bloc_signals_otel`: OpenTelemetry tracing and span generation for state transitions.
* `bloc_signals_devtools`: Universal DevTools telemetry observer using `dart:developer`.
* `bloc_signals_test`: Declarative unit testing utilities (`blocSignalTest`).
* `bloc_signals_lint`: Custom analyzer lint rules and automated IDE quick-fixes.

### Getting Started:
1. Clone the repository:
   ```bash
   git clone https://github.com/RandalSchwartz/BlocSignal.git
   cd BlocSignal
   ```
2. Resolve workspace dependencies from the root:
   ```bash
   dart pub get
   ```

---

## 📏 Engineering Invariants & Quality Standards

To maintain high stability and code quality across all packages, every pull request must satisfy the following strict criteria:

### 1. 100% Test Line Coverage
We maintain **100% line coverage** across all packages in the monorepo.
* Core packages: `dart test --coverage=coverage`
* Flutter packages: `flutter test --coverage`
* Workspace runner: Run the comprehensive test suite across all packages with:
  ```bash
  dart run tool/run_workspace_tests.dart
  ```

### 2. Dual SDK Baseline Policy
* **Published Packages (`bloc_signals*`)**:
  * Must specify and strictly conform to `sdk: ^3.5.0`.
  * Must NOT use Dart language features or APIs introduced after Dart 3.5 (for example primary constructors).
* **Monorepo Workspace, Tooling & Website (`/`, `tool/`, `website/`, `benchmarks/`)**:
  * Requires `sdk: ^3.13.0` for development, website tooling, CI orchestration, and benchmarks.
  * Allows full use of modern Dart 3.13 ergonomics (primary constructors, parameter shorthands, newer core library APIs).

### 3. Strict Linter Rules & Pub Score Compliance (160/160)
* We use `very_good_analysis` with zero allowed warnings or infos.
* **Complete Documentation**: All public member APIs must have complete doc comments (`///`) with runnable code examples.
* **Formatting**: Always format all files before committing:
  ```bash
  dart format .
  ```
* **Phrasing Standard**: Never use the Latin abbreviations `e.g.` or `i.e.` in code or documentation. Always write out **"for example"** and **"that is"**.

---

## 🔄 Pull Request & Git Workflow

1. **Create a Feature Branch**:
   * Name your branch descriptively (for example `issue-123-feature-name` or `fix/issue-456-bug-title`).
   ```bash
   git checkout -b issue-123-feature-name
   ```

2. **Develop with Test-Driven Development (TDD)**:
   * Write a failing unit or widget test reproducing the issue or defining the feature.
   * Implement the minimal, surgical fix or feature code.
   * Verify all tests pass with 100% coverage.

3. **Verify Locally Before Committing**:
   * Run the test suite: `dart run tool/run_workspace_tests.dart`
   * Run the analyzer: `dart analyze --fatal-infos`
   * Format the code: `dart format .`
   * Validate AI plugin manifests: `dart run tool/validate_agent_plugin.dart`

4. **Commit Guidelines**:
   * Use [Conventional Commits](https://www.conventionalcommits.org/) format (for example `feat(flutter): add context.select property selector` or `fix(core): resolve mutex lock re-entrancy edge case`).
   * Keep the commit subject line strictly **72 characters or less**.

5. **Submit a Pull Request**:
   * Open your PR against the `main` branch.
   * Fill out all items in the pull request template checklist.
   * Link the relevant issue number in your PR description (for example `Fixes #123`).

---

## 📜 Code of Conduct

Please note that this project is released with a Contributor Code of Conduct. By participating in this project you agree to abide by its terms as outlined in [CODE_OF_CONDUCT.md](./CODE_OF_CONDUCT.md).

