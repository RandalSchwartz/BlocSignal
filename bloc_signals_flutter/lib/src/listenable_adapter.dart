import 'package:bloc_signals/bloc_signals.dart';
import 'package:flutter/foundation.dart';

/// A reactive state container wrapper that adapts an underlying Flutter
/// [Listenable] into a [BlocSignalBase].
class ListenableBlocSignal<T> extends CubitSignal<T> {
  /// Creates a [ListenableBlocSignal] wrapping a Flutter [listenable] with
  /// [readState] evaluation function.
  ListenableBlocSignal(
    this.listenable, {
    required T Function() readState,
  })  : _readState = readState,
        super(initialState: readState()) {
    listenable.addListener(_onListenableChanged);
  }

  /// Creates a [ListenableBlocSignal] wrapping a [ValueListenable].
  factory ListenableBlocSignal.fromValueListenable(
    ValueListenable<T> valueListenable,
  ) {
    return ListenableBlocSignal<T>(
      valueListenable,
      readState: () => valueListenable.value,
    );
  }

  /// The underlying Flutter [Listenable].
  final Listenable listenable;
  final T Function() _readState;

  void _onListenableChanged() {
    if (!isClosed) {
      emit(_readState());
    }
  }

  @override
  Future<void> close() async {
    listenable.removeListener(_onListenableChanged);
    await super.close();
  }
}

/// Extension methods on Flutter [Listenable] for [BlocSignalBase] conversion.
extension ListenableBlocSignalX on Listenable {
  /// Adapts this Flutter [Listenable] into a [BlocSignalBase] container with
  /// initial state evaluated by [readState].
  BlocSignalBase<T> toBlocSignal<T>({required T Function() readState}) {
    return ListenableBlocSignal<T>(this, readState: readState);
  }
}

/// Extension methods on Flutter [ValueListenable] for [BlocSignalBase]
/// conversion.
extension ValueListenableBlocSignalX<T> on ValueListenable<T> {
  /// Adapts this Flutter [ValueListenable] into a [BlocSignalBase] container.
  BlocSignalBase<T> toBlocSignal() {
    return ListenableBlocSignal<T>.fromValueListenable(this);
  }
}

/// Extension methods on [BlocSignalBase] for Flutter [ValueListenable]
/// conversion.
extension BlocSignalValueListenableX<T> on BlocSignalBase<T> {
  /// Exposes this [BlocSignalBase] state container as a Flutter
  /// [ValueListenable].
  ValueListenable<T> toValueListenable() {
    return _BlocSignalValueListenable<T>(this);
  }
}

class _BlocSignalValueListenable<T> extends ValueNotifier<T> {
  _BlocSignalValueListenable(this.bloc) : super(bloc.stateValue) {
    _unsubscribe = bloc.state.subscribe((newValue) {
      value = newValue;
    });
  }

  final BlocSignalBase<T> bloc;
  late final void Function() _unsubscribe;

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }
}
