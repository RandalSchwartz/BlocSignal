import 'dart:async';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:test/test.dart';

// Test events
sealed class TestEvent {}

final class PlainEvent extends TestEvent {
  PlainEvent(this.message);
  final String message;
}

final class AsyncEvent extends TestEvent {
  AsyncEvent(this.delayMs, this.value);
  final int delayMs;
  final int value;
}

final class ErrorEvent extends TestEvent {}

// Test bloc
class ContextualTestBloc extends BlocSignal<TestEvent, String> {
  ContextualTestBloc({
    BlocEventTransformer<PlainEvent, String>? plainTransformer,
    BlocEventTransformer<AsyncEvent, String>? asyncTransformer,
    BlocEventTransformer<ErrorEvent, String>? errorTransformer,
    EventTransformer<PlainEvent, String>? standardPlainTransformer,
  }) : super(initialState: 'initial') {
    on<PlainEvent>(
      (event, emit) => emit(event.message),
      blocTransformer: plainTransformer,
      transformer: standardPlainTransformer,
    );

    if (asyncTransformer != null) {
      on<AsyncEvent>(
        (event, emit) async {
          await Future<void>.delayed(Duration(milliseconds: event.delayMs));
          emit('async:${event.value}');
        },
        blocTransformer: asyncTransformer,
      );
    }

    if (errorTransformer != null) {
      on<ErrorEvent>(
        (event, emit) => throw StateError('Transformer error test'),
        blocTransformer: errorTransformer,
      );
    }
  }

  // Helper exposing withBloc for tests
  EventTransformer<PlainEvent, String> adaptWithBloc(
    BlocEventTransformer<PlainEvent, String> transformer,
  ) {
    return withBloc(transformer);
  }
}

class _TestTelemetryObserver extends BlocSignalObserver {
  final List<String> logs = [];

  @override
  void onTelemetry(
    BlocSignalBase<dynamic> bloc,
    String name, {
    Object? event,
    Map<String, dynamic>? metadata,
  }) {
    logs.add('$name:${metadata?['state_before']}');
  }
}

void main() {
  group('BlocEventTransformer & blocTransformer Tests', () {
    test('passes host bloc instance, event, handler, and emit to transformer',
        () async {
      BlocSignalMixin<dynamic, String>? capturedBloc;
      PlainEvent? capturedEvent;
      final observer = _TestTelemetryObserver();
      BlocSignalObserver.observer = observer;

      final bloc = ContextualTestBloc(
        plainTransformer: (hostBloc, event, handler, emit) {
          capturedBloc = hostBloc;
          capturedEvent = event;
          emitContainerTelemetry(
            hostBloc,
            'transformer_invoked',
            metadata: {'state_before': hostBloc.stateValue},
          );
          emit('transformed:${event.message}');
        },
      );

      expect(bloc.stateValue, equals('initial'));

      bloc.add(PlainEvent('hello'));
      expect(bloc.stateValue, equals('transformed:hello'));
      expect(capturedBloc, same(bloc));
      expect(capturedEvent?.message, equals('hello'));
      expect(observer.logs, equals(['transformer_invoked:initial']));

      await bloc.close();
      BlocSignalObserver.observer = null;
    });

    test('asserts when both transformer and blocTransformer are provided', () {
      expect(
        () => ContextualTestBloc(
          plainTransformer: (b, e, h, em) => h(e, em),
          standardPlainTransformer: (e, h, em) => h(e, em),
        ),
        throwsA(
          isA<AssertionError>().having(
            (e) => e.message,
            'message',
            contains(
              'Cannot provide both transformer and blocTransformer to '
              'on<PlainEvent>',
            ),
          ),
        ),
      );
    });

    test('withBloc adapts BlocEventTransformer to standard EventTransformer',
        () async {
      BlocSignalMixin<dynamic, String>? capturedBloc;

      final bloc = ContextualTestBloc();
      final adapted = bloc.adaptWithBloc((hostBloc, event, handler, emit) {
        capturedBloc = hostBloc;
        return handler(event, emit);
      });

      // Execute adapted transformer
      var emittedState = '';
      final res = adapted(
        PlainEvent('adapted'),
        (e, emit) => emit('handled:${e.message}'),
        (state) => emittedState = state,
      );
      if (res is Future) await res;

      expect(capturedBloc, same(bloc));
      expect(emittedState, equals('handled:adapted'));
      await bloc.close();
    });

    test('.toBlocTransformer() lifts EventTransformer to BlocEventTransformer',
        () async {
      var innerInvoked = false;
      FutureOr<void> standard(
        PlainEvent event,
        EventHandler<PlainEvent, String> handler,
        void Function(String) emit,
      ) {
        innerInvoked = true;
        return handler(event, emit);
      }

      final lifted = standard.toBlocTransformer();

      final bloc = ContextualTestBloc(plainTransformer: lifted)
        ..add(
          PlainEvent('lifted'),
        );

      expect(innerInvoked, isTrue);
      expect(bloc.stateValue, equals('lifted'));
      await bloc.close();
    });

    test('async blocTransformer waits for completion and routes errors',
        () async {
      Object? capturedError;
      final bloc = ContextualTestBloc(
        errorTransformer: (hostBloc, event, handler, emit) async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          await handler(event, emit);
        },
      );

      runZonedGuarded(
        () => bloc.add(ErrorEvent()),
        (error, stack) => capturedError = error,
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(capturedError, isNotNull);
      await bloc.close();
    });

    test('droppable executes synchronous handlers immediately in same frame',
        () async {
      final bloc = ContextualTestBloc(
        plainTransformer: droppable<PlainEvent, String>().toBlocTransformer(),
      )
        ..add(PlainEvent('first'))
        ..add(PlainEvent('second'));

      // In the same frame, both were processed synchronously
      expect(bloc.stateValue, equals('second'));
      await bloc.close();
    });

    test('restartable executes synchronous handlers immediately in same frame',
        () async {
      final bloc = ContextualTestBloc(
        plainTransformer: restartable<PlainEvent, String>().toBlocTransformer(),
      )
        ..add(PlainEvent('first'))
        ..add(PlainEvent('second'));

      expect(bloc.stateValue, equals('second'));
      await bloc.close();
    });

    test('restartable handles synchronous errors and resets inFlight count',
        () async {
      final bloc = ContextualTestBloc(
        errorTransformer: restartable<ErrorEvent, String>().toBlocTransformer(),
      );

      expect(() => bloc.add(ErrorEvent()), throwsStateError);
      await bloc.close();
    });
  });
}
