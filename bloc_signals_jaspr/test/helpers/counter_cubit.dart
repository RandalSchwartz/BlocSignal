import 'package:bloc_signals_jaspr/bloc_signals_jaspr.dart';

class CounterCubit extends CubitSignal<int> {
  CounterCubit({int initial = 0}) : super(initialState: initial);

  void increment() => emit(stateValue + 1);
  void decrement() => emit(stateValue - 1);
}

class ThemeCubit extends CubitSignal<String> {
  ThemeCubit({String initial = 'light'}) : super(initialState: initial);

  void toggle() => emit(stateValue == 'light' ? 'dark' : 'light');
}

sealed class CounterEvent {}

final class CounterIncrement extends CounterEvent {}

class CounterBloc extends BlocSignal<CounterEvent, int> {
  CounterBloc() : super(initialState: 0) {
    on<CounterIncrement>((event, emit) => emit(stateValue + 1));
  }
}
