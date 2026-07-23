---
name: bloc-signals
description: Implement, review, test, or debug Dart and Flutter code that uses bloc_signals, bloc_signals_flutter, or otel_bloc_signals. Use for BlocSignalBase, BlocSignal, CubitSignal, Change, Transition, event handlers, createEffect ownership, synchronous state updates, lazy providers, builders, listeners, consumers, selectors, context.select, lifecycle observers, and package-specific test failures. Also use when comparing BlocSignal with package:bloc or Riverpod; read the matching migration reference before changing an existing application.
---

# BlocSignal

## Start from installed source

BlocSignal is young and its API may change between releases. Inspect the consumer project's
`pubspec.yaml`, lockfile, imports, and installed package source before editing code. Use this
repository only when the project follows its current branch or the task concerns the repository
itself.

Do not infer API parity from `package:bloc`, `package:flutter_bloc`, or Riverpod. BlocSignal uses
signals, has no state stream or provider dependency graph, and does not implement every source
package lifecycle, predicate, or widget API.

## Related Signals skills

This plugin is self-contained for BlocSignal work. When the agent already has skills from
`rodydavis/signals.dart`, use these optional companions for lower-level Signals tasks:

- `signals-dart` for `signals_core` primitives and utilities.
- `signals-flutter` for Flutter bindings and signal-aware widgets.
- `signals-hooks` for `flutter_hooks` integration.
- `signals-lint` for analyzer rules and quick fixes.
- `signals-migration-6-to-7` for Signals 6 to 7 migrations.

Do not assume these skills are installed. If they are unavailable, inspect the consumer project's
installed Signals source before changing code.

## Route the task

- Read [core.md](core.md) for event dispatch, equality, errors, closure, observers, and reactive
  ownership.
- Read [flutter.md](flutter.md) for providers, builders, listeners, multi-listeners, consumers,
  selectors, context extensions, widget ownership, and derived UI state.
- Read [testing.md](testing.md) for synchronous assertions, deterministic async tests, zones, and
  widget tests.
- Read [migration.md](migration.md) before replacing `bloc`, `flutter_bloc`, or their widgets.
- Read [migration_bridge.md](migration_bridge.md) for Stream and Listenable interop bridges.
- Read [riverpod_migration.md](riverpod_migration.md) before replacing Riverpod providers,
  consumers, families, scopes, or generated declarations.
- Read [interoperability.md](interoperability.md) for the universal state bridge across BLoC, Riverpod, and Provider ecosystems.
- Read [lint.md](lint.md) for analyzer rules and IDE diagnostics (`bloc_signals_lint`).
- Read [otel.md](otel.md) for `OtelBlocSignalObserver`, span completion gaps, and telemetry data
  choices.

Load only the references needed for the task.

## Workflow

1. Identify the exact package versions and target platform.
2. Trace the current event, state, ownership, and disposal path before changing it.
3. Check the installed public API for every type or member you plan to use.
4. Make the smallest coherent change that preserves existing user behavior.
5. Format changed Dart files and run scoped analysis plus the nearest tests.
6. Report the versions inspected, checks run, and any unsupported source behavior that remains.

## Contracts to preserve

- `BlocSignalBase<State>` owns state and lifecycle. Use `CubitSignal<State>` for public methods and
  `BlocSignal<Event, State>` for event dispatch.
- `emit` changes state synchronously and skips a value equal to the current state.
- `BlocSignal.add` returns `void`. Synchronous handlers finish before it returns. Async handler
  futures are observed for errors but are not returned or cancelled by `close`.
- `on<E>` registration is runtime routing. Duplicate exact types throw `StateError`; registration
  does not give sealed-class exhaustiveness. An `onEvent` override must call `super.onEvent`.
- `close` returns `Future<void>`, disposes effects registered through `createEffect`, and disposes
  the internal model. New events are dropped after closure. A post-close `emit` asserts in debug
  mode and returns without updating state in release mode.
- A non-equal event transition runs before state mutation. `onChange` runs after mutation. Both
  local hooks require `super`; equal emits run neither hook.
- `BlocSignalProvider(create:)` is lazy by default, owns its bloc, and closes it. Use `lazy: false`
  for eager creation. `BlocSignalProvider.value` does not own its bloc.
- `context.watch<T>()` tracks provider replacement, not state changes. Use `BlocSignalBuilder` or a
  signals widget to rebuild for state.
- `BlocSignalListener` suppresses its initial effect run and supports `listenWhen(previous,
  current)`. It passes only the current state to the listener callback.
- A global `BlocSignalObserver` is a single slot. Installing a telemetry observer can replace an
  existing logger unless the application composes them.

Never create an `effect` or `computed` during a Flutter `build` method. Keep its owner and disposal
path explicit.
