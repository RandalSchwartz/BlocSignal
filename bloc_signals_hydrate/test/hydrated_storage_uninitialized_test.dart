import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';
import 'package:test/test.dart';

class TestUninitializedCubit extends HydratedCubitSignal<int> {
  TestUninitializedCubit() : super(initialState: 0);

  void increment() => emit(stateValue + 1);
}

void main() {
  tearDown(() {
    HydratedStorage.reset();
  });

  group('HydratedStorage Uninitialized Fallback & Helpers', () {
    test('isInitialized returns false when storage is uninitialized', () {
      expect(HydratedStorage.isInitialized, isFalse);
    });

    test('lazily falls back to MemoryHydratedStorage when accessed while null',
        () {
      expect(HydratedStorage.isInitialized, isFalse);

      final storage = HydratedStorage.storage;

      expect(storage, isA<MemoryHydratedStorage>());
      expect(HydratedStorage.isInitialized, isTrue);
    });

    test('instantiates HydratedCubitSignal without setting storage explicitly',
        () {
      expect(HydratedStorage.isInitialized, isFalse);

      final cubit = TestUninitializedCubit();
      expect(cubit.stateValue, equals(0));

      cubit.increment();
      expect(cubit.stateValue, equals(1));
      expect(
          HydratedStorage.storage!.read('TestUninitializedCubit'), equals(1));
    });

    test('reset() restores storage to uninitialized state', () {
      HydratedStorage.storage = MemoryHydratedStorage();
      expect(HydratedStorage.isInitialized, isTrue);

      HydratedStorage.reset();
      expect(HydratedStorage.isInitialized, isFalse);
    });
  });
}
