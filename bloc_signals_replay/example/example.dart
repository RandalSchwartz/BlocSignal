import 'package:bloc_signals_replay/bloc_signals_replay.dart';

/// An example CounterCubit with undo and redo state history tracking.
class CounterCubit extends ReplayCubit<int> {
  CounterCubit() : super(0);

  void increment() => emit(stateValue + 1);
  void decrement() => emit(stateValue - 1);
}

void main() {
  final cubit = CounterCubit();

  print('Initial state: ${cubit.stateValue}'); // 0

  cubit.increment();
  print('After increment: ${cubit.stateValue}'); // 1

  cubit.increment();
  print('After second increment: ${cubit.stateValue}'); // 2

  if (cubit.canUndo) {
    cubit.undo();
    print('After undo: ${cubit.stateValue}'); // 1
  }

  if (cubit.canRedo) {
    cubit.redo();
    print('After redo: ${cubit.stateValue}'); // 2
  }

  cubit.close();
}
