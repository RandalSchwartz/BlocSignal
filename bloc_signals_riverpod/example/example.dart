import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_riverpod/bloc_signals_riverpod.dart';
import 'package:riverpod/riverpod.dart';

class CounterNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void increment() => state++;
}

class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void increment() => emit(stateValue + 1);
}

void main() {
  final container = ProviderContainer();

  // 1. Riverpod Provider -> BlocSignal
  final counterProvider = NotifierProvider<CounterNotifier, int>(
    CounterNotifier.new,
  );
  final blocSignalFromRiverpod = counterProvider.toBlocSignal(container);
  print('Initial BlocSignal state: ${blocSignalFromRiverpod.stateValue}');

  container.read(counterProvider.notifier).increment();
  print('Updated BlocSignal state: ${blocSignalFromRiverpod.stateValue}');

  // 2. BlocSignal -> Riverpod Provider
  final cubit = CounterCubit();
  final cubitProvider = cubit.toProvider();
  print('Initial Riverpod state: ${container.read(cubitProvider)}');

  cubit.increment();
  print('Updated Riverpod state: ${container.read(cubitProvider)}');

  // 3. AsyncValue <-> AsyncState Conversions
  const riverpodAsync = AsyncValue.data(42);
  final signalsState = riverpodAsync.toAsyncState();
  print('Converted to Signals AsyncState: $signalsState');

  final convertedBack = signalsState.toAsyncValue();
  print('Converted back to Riverpod AsyncValue: $convertedBack');

  blocSignalFromRiverpod.close();
  cubit.close();
  container.dispose();
}
