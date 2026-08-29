# Changelog

## 1.0.0

- Initial release of `bloc_signals_bloc`.
- Bidirectional interoperability adapters and extensions:
  - `classicBloc.toBlocSignal()`: Convert any `package:bloc` `Bloc` into a `ClassicBlocSignal` with synchronous reactive signals and `.add(event)` forwarding.
  - `classicCubit.toBlocSignal()`: Convert any `package:bloc` `Cubit` into a `ClassicCubitSignal` with synchronous reactive signals and typed `.cubit` method access.
  - `blocSignal.toClassicBloc()`: Convert any modern `BlocSignal` into a classic `Bloc` for drop-in compatibility with legacy `flutter_bloc` widgets (`BlocBuilder`, `BlocListener`, `BlocConsumer`, `BlocSelector`).
  - `cubitSignal.toClassicCubit()`: Convert any modern `CubitSignal` into a classic `Cubit`.
  - `blocSignalBase.toClassicBloc()` and `blocSignalBase.toClassicCubit()`: Generic base adapters for all `BlocSignalBase` containers.
