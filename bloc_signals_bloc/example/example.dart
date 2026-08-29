import 'package:bloc/bloc.dart' as bloc_lib;
import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_bloc/bloc_signals_bloc.dart';

sealed class CounterEvent {
  const CounterEvent();
}

final class IncrementEvent extends CounterEvent {
  const IncrementEvent();
}

class ClassicCounterBloc extends bloc_lib.Bloc<CounterEvent, int> {
  ClassicCounterBloc() : super(0) {
    on<IncrementEvent>((event, emit) => emit(state + 1));
  }
}

class ModernCounterBloc extends BlocSignal<CounterEvent, int> {
  ModernCounterBloc() : super(initialState: 0) {
    on<IncrementEvent>((event, emit) => emit(stateValue + 1));
  }
}

void main() async {
  // 1. Classic Bloc -> BlocSignal (Bidirectional)
  final classicBloc = ClassicCounterBloc();
  final blocSignal = classicBloc.toBlocSignal();

  print('Classic -> Signal initial: ${blocSignal.stateValue}');
  blocSignal.add(const IncrementEvent());
  await Future<void>.delayed(Duration.zero);
  print('Classic -> Signal updated: ${blocSignal.stateValue}');

  // 2. Modern BlocSignal -> Classic Bloc
  final modernBloc = ModernCounterBloc();
  final classicAdapter = modernBloc.toClassicBloc();

  print('Signal -> Classic initial: ${classicAdapter.state}');
  classicAdapter.add(const IncrementEvent());
  await Future<void>.delayed(Duration.zero);
  print('Signal -> Classic updated: ${classicAdapter.state}');

  await blocSignal.close();
  await classicAdapter.close();
  await classicBloc.close();
  await modernBloc.close();
}
