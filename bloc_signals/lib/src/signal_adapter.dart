import 'dart:async';

import 'package:bloc_signals/src/bloc_signals_base.dart';
import 'package:signals_core/signals_core.dart';

/// A reactive state container wrapper that adapts an underlying
/// [ReadonlySignal] (for example a [Signal], [Computed], [FutureSignal],
/// [StreamSignal], or [AsyncSignal]) into a [BlocSignalBase].
///
/// Example:
/// ```dart
/// final countSignal = signal(0);
/// final countBloc = SignalBlocSignal(countSignal);
/// ```
class SignalBlocSignal<StateType> extends CubitSignal<StateType> {
  /// Creates a [SignalBlocSignal] wrapping an underlying [signal].
  SignalBlocSignal(
    this.signal, {
    super.equals,
    super.options,
  }) : super(initialState: signal.value) {
    _cleanup = signal.subscribe(emit);
  }

  /// The underlying reactive [ReadonlySignal].
  final ReadonlySignal<StateType> signal;
  late final void Function() _cleanup;

  @override
  Future<void> close() async {
    _cleanup();
    await super.close();
  }
}

/// Extension methods on [ReadonlySignal] to create [BlocSignalBase] containers.
extension ReadonlySignalBlocSignalExtension<StateType>
    on ReadonlySignal<StateType> {
  /// Adapts this [ReadonlySignal] into a [SignalBlocSignal] state container.
  ///
  /// Example:
  /// ```dart
  /// final countSignal = signal(0);
  /// final countBloc = countSignal.toBlocSignal();
  /// ```
  SignalBlocSignal<StateType> toBlocSignal({
    bool Function(StateType previous, StateType current)? equals,
    SignalOptions<StateType>? options,
  }) {
    return SignalBlocSignal<StateType>(
      this,
      equals: equals,
      options: options,
    );
  }
}

/// A reactive state container wrapper that adapts an underlying Dart [Future]
/// into a [BlocSignalBase] holding raw state of type [StateType].
///
/// Example:
/// ```dart
/// final futureBloc = FutureBlocSignal(
///   fetchCount(),
///   initialState: 0,
/// );
/// ```
class FutureBlocSignal<StateType> extends CubitSignal<StateType> {
  /// Creates a [FutureBlocSignal] wrapping an underlying [future] with
  /// [initialState].
  FutureBlocSignal(
    Future<StateType> future, {
    required super.initialState,
    super.equals,
    super.options,
  }) {
    unawaited(
      future.then(
        (value) {
          if (!isClosed) {
            emit(value);
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!isClosed) {
            onError(error, stackTrace);
          }
        },
      ),
    );
  }
}

/// Extension methods on [Future] to create [BlocSignalBase] containers.
extension FutureBlocSignalExtension<T> on Future<T> {
  /// Adapts this Dart [Future] into a [BlocSignalBase<T>] state container
  /// holding raw values of type [T] with a required [initialState].
  ///
  /// The returned container's state starts at [initialState] synchronously,
  /// and emits the resolved value of type [T] upon completion.
  ///
  /// Example:
  /// ```dart
  /// final bloc = fetchCount().toBlocSignal(initialState: 0);
  /// ```
  BlocSignalBase<T> toBlocSignal({
    required T initialState,
    bool Function(T previous, T current)? equals,
    SignalOptions<T>? options,
  }) {
    return FutureBlocSignal<T>(
      this,
      initialState: initialState,
      equals: equals,
      options: options,
    );
  }

  /// Adapts this Dart [Future] into a [SignalBlocSignal<AsyncState<T>>]
  /// container using an underlying [FutureSignal].
  ///
  /// The returned container's state starts as [AsyncLoading] (or
  /// [AsyncData] if [initialValue] is supplied), and transitions to
  /// [AsyncData] or [AsyncError] upon future resolution.
  ///
  /// Example:
  /// ```dart
  /// final userBloc = api.getUser(id).toAsyncBlocSignal();
  /// ```
  SignalBlocSignal<AsyncState<T>> toAsyncBlocSignal({
    Duration? timeout,
    T? initialValue,
    bool lazy = true,
    List<ReadonlySignal<dynamic>> dependencies = const [],
    AsyncSignalOptions<T>? asyncSignalOptions,
    bool Function(AsyncState<T> previous, AsyncState<T> current)? equals,
    SignalOptions<AsyncState<T>>? options,
  }) {
    return toFutureSignal(
      timeout: timeout,
      initialValue: initialValue,
      lazy: lazy,
      dependencies: dependencies,
      options: asyncSignalOptions,
    ).toBlocSignal(
      equals: equals,
      options: options,
    );
  }
}
