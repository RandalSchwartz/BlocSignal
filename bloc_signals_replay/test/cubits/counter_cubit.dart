import 'package:bloc_signals_replay/bloc_signals_replay.dart';

class CounterCubit extends ReplayCubit<int> {
  CounterCubit({
    super.limit,
    bool Function(int state)? shouldReplayCallback,
  })  : _shouldReplayCallback = shouldReplayCallback,
        super(initialState: 0);

  final bool Function(int state)? _shouldReplayCallback;

  void increment() => emit(stateValue + 1);
  void decrement() => emit(stateValue - 1);

  @override
  bool shouldReplay(int state) {
    return _shouldReplayCallback?.call(state) ?? super.shouldReplay(state);
  }
}

class CounterCubitMixin extends CubitSignal<int> with ReplayCubitMixin<int> {
  CounterCubitMixin({
    int? limit,
    bool Function(int state)? shouldReplayCallback,
  })  : _shouldReplayCallback = shouldReplayCallback,
        super(initialState: 0) {
    if (limit != null) this.limit = limit;
  }

  final bool Function(int state)? _shouldReplayCallback;

  void increment() => emit(stateValue + 1);
  void decrement() => emit(stateValue - 1);

  @override
  bool shouldReplay(int state) {
    return _shouldReplayCallback?.call(state) ?? super.shouldReplay(state);
  }
}
