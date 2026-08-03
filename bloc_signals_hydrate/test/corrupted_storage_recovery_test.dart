import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';
import 'package:test/test.dart';

class CorruptedStorage extends MemoryHydratedStorage {
  @override
  Object? read(String key) {
    if (key.contains('CorruptedCubit')) {
      throw const FormatException('Simulated corrupted storage payload');
    }
    return super.read(key);
  }
}

class CorruptedCubit extends HydratedCubitSignal<int> {
  CorruptedCubit({super.storage}) : super(initialState: 42);

  @override
  void onError(Object error, StackTrace stackTrace) {
    capturedError = error;
    super.onError(error, stackTrace);
  }

  Object? capturedError;
}

void main() {
  group('Corrupted Storage Recovery Tests', () {
    test('HydratedCubitSignal recovers from storage read format exception',
        () async {
      final storage = CorruptedStorage();
      final cubit = CorruptedCubit(storage: storage);

      // Initial state falls back to initial value (42) cleanly
      expect(cubit.stateValue, equals(42));
      expect(cubit.capturedError, isA<FormatException>());

      await cubit.close();
    });
  });
}
