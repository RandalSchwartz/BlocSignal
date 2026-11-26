# Changelog

## Unreleased

- **Feat (test)**: Support `Matcher` predicates and collection matchers in `isTelemetry` metadata with detailed `describeMismatch` diagnostics (#483).
- **Feat (test)**: Add `seed` and `expectComputed` parameters to `blocSignalTest` and `runBlocSignalTest` (#483).
- **Fix (test)**: Move `setUp` inside `try/finally` in `runBlocSignalTest` so `tearDown` and `BlocSignalObserver.observer` restoration run even when `setUp` throws (#483).
- **Perf (test)**: Drain microtasks with `Future.microtask` instead of allocating a `Timer` on synchronous `blocSignalTest` runs without `wait` (#483).
- **Dependencies**: Add direct dependency on `signals_core: ^7.0.0` (#483).
- **Feat (test)**: Add opt-in `fakeAsync` virtual-time `wait`, `elapse`, and `flushMicrotasks` support to `blocSignalTest` (#499).
- **Dependencies**: Add direct dependency on `fake_async: ^1.3.0` (#499).

## 1.0.3

- **Docs (test)**: Document idiomatic Fake/Stub classes and `mocktail` backing-signal patterns for widget and golden testing (#313).
- **Docs (test)**: Document intentional `on Object catch` boundary in `blocSignalTest` (#340).

## 1.0.2

- **Fix (test)**: Capture rethrown Error subtypes in blocSignalTest when errors matcher is provided (#328).

## 1.0.1

- **Fix (test)**: Delegate `onEventCompleted` to parent observer in `_TestBlocSignalObserver` (#297).
- **Fix (test)**: Capture ambient observer prior to invoking `setUp` in `blocSignalTest` to prevent observer leaks across tests (#297).
- **Dependencies**: Bump `bloc_signals` constraint to `^1.5.0` for `onEventCompleted` support (#297).

## 1.0.0+1

- Re-trigger pub.dev Pana static analysis.

## 1.0.0

- Official 1.0.0 production release.
- Update `bloc_signals` dependency constraint to `^1.0.0`.

## 0.9.0

- Staging release candidate for the 1.0.0 production milestone.
- Update `bloc_signals` dependency constraint to `^0.9.0`.

## 0.1.4

- Add comprehensive ecosystem package cross-linking table and motto to README.
- Add quick inlined declarative testing code examples (`blocSignalTest`).
- Add `dart_test.yaml` path restriction (`paths: [test/]`) to prevent package entrypoint library (`lib/bloc_signals_test.dart`) filename glob collisions during recursive test execution.
- Update `bloc_signals` dependency to `^0.2.8`.

## 0.1.0

- Initial release of `bloc_signals_test`.
- Provides `blocSignalTest` declarative unit testing utility for `BlocSignal` and `CubitSignal` instances.
