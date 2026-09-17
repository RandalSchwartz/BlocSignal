import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';
import 'package:test/test.dart';

class TestUninitializedCubit extends HydratedCubitSignal<int> {
  TestUninitializedCubit() : super(initialState: 0);

  void increment() => emit(stateValue + 1);

  @override
  void onError(Object error, StackTrace stackTrace) {
    capturedErrors.add(error);
    super.onError(error, stackTrace);
  }

  final List<Object> capturedErrors = [];
}

void main() {
  tearDown(HydratedStorage.reset);

  group('HydratedStorage Uninitialized Diagnostics & Helpers', () {
    test('isInitialized returns false when storage is uninitialized', () {
      expect(HydratedStorage.isInitialized, isFalse);
    });

    test('storage getter returns null when uninitialized without side effects',
        () {
      expect(HydratedStorage.isInitialized, isFalse);

      final storage = HydratedStorage.storage;

      expect(storage, isNull);
      expect(HydratedStorage.isInitialized, isFalse);
    });

    test(
        'instantiating HydratedCubitSignal without storage routes '
        'StateError to onError', () {
      expect(HydratedStorage.isInitialized, isFalse);

      final cubit = TestUninitializedCubit();
      expect(cubit.stateValue, equals(0));
      expect(cubit.capturedErrors, hasLength(1));
      expect(cubit.capturedErrors.first, isA<StateError>());
      expect(
        (cubit.capturedErrors.first as StateError).message,
        contains('HydratedStorage.storage must be initialized'),
      );

      // Incrementing without storage also reports StateError to onError
      cubit.increment();
      expect(cubit.stateValue, equals(1));
      expect(cubit.capturedErrors, hasLength(2));
      expect(cubit.capturedErrors.last, isA<StateError>());
    });

    test('reset() restores storage to uninitialized state', () {
      HydratedStorage.storage = MemoryHydratedStorage();
      expect(HydratedStorage.isInitialized, isTrue);

      HydratedStorage.reset();
      expect(HydratedStorage.isInitialized, isFalse);
    });
  });
}
