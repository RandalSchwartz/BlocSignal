// Cascade invocations are ignored to keep test assertions clean and readable.
// ignore_for_file: cascade_invocations

import 'dart:async';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:signals/signals.dart';
import 'package:test/test.dart';

sealed class CounterEvent {}

class Increment extends CounterEvent {}

class Decrement extends CounterEvent {}

class CounterBloc extends BlocSignal<CounterEvent, int> {
  CounterBloc() : super(initialState: 0);

  @override
  void onEvent(CounterEvent event) {
    unawaited(Future.value(super.onEvent(event)));
    switch (event) {
      case Increment():
        emit(stateValue + 1);
      case Decrement():
        emit(stateValue - 1);
    }
  }
}

class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void increment() => emit(stateValue + 1);
  void decrement() => emit(stateValue - 1);
  void triggerError() => onError(Exception('Cubit error'), StackTrace.empty);
  void publicEmit(int val) => emit(val);
}

class AutoDisposeEffectCubit extends CubitSignal<int> {
  AutoDisposeEffectCubit(this.externalSignal)
      : super(initialState: externalSignal.value) {
    createEffect(() {
      emit(externalSignal.value);
    });
  }

  final Signal<int> externalSignal;
}

class ErrorBloc extends BlocSignal<String, int> {
  ErrorBloc() : super(initialState: 0);

  @override
  void onEvent(String event) {
    unawaited(Future.value(super.onEvent(event)));
    throw Exception('Test error');
  }
}

class ThrowErrorBloc extends BlocSignal<String, int> {
  ThrowErrorBloc() : super(initialState: 0);

  @override
  void onEvent(String event) {
    unawaited(Future.value(super.onEvent(event)));
    throw ArgumentError('Test argument error');
  }
}

class AsyncExceptionBloc extends BlocSignal<String, int> {
  AsyncExceptionBloc() : super(initialState: 0);

  @override
  Future<void> onEvent(String event) async {
    await super.onEvent(event);
    await Future<void>.delayed(Duration.zero);
    throw Exception('Async test error');
  }
}

class AsyncErrorBloc extends BlocSignal<String, int> {
  AsyncErrorBloc() : super(initialState: 0);

  @override
  Future<void> onEvent(String event) async {
    await super.onEvent(event);
    await Future<void>.delayed(Duration.zero);
    throw ArgumentError('Async test argument error');
  }
}

class BlocB extends BlocSignal<String, int> {
  BlocB() : super(initialState: 0);

  @override
  void onEvent(String event) {
    unawaited(Future.value(super.onEvent(event)));
  }
}

class BlocA extends BlocSignal<int, int> {
  BlocA(this.otherBloc) : super(initialState: 0);
  final BlocB otherBloc;

  @override
  void onEvent(int event) {
    unawaited(Future.value(super.onEvent(event)));
    otherBloc.emit(42);
    emit(stateValue + 1);
  }
}

class AsyncEmitBloc extends BlocSignal<String, int> {
  AsyncEmitBloc() : super(initialState: 0);

  @override
  Future<void> onEvent(String event) async {
    await super.onEvent(event);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    emit(100);
  }
}

class NonNullableFutureBloc extends BlocSignal<String, int> {
  NonNullableFutureBloc() : super(initialState: 0);

  @override
  Future<int> onEvent(String event) async {
    await super.onEvent(event);
    await Future<void>.delayed(Duration.zero);
    throw Exception('Non-nullable future async error');
  }
}

class PublicEmitBloc extends BlocSignal<String, int> {
  PublicEmitBloc() : super(initialState: 0);

  @override
  void onEvent(String event) {
    unawaited(Future.value(super.onEvent(event)));
  }

  void publicEmit(int val) => emit(val);
}

class RegistryBloc extends BlocSignal<CounterEvent, int> {
  RegistryBloc() : super(initialState: 0) {
    on<Increment>((event, emit) => emit(stateValue + 1));
    on<Decrement>((event, emit) => emit(stateValue - 1));
  }
}

class AsyncRegistryBloc extends BlocSignal<String, int> {
  AsyncRegistryBloc() : super(initialState: 0) {
    on<String>((event, emit) async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      emit(42);
    });
  }
}

class DuplicateRegistryBloc extends BlocSignal<CounterEvent, int> {
  DuplicateRegistryBloc() : super(initialState: 0) {
    on<Increment>((event, emit) {});
    on<Increment>((event, emit) {});
  }
}

class DummyObserver extends BlocSignalObserver {}

class TestObserver extends BlocSignalObserver {
  final List<String> logs = [];

  @override
  void onEvent(BlocSignalBase<dynamic> bloc, Object? event) {
    logs.add('event: $event');
  }

  @override
  void onTransition(
    BlocSignalBase<dynamic> bloc,
    Object? event,
    Object? state,
  ) {
    logs.add('transition: $state (event: $event)');
  }

