import 'dart:async';

import 'package:bloc_signals/src/bloc_signals_base.dart';
import 'package:bloc_signals/src/signal_adapter.dart';
import 'package:signals_core/signals_core.dart';

/// Extension methods on [BlocSignalBase] to convert reactive state emissions
/// into a standard Dart multi-subscription [Stream].
extension BlocSignalStreamExtension<StateType> on BlocSignalBase<StateType> {
  /// Converts the reactive state signal into a multi-subscription Dart
  /// [Stream].
  ///
  /// Example:
  /// ```dart
  /// final Stream<int> stream = counterBloc.toStream();
  /// ```
  Stream<StateType> toStream() => state.toStream();

  /// Exposes the reactive state signal as a multi-subscription Dart [Stream].
  Stream<StateType> get stream => state.toStream();
}

/// A reactive state container wrapper that adapts an underlying Dart [Stream]
/// (for example, legacy BLoC, Cubit, or RxDart stream) into a [BlocSignalBase].
///
/// Example:
/// ```dart
/// final streamBloc = StreamBlocSignal(
///   myStream,
///   initialState: 0,
/// );
/// ```
class StreamBlocSignal<StateType> extends CubitSignal<StateType> {
  /// Creates a [StreamBlocSignal] wrapping an underlying [stream] with
  /// [initialState].
  StreamBlocSignal(
    Stream<StateType> stream, {
    required super.initialState,
    super.equals,
    super.options,
  }) {
    _subscription = stream.listen(
      emit,
      onError: (Object error, StackTrace stackTrace) {
        onError(error, stackTrace);
      },
      onDone: () {
        if (!isClosed) {
          unawaited(close());
        }
      },
    );
  }

  late final StreamSubscription<StateType> _subscription;

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await super.close();
  }
}

/// Extension methods on [Stream] to create [BlocSignalBase] containers.
extension StreamBlocSignalExtension<StateType> on Stream<StateType> {
  /// Adapts this Dart [Stream] into a [BlocSignalBase] state container
  /// holding raw state values with [initialState].
  ///
  /// Example:
  /// ```dart
  /// final bloc = stream.toBlocSignal(initialState: 0);
  /// ```
  BlocSignalBase<StateType> toBlocSignal({
    required StateType initialState,
    bool Function(StateType previous, StateType current)? equals,
    SignalOptions<StateType>? options,
  }) {
    return StreamBlocSignal<StateType>(
      this,
      initialState: initialState,
      equals: equals,
      options: options,
    );
  }

  /// Adapts this Dart [Stream] into a [SignalBlocSignal<AsyncState<StateType>>]
  /// container using an underlying [StreamSignal].
  ///
  /// The returned container's state starts as [AsyncLoading] (or
  /// [AsyncData] if [initialValue] is supplied), and transitions to
  /// [AsyncData] or [AsyncError] as stream events arrive.
  ///
  /// Example:
  /// ```dart
  /// final sensorBloc = sensorStream.toAsyncBlocSignal();
  /// ```
  SignalBlocSignal<AsyncState<StateType>> toAsyncBlocSignal({
    StateType? initialValue,
    bool cancelOnError = false,
    bool lazy = true,
    List<ReadonlySignal<dynamic>> dependencies = const [],
    AsyncSignalOptions<StateType>? asyncSignalOptions,
    bool Function(
      AsyncState<StateType> previous,
      AsyncState<StateType> current,
    )? equals,
    SignalOptions<AsyncState<StateType>>? options,
  }) {
    return toStreamSignal(
      initialValue: initialValue,
      cancelOnError: cancelOnError,
      lazy: lazy,
      dependencies: dependencies,
      options: asyncSignalOptions,
    ).toBlocSignal(
      equals: equals,
      options: options,
    );
  }
}
