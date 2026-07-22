# Changelog

## 0.1.2

- Added example documentation and pubspec package topics to achieve 160/160 pub points on pub.dev.

## 0.1.1

- Added bidirectional conversion extensions between Riverpod's `AsyncValue<T>` and Signals' `AsyncState<T>`:
  - `asyncValue.toAsyncState()`: Converts a Riverpod `AsyncValue` into a Signals `AsyncState`.
  - `asyncState.toAsyncValue()`: Converts a Signals `AsyncState` into a Riverpod `AsyncValue`.

## 0.1.0

- Initial release of `bloc_signals_riverpod`.
- Bidirectional interoperability adapters:
  - `ProviderListenable.toBlocSignal(refOrContainer)`: Convert any Riverpod provider into a `BlocSignalBase` with automatic `ref.onDispose` cleanup.
  - `blocSignal.toProvider()`: Convert any `BlocSignalBase` into a Riverpod `NotifierProvider`.
