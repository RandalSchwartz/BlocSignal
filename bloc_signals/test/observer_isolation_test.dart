import 'dart:async';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:test/test.dart';

class ThrowingObserver extends BlocSignalObserver {
  ThrowingObserver({
    this.throwOnCreate = false,
    this.throwOnEvent = false,
    this.throwOnTransition = false,
    this.throwOnChange = false,
    this.throwOnError = false,
    this.throwOnTelemetry = false,
    this.throwOnClose = false,
  });

  final bool throwOnCreate;
  final bool throwOnEvent;
  final bool throwOnTransition;
  final bool throwOnChange;
  final bool throwOnError;
  final bool throwOnTelemetry;
  final bool throwOnClose;

  final List<String> calls = [];

  @override
  void onCreate(BlocSignalBase<dynamic> bloc) {
    calls.add('onCreate');
    if (throwOnCreate) throw Exception('onCreate failure');
  }

  @override
  void onEvent(BlocSignalBase<dynamic> bloc, Object? event) {
    calls.add('onEvent');
    if (throwOnEvent) throw Exception('onEvent failure');
  }

  @override
  void onTransition(
    BlocSignalBase<dynamic> bloc,
    Object? event,
    Object? state,
  ) {
    calls.add('onTransition');
    if (throwOnTransition) throw Exception('onTransition failure');
  }

  @override
  void onChange(BlocSignalBase<dynamic> bloc, Change<dynamic> change) {
    calls.add('onChange');
    if (throwOnChange) throw Exception('onChange failure');
  }

  @override
  void onError(
    BlocSignalBase<dynamic> bloc,
    Object error,
    StackTrace stackTrace,
  ) {
    calls.add('onError');
    if (throwOnError) throw Exception('onError failure');
  }

  @override
  void onTelemetry(
    BlocSignalBase<dynamic> bloc,
    String name, {
    Object? event,
    Map<String, dynamic>? metadata,
  }) {
    calls.add('onTelemetry');
    if (throwOnTelemetry) throw Exception('onTelemetry failure');
  }

  @override
  void onClose(BlocSignalBase<dynamic> bloc) {
    calls.add('onClose');
    if (throwOnClose) throw Exception('onClose failure');
  }
}

class TestCubit extends CubitSignal<int> {
  TestCubit() : super(initialState: 0);

  final List<Object> errors = [];

  void increment() => emit(stateValue + 1);

  void triggerTelemetry(String name) => emitTelemetry(name);

  void triggerError(Object error) => emitError(error);

  @override
  void onError(Object error, StackTrace stackTrace) {
    errors.add(error);
    super.onError(error, stackTrace);
  }
}

class ThrowingChangeCubit extends CubitSignal<int> {
  ThrowingChangeCubit() : super(initialState: 0);

  final List<Object> errors = [];

  void increment() => emit(stateValue + 1);

  @override
  void onChange(Change<int> change) {
    super.onChange(change);
    throw Exception('Custom onChange failure');
  }

  @override
  void onError(Object error, StackTrace stackTrace) {
    errors.add(error);
    super.onError(error, stackTrace);
  }
}

class ThrowingHandleTransitionBloc extends BlocSignal<String, int> {
  ThrowingHandleTransitionBloc() : super(initialState: 0) {
    on<String>((event, emit) => emit(stateValue + 1));
  }

  final List<Object> errors = [];

  @override
  void handleTransition(Object event, int oldState, int newState) {
    super.handleTransition(event, oldState, newState);
    throw Exception('Custom handleTransition failure');
  }

  @override
  void onError(Object error, StackTrace stackTrace) {
    errors.add(error);
    super.onError(error, stackTrace);
  }
}

