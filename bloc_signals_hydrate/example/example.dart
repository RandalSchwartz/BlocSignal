import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';

/// A sample hydrated cubit storing an integer counter.
class CounterCubit extends HydratedCubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void increment() => emit(stateValue + 1);

  @override
  int? fromJson(dynamic json) => json as int?;

  @override
  dynamic toJson(int state) => state;
}

void main() async {
  // Set up in-memory hydrated storage
  final storage = MemoryHydratedStorage();
  HydratedStorage.storage = storage;

  // Pre-seed storage key
  storage.write('CounterCubit', 42);

  // Instantiating cubit synchronously restores state = 42
  final cubit = CounterCubit();
  print('Restored counter state: ${cubit.stateValue}'); // 42

  // Emitting increments state and updates storage
  cubit.increment();
  print('New counter state: ${cubit.stateValue}'); // 43
  print('Stored value: ${storage.read("CounterCubit")}'); // 43

  // Clear storage and reset state
  await cubit.clear();
  print('Cleared counter state: ${cubit.stateValue}'); // 0

  await cubit.close();
}
