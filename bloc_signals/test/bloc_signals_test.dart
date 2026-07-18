// Cascade invocations are ignored to keep test assertions clean and readable.
// ignore_for_file: cascade_invocations

import 'package:bloc_signals/bloc_signals.dart';
import 'package:test/test.dart';

sealed class CounterEvent {}

class Increment extends CounterEvent {}

class Decrement extends CounterEvent {}

class CounterBloc extends BlocSignal<CounterEvent, int> {
  CounterBloc() : super(initialState: 0);

  @override
  void onEvent(CounterEvent event) {
    switch (event) {
      case Increment():
        emit(stateValue + 1);
      case Decrement():
        emit(stateValue - 1);
    }
  }
}

class ErrorBloc extends BlocSignal<String, int> {
  ErrorBloc() : super(initialState: 0);

  @override
  void onEvent(String event) {
    throw Exception('Test error');
  }
}

class DummyObserver extends BlocSignalObserver {}

class TestObserver extends BlocSignalObserver {
  final List<String> logs = [];

  @override
  void onEvent(BlocSignal<dynamic, dynamic> bloc, Object? event) {
    logs.add('event: $event');
  }

  @override
  void onTransition(
    BlocSignal<dynamic, dynamic> bloc,
    Object? event,
    Object? state,
  ) {
    logs.add('transition: $state');
  }

  @override
  void onError(
    BlocSignal<dynamic, dynamic> bloc,
    Object error,
    StackTrace stackTrace,
  ) {
    logs.add('error: $error');
  }
}

void main() {
  group('BlocSignal Tests', () {
    late TestObserver observer;

    setUp(() {
      observer = TestObserver();
      BlocSignalObserver.observer = observer;
    });

    tearDown(() {
      BlocSignalObserver.observer = null;
    });

    test('initial state is correct', () {
      final bloc = CounterBloc();
      expect(bloc.stateValue, equals(0));
      expect(bloc.state.value, equals(0));
      bloc.close();
    });

    test('handles event and updates state synchronously', () {
      final bloc = CounterBloc();

      bloc.add(Increment());
      expect(bloc.stateValue, equals(1));

      bloc.add(Decrement());
      expect(bloc.stateValue, equals(0));

      bloc.close();
    });

    test('observer logs transitions and events', () {
      final bloc = CounterBloc();

      bloc.add(Increment());

      expect(observer.logs, contains("event: Instance of 'Increment'"));
      expect(observer.logs, contains('transition: 1'));

      bloc.close();
    });

    test('disposal frees resources and cleans up effects', () {
      final bloc = CounterBloc();
      var effectCallCount = 0;

      expect(bloc.isClosed, isFalse);

      // Create an effect that listens to the bloc's state
      bloc.state.subscribe((_) {
        effectCallCount++;
      });

      // Initially subscribed, call count increases
      expect(effectCallCount, equals(1));

      bloc.add(Increment());
      expect(effectCallCount, equals(2));

      bloc.close();
      expect(bloc.isClosed, isTrue);

      bloc.add(Increment());
      // Should drop event, so effectCallCount remains 2
      expect(effectCallCount, equals(2));
    });

    test('handles errors during event processing', () {
      final bloc = ErrorBloc();
      bloc.add('trigger');
      expect(observer.logs, contains('error: Exception: Test error'));
      bloc.close();
    });

    test('covers default empty observer methods', () {
      final dummy = DummyObserver();
      final bloc = CounterBloc();
      dummy.onEvent(bloc, null);
      dummy.onTransition(bloc, null, null);
      dummy.onError(bloc, Exception(), StackTrace.empty);
      bloc.close();
    });
  });
}