class TestBloc extends BlocSignal<String, int> {
  TestBloc({EventTransformer<String, int>? transformer})
      : super(initialState: 0) {
    on<String>(
      (event, emit) async {
        executed.add(event);
        if (event == 'async_wait') {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        emit(stateValue + 1);
      },
      transformer: transformer,
    );
  }

  final List<String> executed = [];
  final List<Object> errors = [];

  void triggerTelemetry(String name) => emitTelemetry(name);

  void triggerError(Object error) => emitError(error);

  @override
  void onError(Object error, StackTrace stackTrace) {
    errors.add(error);
    super.onError(error, stackTrace);
  }
}

void main() {
  tearDown(() {
    BlocSignalObserver.observer = null;
    DevToolsService.instance.isEnabled = true;
  });

  group('Observer Exception Isolation ([F-5])', () {
    test(
      'throwing onTransition does not abort state update and routes to onError',
      () {
        final observer = ThrowingObserver(throwOnTransition: true);
        BlocSignalObserver.observer = observer;

        final cubit = TestCubit();
        expect(cubit.stateValue, equals(0));

        cubit.increment();

        expect(cubit.stateValue, equals(1));
        expect(cubit.errors.length, equals(1));
        expect(cubit.errors.first.toString(), contains('onTransition failure'));
        unawaited(cubit.close());
      },
    );

    test(
      'throwing onTransition in BlocSignal routes to onError and updates state',
      () {
        final observer = ThrowingObserver(throwOnTransition: true);
        BlocSignalObserver.observer = observer;

        final bloc = TestBloc()..add('test');

        expect(bloc.stateValue, equals(1));
        expect(bloc.errors.length, equals(1));
        expect(bloc.errors.first.toString(), contains('onTransition failure'));
        unawaited(bloc.close());
      },
    );

    test(
      'throwing onCreate routes to onError without crashing constructor',
      () {
        final observer = ThrowingObserver(throwOnCreate: true);
        BlocSignalObserver.observer = observer;

        final cubit = TestCubit();
        expect(cubit.stateValue, equals(0));
        expect(cubit.errors.length, equals(1));
        expect(cubit.errors.first.toString(), contains('onCreate failure'));
        unawaited(cubit.close());
      },
    );

    test(
      'throwing onEvent routes to onError without aborting event processing',
      () async {
        final observer = ThrowingObserver(throwOnEvent: true);
        BlocSignalObserver.observer = observer;

        final bloc = TestBloc()..add('test');
        await Future<void>.delayed(Duration.zero);

        expect(bloc.stateValue, equals(1));
        expect(bloc.errors.length, equals(1));
        expect(bloc.errors.first.toString(), contains('onEvent failure'));
        unawaited(bloc.close());
      },
    );

    test('throwing onChange routes to onError without aborting emit', () {
      final observer = ThrowingObserver(throwOnChange: true);
      BlocSignalObserver.observer = observer;

      final cubit = TestCubit()..increment();

      expect(cubit.stateValue, equals(1));
      expect(cubit.errors.length, equals(1));
      expect(cubit.errors.first.toString(), contains('onChange failure'));
      unawaited(cubit.close());
    });

    test(
      'throwing onClose routes to onError without aborting close cleanup',
      () async {
        final observer = ThrowingObserver(throwOnClose: true);
        BlocSignalObserver.observer = observer;

        final cubit = TestCubit();
        await cubit.close();

        expect(cubit.isClosed, isTrue);
        expect(cubit.errors.length, equals(1));
        expect(cubit.errors.first.toString(), contains('onClose failure'));
      },
    );

    test('throwing onError in observer does not cause recursion or crash', () {
      final observer = ThrowingObserver(
        throwOnTransition: true,
        throwOnError: true,
      );
      BlocSignalObserver.observer = observer;

      final cubit = TestCubit();
      expect(cubit.increment, returnsNormally);
      expect(cubit.stateValue, equals(1));
      unawaited(cubit.close());
    });

    test('custom throwing onChange in subclass routes to onError in emit', () {
      final cubit = ThrowingChangeCubit()..increment();

      expect(cubit.stateValue, equals(1));
      expect(cubit.errors.length, equals(1));
      expect(
        cubit.errors.first.toString(),
        contains('Custom onChange failure'),
      );
      unawaited(cubit.close());
    });

    test('custom throwing handleTransition routes to onError in emit', () {
      final bloc = ThrowingHandleTransitionBloc()..add('test');

      expect(bloc.stateValue, equals(1));
      expect(bloc.errors.length, equals(1));
      expect(
        bloc.errors.first.toString(),
        contains('Custom handleTransition failure'),
      );
      unawaited(bloc.close());
    });
  });

  group('CompositeBlocSignalObserver & Chaining ([F-4])', () {
    test(
      'dispatches all lifecycle events to multiple observers and '
      'isolates errors',
      () async {
        final obs1 = ThrowingObserver(
          throwOnCreate: true,
          throwOnEvent: true,
          throwOnTransition: true,
          throwOnChange: true,
          throwOnError: true,
          throwOnTelemetry: true,
          throwOnClose: true,
        );
        final obs2 = ThrowingObserver();

        final composite = CompositeBlocSignalObserver([obs1, obs2]);
        BlocSignalObserver.observer = composite;

        final bloc = TestBloc();
        expect(obs1.calls, contains('onCreate'));
        expect(obs2.calls, contains('onCreate'));

        bloc.add('test');
        expect(obs1.calls, contains('onEvent'));
        expect(obs2.calls, contains('onEvent'));
        expect(obs1.calls, contains('onTransition'));
        expect(obs2.calls, contains('onTransition'));
        expect(obs1.calls, contains('onChange'));
        expect(obs2.calls, contains('onChange'));

        bloc.triggerTelemetry('custom_metric');
        expect(obs1.calls, contains('onTelemetry'));
        expect(obs2.calls, contains('onTelemetry'));

        bloc.triggerError(Exception('manual error'));
        expect(obs1.calls, contains('onError'));
        expect(obs2.calls, contains('onError'));

        await bloc.close();
        expect(obs1.calls, contains('onClose'));
        expect(obs2.calls, contains('onClose'));

        composite.clear();
        expect(composite.observers, isEmpty);
      },
    );

    test(
      'BlocSignalObserver.addObserver and removeObserver manage composition',
      () {
        final obs1 = ThrowingObserver();
        final obs2 = ThrowingObserver();
        final obs3 = ThrowingObserver();

        expect(BlocSignalObserver.removeObserver(obs1), isFalse);

        BlocSignalObserver.addObserver(obs1);
        expect(BlocSignalObserver.observer, equals(obs1));

        BlocSignalObserver.addObserver(obs2);
        expect(BlocSignalObserver.observer, isA<CompositeBlocSignalObserver>());
        final composite =
            BlocSignalObserver.observer! as CompositeBlocSignalObserver;
        expect(composite.observers, containsAll([obs1, obs2]));

        // Adding a 3rd observer appends to existing composite
        BlocSignalObserver.addObserver(obs3);
        expect(composite.observers, containsAll([obs1, obs2, obs3]));

        // Removing non-existent observer returns false
        final nonExistent = ThrowingObserver();
        expect(BlocSignalObserver.removeObserver(nonExistent), isFalse);

        expect(BlocSignalObserver.removeObserver(obs1), isTrue);
        expect(composite.observers, equals([obs2, obs3]));

        expect(BlocSignalObserver.removeObserver(obs2), isTrue);
        expect(BlocSignalObserver.removeObserver(obs3), isTrue);
        expect(BlocSignalObserver.observer, isNull);
      },
    );
  });

  group('Sequential Event Transformer Close Drain ([F-38])', () {
    test('discards pending queued events when container is closed', () async {
      final bloc = TestBloc(transformer: sequential())
        ..add('async_wait')
        ..add('queued_1')
        ..add('queued_2');

      // Close immediately while async_wait is in-flight
      await bloc.close();

      // Give enough time for delayed futures to finish if they were not aborted
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Only async_wait executed; queued_1 and queued_2 discarded from backlog
      expect(bloc.executed, equals(['async_wait']));
    });
  });

  group('DevToolsService Release Overhead Elimination ([F-10])', () {
    test(
      'does not track history or retain containers when isEnabled is false',
      () {
        DevToolsService.instance.isEnabled = false;
        final cubit = TestCubit();

        DevToolsService.instance
          ..trackCreate(cubit)
          ..trackTransition(cubit, null, 1)
          ..trackError(cubit, 'error', StackTrace.empty);

        expect(
          DevToolsService.instance.getHistoryForTest(identityHashCode(cubit)),
          isNull,
        );
        unawaited(cubit.close());
      },
    );

    test(
        'DevToolsBlocSignalObserver passes telemetry to previousObserver '
        'when disabled', () {
      DevToolsService.instance.isEnabled = false;
      final prev = ThrowingObserver();
      final devTools = DevToolsBlocSignalObserver(previousObserver: prev);
      BlocSignalObserver.observer = devTools;

      final cubit = TestCubit()..triggerTelemetry('disabled_event');

      expect(prev.calls, contains('onTelemetry'));
      unawaited(cubit.close());
    });
  });
}
