# Changelog

## 1.0.0+1

- Maintenance patch release for pub.dev package score re-analysis.

## 1.0.0


- Official 1.0.0 production release.
- Update `bloc_signals` dependency constraint to `^1.0.0`.

## 0.9.0

- Staging release candidate for the 1.0.0 production milestone.
- Update `bloc_signals` dependency constraint to `^0.9.0`.

## 0.1.5

- Fix Riverpod 3.3+ export compatibility by importing `package:riverpod/src/internals.dart`.
- Add optional `equals:` parameter to `RiverpodBlocSignal` constructors and `ProviderListenable.toBlocSignal()` extension.
- Add comprehensive ecosystem package cross-linking table and motto to README.
- Add quick inlined Riverpod 2/3 interop code examples.
- Update `bloc_signals` dependency to `^0.2.8`.

## 0.1.2

- Added example documentation and pubspec package topics to achieve 160/160 pub points on pub.dev.

## 0.1.1

- Added bidirectional conversion extensions between Riverpod's `AsyncValue<T>` and Signals' `AsyncState<T>`:
  - `asyncValue.toAsyncState()`: Converts a Riverpod `AsyncValue` into a Signals `AsyncState`.
  - `asyncState.toAsyncValue()`: Converts a Signals `AsyncState` into a Riverpod `AsyncValue`.

## 0.1.4

- Add comprehensive ecosystem package cross-linking table and motto to README.
- Add quick inlined Riverpod 2/3 interop code examples.
- Update `bloc_signals` dependency to `^0.2.6`.

## 0.1.0

- Initial release of `bloc_signals_riverpod`.
- Bidirectional interoperability adapters:
  - `ProviderListenable.toBlocSignal(refOrContainer)`: Convert any Riverpod provider into a `BlocSignalBase` with automatic `ref.onDispose` cleanup.
  - `blocSignal.toProvider()`: Convert any `BlocSignalBase` into a Riverpod `NotifierProvider`.
