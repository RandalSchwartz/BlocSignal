---
name: bloc-signals
description: Implement, review, test, or debug Dart and Flutter code that uses bloc_signals, bloc_signals_flutter, or otel_bloc_signals. Use for BlocSignal event handlers, synchronous state updates, providers, builders, lifecycle ownership, equality behavior, observers, and package-specific test failures. Also use when comparing BlocSignal with package:bloc; read the migration reference before changing an existing BLoC application.
---

# BlocSignal

## Start from installed source

BlocSignal is young and its API may change between releases. Inspect the consumer project's
`pubspec.yaml`, lockfile, imports, and installed package source before editing code. Use this
repository only when the project follows its current branch or the task concerns the repository
itself.

Do not infer API parity from `package:bloc` or `package:flutter_bloc`. BlocSignal uses signals,
has no state stream, and does not implement every BLoC widget or event-transformer API.

## Route the task

- Read [core.md](core.md) for event dispatch, equality, errors, closure, observers, and reactive
  ownership.
- Read [flutter.md](flutter.md) for providers, builders, context extensions, widget ownership, and
  derived UI state.
- Read [testing.md](testing.md) for synchronous assertions, deterministic async tests, zones, and
  widget tests.
- Read [migration.md](migration.md) before replacing `bloc`, `flutter_bloc`, or their widgets.
- Read [otel.md](otel.md) for `OtelBlocSignalObserver`, span completion gaps, and telemetry data
  choices.

Load only the references needed for the task.

## Workflow

1. Identify the exact package versions and target platform.
2. Trace the current event, state, ownership, and disposal path before changing it.
3. Check the installed public API for every type or member you plan to use.
4. Make the smallest coherent change that preserves existing user behavior.
5. Format changed Dart files and run scoped analysis plus the nearest tests.
6. Report the versions inspected, checks run, and any unsupported BLoC behavior that remains.

## Contracts to preserve

- `emit` changes state synchronously and skips a value equal to the current state.
- `add` returns `void`. Synchronous handlers finish before it returns. Async handler futures are
  observed for errors but are not returned to the caller.
- `on<E>` registration is runtime routing. It does not give sealed-class exhaustiveness.
- `close` disposes BlocSignal's internal model. New events are dropped after closure. A post-close
  `emit` asserts in debug mode and returns without updating state in release mode.
- `BlocSignalProvider(create:)` owns and closes its bloc. `BlocSignalProvider.value` does not.
- `context.watch<T>()` tracks provider replacement, not state changes. Use `BlocSignalBuilder` or a
  signals widget to rebuild for state.
- A global `BlocSignalObserver` is a single slot. Installing a telemetry observer can replace an
  existing logger unless the application composes them.

Never create an `effect` or `computed` during a Flutter `build` method. Keep its owner and disposal
path explicit.
