import 'dart:async';

import 'package:bloc_signals/src/bloc_signals_base.dart';
import 'package:signals_core/signals_core.dart';

/// Extension methods on [BlocSignalBase] to convert reactive state emissions
/// into a standard Dart multi-subscription [Stream].
extension BlocSignalStreamExtension<StateType> on BlocSignalBase<StateType> {
  /// Converts the reactive state signal into a multi-subscription Dart
  /// [Stream].
  Stream<StateType> toStream() => state.toStream();

  /// Exposes the reactive state signal as a multi-subscription Dart [Stream].
  Stream<StateType> get stream => state.toStream();
}

/// A reactive state container wrapper that adapts an underlying Dart [Stream]
/// (e.g. legacy BLoC, Cubit, or RxDart stream) into a [BlocSignalBase].
class StreamBlocSignal<StateType> extends CubitSignal<StateType> {
  /// Creates a [StreamBlocSignal] wrapping an underlying [stream] with
  /// [initialState].
  StreamBlocSignal(
    Stream<StateType> stream, {
    required super.initialState,
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
  /// with [initialState].
  BlocSignalBase<StateType> toBlocSignal({required StateType initialState}) {
    return StreamBlocSignal<StateType>(this, initialState: initialState);
  }
}