  @override
  void onError(
    BlocSignalBase<dynamic> bloc,
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
      expect(
        observer.logs,
        contains("transition: 1 (event: Instance of 'Increment')"),
      );

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

    test('rethrows Error objects (developer faults) synchronously', () {
      final bloc = ThrowErrorBloc();
      expect(() => bloc.add('trigger'), throwsA(isA<ArgumentError>()));
      expect(
        observer.logs,
        contains('error: Invalid argument(s): Test argument error'),
      );
      bloc.close();
    });

    test('handles asynchronous Exception without crashing', () async {
      final bloc = AsyncExceptionBloc();
      bloc.add('trigger');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(observer.logs, contains('error: Exception: Async test error'));
      bloc.close();
    });

    test('throws asynchronous Error to the current zone', () async {
      final bloc = AsyncErrorBloc();
      Object? caughtError;
      runZonedGuarded(
        () => bloc.add('trigger'),
        (e, s) => caughtError = e,
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(caughtError, isA<ArgumentError>());
      expect(
        observer.logs,
        contains('error: Invalid argument(s): Async test argument error'),
      );
      bloc.close();
    });

    test('allows cross-bloc emit without zone key casting crashes', () {
      final blocB = BlocB();
      final blocA = BlocA(blocB);

      // This should not crash!
      blocA.add(1);

      expect(blocB.stateValue, equals(42));
      expect(blocA.stateValue, equals(1));

      // BlocB's transition should have null event
      // (since it wasn't triggered by its own add)
      expect(observer.logs, contains('transition: 42 (event: null)'));
      // BlocA's transition should have 1 as event
      expect(observer.logs, contains('transition: 1 (event: 1)'));

      blocA.close();
      blocB.close();
    });

    test(
      'preserves the event in onTransition even after async await',
      () async {
        final bloc = AsyncEmitBloc();

        bloc.add('delayed_event');
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(bloc.stateValue, equals(100));
        expect(
          observer.logs,
          contains('transition: 100 (event: delayed_event)'),
        );

        bloc.close();
      },
    );
    test('handles async exceptions when Future is non-nullable', () async {
      final bloc = NonNullableFutureBloc();
      bloc.add('trigger');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(
        observer.logs,
        contains('error: Exception: Non-nullable future async error'),
      );
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

    test('throws AssertionError when emit is called after close', () {
      final bloc = PublicEmitBloc();
      bloc.close();
      expect(() => bloc.publicEmit(42), throwsA(isA<AssertionError>()));
    });

    test('supports on<E> registration and handles events synchronously', () {
      final bloc = RegistryBloc();
      expect(bloc.stateValue, equals(0));

      bloc.add(Increment());
      expect(bloc.stateValue, equals(1));

      bloc.add(Decrement());
      expect(bloc.stateValue, equals(0));

      bloc.close();
    });

    test('supports on<E> with async handlers', () async {
      final bloc = AsyncRegistryBloc();
      expect(bloc.stateValue, equals(0));

      bloc.add('trigger');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.stateValue, equals(42));

      bloc.close();
    });

    test('on<E> preserves zone transition event tracking', () {
      final bloc = RegistryBloc();
      bloc.add(Increment());

      expect(
        observer.logs,
        contains("transition: 1 (event: Instance of 'Increment')"),
      );

      bloc.close();
    });

    test('throws StateError when on<E> is registered multiple times', () {
      expect(
        DuplicateRegistryBloc.new,
        throwsA(isA<StateError>()),
      );
    });

    group('CubitSignal Tests', () {
      test('initial state is correct', () {
        final cubit = CounterCubit();
        expect(cubit.stateValue, equals(0));
        expect(cubit.state.value, equals(0));
        cubit.close();
      });

      test('updates state synchronously when methods are called', () {
        final cubit = CounterCubit();
        cubit.increment();
        expect(cubit.stateValue, equals(1));
        cubit.decrement();
        expect(cubit.stateValue, equals(0));
        cubit.close();
      });

      test('observer logs transitions with null event', () {
        final cubit = CounterCubit();
        cubit.increment();
        expect(
          observer.logs,
          contains('transition: 1 (event: null)'),
        );
        cubit.close();
      });

      test('onError routes errors to the observer', () {
        final cubit = CounterCubit();
        cubit.triggerError();
        expect(
          observer.logs,
          contains('error: Exception: Cubit error'),
        );
        cubit.close();
      });

      test('throws AssertionError when emit is called after close', () {
        final cubit = CounterCubit();
        cubit.close();
        expect(() => cubit.publicEmit(42), throwsA(isA<AssertionError>()));
      });

      test('createEffect auto-disposes subclass constructor effects on close',
          () {
        final externalSignal = signal<int>(0);
        final cubit = AutoDisposeEffectCubit(externalSignal);

        expect(cubit.stateValue, equals(0));

        externalSignal.value = 1;
        expect(cubit.stateValue, equals(1));

        cubit.close();

        // Modifying the external signal after close should not throw assertions
        // because the effect should have been automatically disposed.
        externalSignal.value = 2;
        expect(cubit.stateValue, equals(1)); // State remains 1
      });
    });
  });
}
