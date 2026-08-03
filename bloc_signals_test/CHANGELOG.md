# Changelog

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
