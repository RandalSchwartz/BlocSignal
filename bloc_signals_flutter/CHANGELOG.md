## 0.2.6

- Add comprehensive ecosystem package cross-linking table and motto to README.
- Add quick inlined Flutter UI widget code examples (`BlocSignalBuilder`, `BlocSignalListener`, `BlocSignalConsumer`, `BlocSignalSelector`).
- Update `bloc_signals` dependency to `^0.2.6`.

## 0.2.4

- Add optional `equals:` parameter to `ListenableBlocSignal` constructors and `.toBlocSignal()` extensions (`Listenable.toBlocSignal()` & `ValueListenable.toBlocSignal()`).

## 0.2.3

- Route exceptions thrown by `readState()` inside `ListenableBlocSignal._onListenableChanged()` directly to `onError(error, stackTrace)` and observers.

## 0.2.2

- Added bidirectional Flutter `Listenable` & `ValueListenable` interop adapters:
  - `listenable.toBlocSignal(readState: ...)` & `valueListenable.toBlocSignal()`: Convert any Flutter `Listenable`, `ChangeNotifier`, or `ValueNotifier` into a `BlocSignalBase`.
  - `blocSignal.toValueListenable()`: Expose any `BlocSignalBase` as a Flutter `ValueListenable<T>` for classic `package:provider` (`ChangeNotifierProvider`) or `ValueListenableBuilder`.

## 0.2.1

- Refactor example app BLoCs (`LoginBloc` and `TimerBloc`) to use constructor-scoped `on<E>` event handler syntax.
- Add unit tests for example BLoCs and update example documentation.

## 0.2.0

- Complete Flutter Bloc API Parity alignments:
  - Update `BlocSignalProvider` to default to `lazy: true`.
  - Convert `BlocSignalListener` to `StatefulWidget` to align listener execution lifecycle.
  - Add `listenWhen` filter parameter to `BlocSignalListener` and `BlocSignalConsumer`.
  - Implement `MultiBlocSignalListener` to compose multiple listeners cleanly.
  - Implement `BuildContext.select` extension to efficiently watch state slices via element-cached computed signals.

## 0.1.9

- Add `BlocSignalListener`, `BlocSignalConsumer`, and `BlocSignalSelector` widgets to achieve 100% widget-level API parity with classic `flutter_bloc`.
- Fix inherited dependency lookup bug in `BlocSignalBuilder`, `BlocSignalListener`, `BlocSignalConsumer`, and `BlocSignalSelector` to ensure proper rebuilds and reactiveness when ancestor provided bloc instances change.

## 0.1.8

- Update `bloc_signals` dependency constraint to `^0.1.12`.

## 0.1.7

- Widen providers, builders, and lookup extensions to accept `BlocSignalBase` to support both Blocs and Cubits.
- Optimize provider lookup performance in `BlocSignalProvider.of` to run in O(1) time.

## 0.1.6

- Remove pre-release Dart SDK constraints in favor of stable `^3.10.0`.
- Update documentation and link package READMEs to the primary consumable AI coding assistant skill.
- Clarify stateful widget effect disposal guidelines and provide Flutter Hooks integration examples.

## 0.1.5

- Widen Dart SDK constraint to include pre-release versions of Dart `3.10.0`.


## 0.1.4

- Relax Dart SDK constraints to `^3.10.0`.

## 0.1.3

- Fix relative Migration Guide link in README for pub.dev.

## 0.1.2

- Acknowledge Felix Angelov & Rody Davis in documentation.
- Add comprehensive Timer showcase example.

## 0.1.1

- Add Cubit migration guide to documentation.

## 0.1.0

- Initial release of `bloc_signals_flutter` bindings.
- Added `BlocSignalProvider`, `MultiBlocSignalProvider`, and `BlocSignalBuilder` widgets.
