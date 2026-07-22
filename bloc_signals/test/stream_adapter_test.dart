import 'dart:async';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:test/test.dart';

class _TestCubit extends CubitSignal<int> {
  _TestCubit() : super(initialState: 0);

  void increment() => emit(stateValue + 1);
}

class _TestObserver extends BlocSignalObserver {
  Object? lastError;
  StackTrace? lastStackTrace;

  @override
  void onError(
    BlocSignalBase<dynamic> bloc,
    Object error,
    StackTrace stackTrace,
  ) {
    lastError = error;
    lastStackTrace = stackTrace;
  }
}

void main() {
  group('BlocSignalStreamExtension (.toStream() & .stream)', () {
    test('toStream() emits initial state followed by state updates', () async {
      final cubit = _TestCubit();
      final states = <int>[];

      final subscription = cubit.toStream().listen(states.add);

      cubit
        ..increment()
        ..increment();

      await Future<void>.delayed(Duration.zero);
      expect(states, equals([0, 1, 2]));

      await subscription.cancel();
      await cubit.close();
    });

    test('stream getter exposes state updates as a Stream', () async {
      final cubit = _TestCubit();
      final states = <int>[];

      final subscription = cubit.stream.listen(states.add);

      cubit.increment();

      await Future<void>.delayed(Duration.zero);
      expect(states, equals([0, 1]));

      await subscription.cancel();
      await cubit.close();
    });
  });

  group('StreamBlocSignal & StreamBlocSignalExtension (.toBlocSignal())', () {
    test('StreamBlocSignal listens to stream and updates stateValue', () async {
      final controller = StreamController<int>.broadcast();
      final blocSignal = controller.stream.toBlocSignal(initialState: 0);

      expect(blocSignal.stateValue, equals(0));

      controller.add(10);
      await Future<void>.delayed(Duration.zero);
      expect(blocSignal.stateValue, equals(10));

      controller.add(20);
      await Future<void>.delayed(Duration.zero);
      expect(blocSignal.stateValue, equals(20));

      await blocSignal.close();
      await controller.close();
    });

    test('StreamBlocSignal forwards stream errors to onError observer',
        () async {
      final previousObserver = BlocSignalObserver.observer;
      final observer = _TestObserver();
      BlocSignalObserver.observer = observer;

      try {
        final controller = StreamController<String>.broadcast();
        final blocSignal =
            controller.stream.toBlocSignal(initialState: 'initial');

        final exception = Exception('Stream error');
        controller.addError(exception, StackTrace.current);

        await Future<void>.delayed(Duration.zero);
        expect(observer.lastError, equals(exception));

        await blocSignal.close();
        await controller.close();
      } finally {
        BlocSignalObserver.observer = previousObserver;
      }
    });

    test('StreamBlocSignal auto-closes when underlying stream completes',
        () async {
      final controller = StreamController<int>();
      final blocSignal = StreamBlocSignal(
        controller.stream,
        initialState: 0,
      );

      expect(blocSignal.isClosed, isFalse);

      await controller.close();
      await Future<void>.delayed(Duration.zero);

      expect(blocSignal.isClosed, isTrue);
    });

    test('StreamBlocSignal cancels stream subscription on close()', () async {
      var isCancelled = false;
      final controller = StreamController<int>(
        onCancel: () {
          isCancelled = true;
        },
      );

      final blocSignal = StreamBlocSignal(
        controller.stream,
        initialState: 0,
      );

      expect(isCancelled, isFalse);
      await blocSignal.close();
      expect(isCancelled, isTrue);

      await controller.close();
    });
  });
}
