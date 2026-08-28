import 'dart:async';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:signals_core/signals_core.dart';
import 'package:test/test.dart';

class _TestObserver extends BlocSignalObserver {
  Object? lastCreated;
  Object? lastClosed;
  Change<dynamic>? lastChange;

  @override
  void onCreate(BlocSignalBase<dynamic> bloc) {
    lastCreated = bloc;
  }

  @override
  void onClose(BlocSignalBase<dynamic> bloc) {
    lastClosed = bloc;
  }

  @override
  void onChange(BlocSignalBase<dynamic> bloc, Change<dynamic> change) {
    lastChange = change;
  }
}

void main() {
  group(
    'SignalBlocSignal & ReadonlySignalBlocSignalExtension (.toBlocSignal())',
    () {
      test('adapts Signal<T> and reflects initial value synchronously', () {
        final countSignal = signal<int>(42);
        final bloc = countSignal.toBlocSignal();

        expect(bloc.stateValue, equals(42));
        expect(bloc.state.value, equals(42));
        expect(bloc.signal, equals(countSignal));
        expect(bloc.isClosed, isFalse);
      });

      test('synchronously updates stateValue when underlying signal changes',
          () {
        final countSignal = signal<int>(0);
        final bloc = countSignal.toBlocSignal();

        expect(bloc.stateValue, equals(0));

        countSignal.value = 1;
        expect(bloc.stateValue, equals(1));
        expect(bloc.state.value, equals(1));

        countSignal.value = 2;
        expect(bloc.stateValue, equals(2));
      });

      test('adapts Computed<T> signal dynamically', () {
        final firstName = signal('Grace');
        final lastName = signal('Hopper');
        final fullName = computed(() => '${firstName.value} ${lastName.value}');

        final bloc = fullName.toBlocSignal();
        expect(bloc.stateValue, equals('Grace Hopper'));

        lastName.value = 'Brewster Murray';
        expect(bloc.stateValue, equals('Grace Brewster Murray'));
      });

      test(r'adapts lifted signal primitive (value.$)', () {
        final value = 100.$;
        final bloc = value.toBlocSignal();

        expect(bloc.stateValue, equals(100));

        value.value = 200;
        expect(bloc.stateValue, equals(200));
      });

      test('adapts StreamSignal to BlocSignalBase<AsyncState<T>>', () async {
        final controller = StreamController<String>();
        final streamSig = controller.stream.toStreamSignal();
        final bloc = streamSig.toBlocSignal();

        expect(bloc.stateValue, isA<AsyncLoading<String>>());

        controller.add('event-1');
        await Future<void>.delayed(Duration.zero);
        expect(bloc.stateValue, isA<AsyncData<String>>());
        expect((bloc.stateValue as AsyncData<String>).value, equals('event-1'));

        await controller.close();
        await bloc.close();
      });

      test('respects custom equals comparator (for example identical)', () {
        var customEqualsCalled = false;
        final sig = signal<List<int>>([1, 2]);

        final bloc = sig.toBlocSignal(
          equals: (prev, curr) {
            customEqualsCalled = true;
            return identical(prev, curr);
          },
        );

        final nextList = [1, 2];
        sig.value = nextList;

        expect(customEqualsCalled, isTrue);
        expect(bloc.stateValue, equals(nextList));
      });

      test('respects custom SignalOptions (name and equalityCheck)', () {
        final sig = signal<int>(10);
        final bloc = sig.toBlocSignal(
          options: const SignalOptions<int>(
            name: 'custom_signal_bloc',
          ),
        );

        expect(bloc.state.name, equals('custom_signal_bloc'));
        expect(bloc.stateValue, equals(10));
      });

      test('close() unsubscribes from signal mutations and updates lifecycle',
          () async {
        final previousObserver = BlocSignalObserver.observer;
        final observer = _TestObserver();
        BlocSignalObserver.observer = observer;

        try {
          final sig = signal<int>(1);
          final bloc = sig.toBlocSignal();

          expect(observer.lastCreated, equals(bloc));

          sig.value = 2;
          expect(bloc.stateValue, equals(2));

          await bloc.close();
          expect(bloc.isClosed, isTrue);
          expect(observer.lastClosed, equals(bloc));

          // Subsequent mutations on the underlying signal should be ignored
          sig.value = 3;
          expect(bloc.stateValue, equals(2));
        } finally {
          BlocSignalObserver.observer = previousObserver;
        }
      });

      test('SignalBlocSignal constructor direct instantiation', () async {
        final sig = signal('direct');
        final bloc = SignalBlocSignal<String>(sig);

        expect(bloc.stateValue, equals('direct'));
        sig.value = 'updated';
        expect(bloc.stateValue, equals('updated'));

        await bloc.close();
      });
    },
  );

  group('FutureBlocSignal & Future.toBlocSignal(required initialState)', () {
    test(
      'initializes with initialState and emits resolved value on completion',
      () async {
        final completer = Completer<String>();
        final bloc = completer.future.toBlocSignal(initialState: 'initial');

        expect(bloc.stateValue, equals('initial'));

        completer.complete('resolved');
        await Future<void>.delayed(Duration.zero);

        expect(bloc.stateValue, equals('resolved'));
        await bloc.close();
      },
    );

    test('routes future error rejection to onError observer callback',
        () async {
      final completer = Completer<int>();
      final bloc = completer.future.toBlocSignal(initialState: 0);

      final exception = Exception('Async failure');
      completer.completeError(exception);
      await Future<void>.delayed(Duration.zero);

      // State value remains initial
      expect(bloc.stateValue, equals(0));

      await bloc.close();
    });

    test('close() before future completes prevents emissions or errors',
        () async {
      final completer = Completer<int>();
      final bloc = completer.future.toBlocSignal(initialState: 10);

      expect(bloc.stateValue, equals(10));
      await bloc.close();
      expect(bloc.isClosed, isTrue);

      completer.complete(99);
      await Future<void>.delayed(Duration.zero);

      expect(bloc.stateValue, equals(10));
    });

    test('close() before future errors prevents onError dispatch', () async {
      final completer = Completer<int>();
      final bloc = completer.future.toBlocSignal(initialState: 10);

      await bloc.close();
      completer.completeError(Exception('Late error'));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.stateValue, equals(10));
    });
  });

  group('FutureBlocSignalExtension (Future.toAsyncBlocSignal())', () {
    test(
      'transitions through AsyncLoading -> AsyncData on successful '
      'resolution',
      () async {
        final completer = Completer<String>();
        final bloc = completer.future.toAsyncBlocSignal();

        // Synchronous initial frame
        expect(bloc.stateValue, isA<AsyncLoading<String>>());
        expect(bloc.state.value.isLoading, isTrue);

        completer.complete('user_data');
        await Future<void>.delayed(Duration.zero);

        expect(bloc.stateValue, isA<AsyncData<String>>());
        expect(
          (bloc.stateValue as AsyncData<String>).value,
          equals('user_data'),
        );
        expect(bloc.state.value.requireValue, equals('user_data'));

        await bloc.close();
      },
    );

    test('transitions to AsyncError on future error rejection', () async {
      final completer = Completer<int>();
      final bloc = completer.future.toAsyncBlocSignal();

      expect(bloc.stateValue, isA<AsyncLoading<int>>());

      final exception = Exception('Network error');
      completer.completeError(exception);
      await Future<void>.delayed(Duration.zero);

      expect(bloc.stateValue, isA<AsyncError<int>>());
      final errorState = bloc.stateValue as AsyncError<int>;
      expect(errorState.error, equals(exception));
      expect(bloc.state.value.hasError, isTrue);

      await bloc.close();
    });

    test('supports initialValue parameter', () async {
      final completer = Completer<int>();
      final bloc = completer.future.toAsyncBlocSignal(initialValue: 99);

      // Initially has the initial value as AsyncData
      expect(bloc.stateValue, isA<AsyncData<int>>());
      expect((bloc.stateValue as AsyncData<int>).value, equals(99));

      completer.complete(100);
      await Future<void>.delayed(Duration.zero);

      expect((bloc.stateValue as AsyncData<int>).value, equals(100));

      await bloc.close();
    });

    test('supports timeout and custom options', () async {
      final completer = Completer<String>();
      final bloc = completer.future.toAsyncBlocSignal(
        timeout: const Duration(milliseconds: 20),
      );

      expect(bloc.stateValue, isA<AsyncLoading<String>>());

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(bloc.stateValue, isA<AsyncError<String>>());
      expect(
        (bloc.stateValue as AsyncError<String>).error,
        isA<TimeoutException>(),
      );

      await bloc.close();
    });

    test('close() before future completes prevents further emissions',
        () async {
      final completer = Completer<int>();
      final bloc = completer.future.toAsyncBlocSignal();

      expect(bloc.stateValue, isA<AsyncLoading<int>>());

      await bloc.close();
      expect(bloc.isClosed, isTrue);

      completer.complete(42);
      await Future<void>.delayed(Duration.zero);

      // State remains AsyncLoading because bloc was closed before resolution
      expect(bloc.stateValue, isA<AsyncLoading<int>>());
    });
  });
}
