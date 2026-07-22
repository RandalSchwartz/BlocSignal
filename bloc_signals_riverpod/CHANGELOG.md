# CHANGELOG

## 0.1.0

- Initial release of `bloc_signals_riverpod`.
- Added `ProviderListenable.toBlocSignal(refOrContainer)` extension supporting `Ref`, `WidgetRef`, and `ProviderContainer`.
- Added automatic `ref.onDispose` lifecycle binding to prevent subscription and `autoDispose` retain leaks.
- Added `BlocSignalBase.toProvider()` extension exposing `BlocSignal` and `CubitSignal` instances as Riverpod `NotifierProvider`s.
