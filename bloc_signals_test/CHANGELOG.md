# Changelog

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
