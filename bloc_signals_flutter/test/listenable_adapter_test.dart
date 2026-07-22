import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class TestChangeNotifier extends ChangeNotifier {
  int count = 0;

  bool get isListening => hasListeners;

  void increment() {
    count++;
    notifyListeners();
  }
}

class TestCubit extends CubitSignal<int> {
  TestCubit({super.initialState = 0});

  void increment() => emit(stateValue + 1);
}

class ErrorCapturingListenableBlocSignal<T> extends ListenableBlocSignal<T> {
  ErrorCapturingListenableBlocSignal(
    super.listenable, {
    required super.readState,
    required this.onErrorCallback,
  });

  final void Function(Object error, StackTrace stackTrace) onErrorCallback;

  @override
  void onError(Object error, StackTrace stackTrace) {
    onErrorCallback(error, stackTrace);
    super.onError(error, stackTrace);
  }
}

void main() {
  group('ListenableBlocSignal & ListenableAdapter', () {
    test('adapts ChangeNotifier to BlocSignal using readState', () async {
      final changeNotifier = TestChangeNotifier();
      final blocSignal = changeNotifier.toBlocSignal<int>(
        readState: () => changeNotifier.count,
      );

      expect(blocSignal.stateValue, equals(0));

      changeNotifier.increment();
      expect(blocSignal.stateValue, equals(1));

      await blocSignal.close();
    });

    test('adapts ValueNotifier to BlocSignal via valueNotifier.toBlocSignal()',
        () async {
      final valueNotifier = ValueNotifier<int>(10);
      final blocSignal = valueNotifier.toBlocSignal();

      expect(blocSignal.stateValue, equals(10));

      valueNotifier.value = 20;
      expect(blocSignal.stateValue, equals(20));

      await blocSignal.close();
    });

    test('closing ListenableBlocSignal removes listener from Listenable',
        () async {
      final changeNotifier = TestChangeNotifier();
      final blocSignal = changeNotifier.toBlocSignal<int>(
        readState: () => changeNotifier.count,
      );

      expect(changeNotifier.isListening, isTrue);

      await blocSignal.close();

      expect(changeNotifier.isListening, isFalse);
    });

    test('routes exception thrown by readState to onError', () async {
      Object? capturedError;
      final changeNotifier = TestChangeNotifier();
      var shouldThrow = false;

      final blocSignal = ErrorCapturingListenableBlocSignal<int>(
        changeNotifier,
        readState: () {
          if (shouldThrow) {
            throw const FormatException('readState exception');
          }
          return changeNotifier.count;
        },
        onErrorCallback: (error, stackTrace) {
          capturedError = error;
        },
      );

      shouldThrow = true;
      changeNotifier.increment();

      expect(capturedError, isA<FormatException>());
      await blocSignal.close();
    });

    test('adapts BlocSignal to ValueListenable via toValueListenable()',
        () async {
      final testCubit = TestCubit(initialState: 5);
      final valueListenable = testCubit.toValueListenable();

      expect(valueListenable.value, equals(5));

      var notifiedValue = 0;
      valueListenable.addListener(() {
        notifiedValue = valueListenable.value;
      });

      testCubit.increment();
      expect(valueListenable.value, equals(6));
      expect(notifiedValue, equals(6));

      await testCubit.close();
    });

    test('ValueListenable.dispose unsubscribes from BlocSignal state',
        () async {
      final testCubit = TestCubit(initialState: 100);
      final valueListenable = testCubit.toValueListenable();

      expect(valueListenable.value, equals(100));

      if (valueListenable is ValueNotifier<int>) {
        valueListenable.dispose();
      }

      // Incrementing cubit post-dispose does not throw or crash
      testCubit.increment();
      expect(testCubit.stateValue, equals(101));

      await testCubit.close();
    });

    test('reading state after close does not throw', () async {
      final valueNotifier = ValueNotifier<int>(42);
      final blocSignal = valueNotifier.toBlocSignal();

      await blocSignal.close();

      expect(blocSignal.isClosed, isTrue);
      expect(blocSignal.stateValue, equals(42));
    });
  });
}
