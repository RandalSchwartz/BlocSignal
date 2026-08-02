import 'package:bloc_signals_replay/bloc_signals_replay.dart';

sealed class CounterEvent extends ReplayEvent {
  const CounterEvent();
}

final class CounterIncrementPressed extends CounterEvent {
  const CounterIncrementPressed();

  @override
  String toString() => 'CounterIncrementPressed';
}

final class CounterDecrementPressed extends CounterEvent {
  const CounterDecrementPressed();

  @override
  String toString() => 'CounterDecrementPressed';
}

class CounterBloc extends ReplayBloc<CounterEvent, int> {
  CounterBloc({
    super.limit,
    bool Function(int state)? shouldReplayCallback,
  })  : _shouldReplayCallback = shouldReplayCallback,
        super(0) {
    on<CounterIncrementPressed>((event, emit) => emit(stateValue + 1));
    on<CounterDecrementPressed>((event, emit) => emit(stateValue - 1));
  }

  final bool Function(int state)? _shouldReplayCallback;

  @override
  bool shouldReplay(int state) {
    return _shouldReplayCallback?.call(state) ?? super.shouldReplay(state);
  }
}

class CounterBlocMixin extends BlocSignal<CounterEvent, int>
    with ReplayBlocMixin<CounterEvent, int> {
  CounterBlocMixin({
    int? limit,
    bool Function(int state)? shouldReplayCallback,
  })  : _shouldReplayCallback = shouldReplayCallback,
        super(initialState: 0) {
    if (limit != null) this.limit = limit;
    on<CounterIncrementPressed>((event, emit) => emit(stateValue + 1));
    on<CounterDecrementPressed>((event, emit) => emit(stateValue - 1));
  }

  final bool Function(int state)? _shouldReplayCallback;

  @override
  bool shouldReplay(int state) {
    return _shouldReplayCallback?.call(state) ?? super.shouldReplay(state);
  }
}
