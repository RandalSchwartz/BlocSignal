// Cascade invocations are ignored to keep test assertions clean and readable.
// ignore_for_file: cascade_invocations
// ignore_for_file: invalid_use_of_protected_member

import 'dart:async';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:signals_core/signals_core.dart';
import 'package:test/test.dart';

// Simulated third-party base classes to verify single-inheritance bypass
class ExternalService {
  ExternalService(this.serviceName);
  final String serviceName;
}

class CounterServiceController extends ExternalService
    with CubitSignalMixin<int> {
  CounterServiceController() : super('CounterService') {
    initCubitSignal(initialState: 0);
  }

  void increment() => emit(stateValue + 1);
  void decrement() => emit(stateValue - 1);
  void forceSet(int value) => emit(value);
  void triggerError() => onError(Exception('Service error'), StackTrace.empty);
  void testHandleTransition() => handleTransition('test_event', 0, 1);
}

class UninitializedServiceController extends ExternalService
    with CubitSignalMixin<int> {
  UninitializedServiceController() : super('UninitializedService');

  void publicEmit(int val) => emit(val);
}

class CustomEqualityController extends ExternalService
    with CubitSignalMixin<List<String>> {
  CustomEqualityController() : super('ListService') {
    initCubitSignal(
      initialState: const [],
      equals: (a, b) => a.length == b.length,
    );
  }

  void add(String item) => emit([...stateValue, item]);
  void replace(List<String> list) => emit(list);
}

sealed class AuthEvent {}

class LoginRequested extends AuthEvent {
  LoginRequested(this.username);
  final String username;
}

class LogoutRequested extends AuthEvent {}

class AsyncSlowEvent extends AuthEvent {
  AsyncSlowEvent(this.id);
  final int id;
}

class ExceptionEvent extends AuthEvent {}

class ErrorEvent extends AuthEvent {}

sealed class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  AuthAuthenticated(this.username);
  final String username;
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  AuthError(this.message);
  final String message;
}

class AuthBlocService extends ExternalService
    with CubitSignalMixin<AuthState>, BlocSignalMixin<AuthEvent, AuthState> {
  AuthBlocService() : super('AuthService') {
    initCubitSignal(initialState: AuthInitial());

    on<LoginRequested>((event, emit) async {
      emit(AuthLoading());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      emit(AuthAuthenticated(event.username));
    });

    on<LogoutRequested>((event, emit) {
      emit(AuthUnauthenticated());
    });

    on<AsyncSlowEvent>(
      (event, emit) async {
        emit(AuthLoading());
        await Future<void>.delayed(const Duration(milliseconds: 50));
        emit(AuthAuthenticated('slow_${event.id}'));
      },
      transformer: restartable(),
    );

    on<ExceptionEvent>((event, emit) {
      throw Exception('Handler exception');
    });

    on<ErrorEvent>((event, emit) {
      throw StateError('Handler error');
    });
  }
}

class StringBlocService extends ExternalService
    with CubitSignalMixin<int>, BlocSignalMixin<String, int> {
  StringBlocService() : super('StringBlocService') {
    initCubitSignal(initialState: 0);
    on<String>((event, emit) {
      if (event == 'inc') {
        emit(stateValue + 1);
      }
    });
  }
}

class _TestObserver extends BlocSignalObserver {
  final List<String> logs = [];
  final List<BlocSignalBase<dynamic>> created = [];
  final List<BlocSignalBase<dynamic>> closed = [];
  final List<Change<dynamic>> changes = [];
  final List<Transition<dynamic, dynamic>> transitions = [];
  final List<Object?> events = [];
  final List<Object> errors = [];

  @override
  void onCreate(BlocSignalBase<dynamic> bloc) {
    created.add(bloc);
    logs.add('onCreate: ${bloc.runtimeType}');
  }

  @override
  void onEvent(BlocSignalBase<dynamic> bloc, Object? event) {
    events.add(event);
    logs.add('onEvent: $event');
  }

  @override
  void onTransition(
    BlocSignalBase<dynamic> bloc,
    Object? event,
    Object? state,
  ) {
    logs.add('onTransition: $event -> $state');
  }

  @override
  void onChange(BlocSignalBase<dynamic> bloc, Change<dynamic> change) {
    changes.add(change);
    logs.add('onChange: ${change.currentState} -> ${change.nextState}');
  }

  @override
  void onError(
    BlocSignalBase<dynamic> bloc,
    Object error,
    StackTrace stackTrace,
  ) {
    errors.add(error);
    logs.add('onError: $error');
  }

  @override
  void onClose(BlocSignalBase<dynamic> bloc) {
    closed.add(bloc);
    logs.add('onClose: ${bloc.runtimeType}');
  }
}

class _RecordingSignalsObserver extends SignalsObserver {
  final List<String?> createdEffectNames = [];

  @override
  void onComputedCreated<T>(Computed<T> instance) {}

  @override
  void onComputedUpdated<T>(Computed<T> instance, T value) {}

  @override
  void onSignalCreated<T>(Signal<T> instance, T value) {}

  @override
  void onSignalUpdated<T>(Signal<T> instance, T value) {}

  @override
  void onEffectCreated(Effect instance) {
    createdEffectNames.add(instance.name);
  }
}

void main() {
  late _TestObserver observer;

  setUp(() {
    observer = _TestObserver();
    BlocSignalObserver.observer = observer;
  });

  tearDown(() {
    BlocSignalObserver.observer = null;
  });

  group('CubitSignalMixin Tests', () {
    test('composes into existing class hierarchy and tracks state', () async {
      final controller = CounterServiceController();
      expect(controller.serviceName, 'CounterService');
      expect(controller.isInitialized, isTrue);
      expect(controller.value, 0);
      expect(controller.stateValue, 0);
      expect(controller.state.value, 0);
      expect(controller, isA<BlocSignalBase<int>>());
      expect(observer.created, contains(controller));

      controller.increment();
      expect(controller.value, 1);
      expect(controller.stateValue, 1);
      expect(controller.state.value, 1);
      expect(observer.changes.length, 1);
      expect(observer.changes.first.currentState, 0);
      expect(observer.changes.first.nextState, 1);

      controller.decrement();
      expect(controller.value, 0);
      expect(controller.stateValue, 0);

      await controller.close();
      expect(controller.isClosed, isTrue);
      expect(observer.closed, contains(controller));

      // Disposed controller throws AssertionError when assertions are enabled
      expect(controller.increment, throwsA(isA<AssertionError>()));
    });

    test('uninitialized mixin access throws helpful AssertionErrors', () async {
      final uninit = UninitializedServiceController();
      expect(uninit.isInitialized, isFalse);
      expect(() => uninit.state, throwsA(isA<AssertionError>()));
      expect(() => uninit.value, throwsA(isA<AssertionError>()));
      expect(() => uninit.stateValue, throwsA(isA<AssertionError>()));
      expect(() => uninit.publicEmit(1), throwsA(isA<AssertionError>()));
      await uninit.close();
      expect(uninit.isClosed, isTrue);
    });

    test('default handleTransition can be called without error', () async {
      final controller = CounterServiceController();
      controller.testHandleTransition();
      await controller.close();
    });

    test('supports custom equals comparator override and de-duplication',
        () async {
      final controller = CustomEqualityController();
      expect(controller.stateValue, isEmpty);

      controller.add('item1');
      expect(controller.stateValue, ['item1']);
      expect(observer.changes.length, 1);

      // Same length list does not trigger transition due to custom equals
      controller.replace(['item2']);
      expect(observer.changes.length, 1);
      expect(controller.stateValue, ['item1']);

      // Different length triggers transition
      controller.replace(['item1', 'item2']);
      expect(observer.changes.length, 2);
      expect(controller.stateValue, ['item1', 'item2']);

      await controller.close();
    });

    test('createEffect auto-cleans on close', () async {
      final externalSignal = signal<int>(10);
      var effectRuns = 0;

      final controller = CounterServiceController();
      controller.createEffect(() {
        final val = externalSignal.value;
        effectRuns++;
        controller.forceSet(val);
      });

      expect(effectRuns, 1);
      expect(controller.stateValue, 10);

      externalSignal.value = 20;
      expect(effectRuns, 2);
      expect(controller.stateValue, 20);

      await controller.close();

      // After close, effect should be cleaned up and not run
      externalSignal.value = 30;
      expect(effectRuns, 2);
      expect(controller.stateValue, 20);
    });

    group('(Issue #410) CubitSignalMixin createEffect lifecycle', () {
      test(
        '(Issue #410) createEffect after close throws AssertionError in debug '
        'mode and does not invoke callback or subscribe to external signals',
        () async {
          final externalSignal = signal<int>(0);
          var effectRuns = 0;

          final controller = CounterServiceController();
          await controller.close();

          expect(
            () => controller.createEffect(() {
              effectRuns++;
              externalSignal.value;
            }),
            throwsA(isA<AssertionError>()),
          );
          expect(effectRuns, 0);

          externalSignal.value = 1;
          expect(effectRuns, 0);
        },
      );

      test(
        '(Issue #410) manual disposal stops future runs, invokes onDispose '
        'once, is idempotent, and is not re-disposed on close',
        () async {
          final externalSignal = signal<int>(0);
          var runs1 = 0;
          var runs2 = 0;
          var onDispose1Count = 0;
          var onDispose2Count = 0;

          final controller = CounterServiceController();
          final dispose1 = controller.createEffect(
            () {
              runs1++;
              externalSignal.value;
            },
            onDispose: () => onDispose1Count++,
          );
          final dispose2 = controller.createEffect(
            () {
              runs2++;
              externalSignal.value;
            },
            options: EffectOptions(
              onDispose: () => onDispose2Count++,
            ),
          );

          expect(runs1, 1);
          expect(runs2, 1);
          expect(onDispose1Count, 0);
          expect(onDispose2Count, 0);

          dispose1();
          expect(onDispose1Count, 1);

          // Second manual disposal is an idempotent no-op.
          dispose1();
          expect(onDispose1Count, 1);

          externalSignal.value = 1;
          expect(runs1, 1);
          expect(runs2, 2);

          await controller.close();
          expect(onDispose1Count, 1);
          expect(onDispose2Count, 1);

          // Manual disposal after close() is also an idempotent no-op.
          dispose2();
          expect(onDispose2Count, 1);

          externalSignal.value = 2;
          expect(runs1, 1);
          expect(runs2, 2);
        },
      );

      test(
        '(Issue #410) creating and manually disposing effects assigns '
        'distinct monotonic debug names',
        () async {
          final previousObserver = SignalsObserver.instance;
          final signalsObserver = _RecordingSignalsObserver();
          SignalsObserver.instance = signalsObserver;
          addTearDown(() => SignalsObserver.instance = previousObserver);

          final controller = CounterServiceController();
          addTearDown(controller.close);

          final dispose1 = controller.createEffect(() {});
          dispose1();
          final dispose2 = controller.createEffect(() {});
          dispose2();
          controller.createEffect(() {});

          expect(
            signalsObserver.createdEffectNames,
            equals([
              'CounterServiceController.effect#1',
              'CounterServiceController.effect#2',
              'CounterServiceController.effect#3',
            ]),
          );
        },
      );

      test(
        '(Issue #410) close safely drains remaining effects when an '
        'onDispose callback disposes a sibling effect',
        () async {
          final controller = CounterServiceController();
          var onDisposeACount = 0;
          var onDisposeBCount = 0;
          var onDisposeCCount = 0;
          late void Function() disposeB;

          controller.createEffect(
            () {},
            onDispose: () {
              onDisposeACount++;
              disposeB();
            },
          );
          disposeB = controller.createEffect(
            () {},
            onDispose: () => onDisposeBCount++,
          );
          controller.createEffect(
            () {},
            onDispose: () => onDisposeCCount++,
          );

          await expectLater(controller.close(), completes);
          expect(onDisposeACount, 1);
          expect(onDisposeBCount, 1);
          expect(onDisposeCCount, 1);
        },
      );
    });

    test('prevents multiple initCubitSignal calls', () async {
      final controller = CounterServiceController();
      expect(
        () => controller.initCubitSignal(initialState: 99),
        throwsStateError,
      );
      await controller.close();
    });

    test('routes onError to observer and hooks', () async {
      final controller = CounterServiceController();
      controller.triggerError();
      expect(observer.errors.length, 1);
      expect(observer.errors.first, isA<Exception>());
      await controller.close();
    });

    test('toString displays runtimeType and stateValue', () async {
      final controller = CounterServiceController();
      expect(controller.toString(), 'CounterServiceController(0)');
      await controller.close();
    });
  });

  group('BlocSignalMixin Tests', () {
    test('composes into existing class hierarchy and processes events',
        () async {
      final bloc = AuthBlocService();
      expect(bloc.serviceName, 'AuthService');
      expect(bloc.stateValue, isA<AuthInitial>());
      expect(bloc, isA<BlocSignalBase<AuthState>>());

      bloc.add(LoginRequested('alice'));
      expect(observer.events.first, isA<LoginRequested>());

      // Synchronous Loading emission from handler
      expect(bloc.stateValue, isA<AuthLoading>());

      // Wait for async completion
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.stateValue, isA<AuthAuthenticated>());
      final authState = bloc.stateValue as AuthAuthenticated;
      expect(authState.username, 'alice');

      // Sync event
      bloc.add(LogoutRequested());
      expect(bloc.stateValue, isA<AuthUnauthenticated>());

      await bloc.close();
      expect(bloc.isClosed, isTrue);

      // Dropped after close
      bloc.add(LoginRequested('bob'));
      expect(bloc.stateValue, isA<AuthUnauthenticated>());
    });

    test('supports event concurrency transformers', () async {
      final bloc = AuthBlocService();

      // Add two fast events to restartable handler
      bloc.add(AsyncSlowEvent(1));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      bloc.add(AsyncSlowEvent(2));

      await Future<void>.delayed(const Duration(milliseconds: 70));

      // Should have restarted and completed only event 2
      expect(bloc.stateValue, isA<AuthAuthenticated>());
      final authState = bloc.stateValue as AuthAuthenticated;
      expect(authState.username, 'slow_2');

      await bloc.close();
    });

    test('catches exception in event handler and routes to onError', () async {
      final bloc = AuthBlocService();
      bloc.add(ExceptionEvent());
      expect(observer.errors.length, 1);
      expect(observer.errors.first, isA<Exception>());
      await bloc.close();
    });

    test('rethrows Error in event handler and routes to onError', () async {
      final bloc = AuthBlocService();
      expect(() => bloc.add(ErrorEvent()), throwsA(isA<StateError>()));
      expect(observer.errors.length, 1);
      expect(observer.errors.first, isA<StateError>());
      await bloc.close();
    });

    test('throws StateError on registering duplicate event handler', () async {
      final bloc = AuthBlocService();
      expect(
        () => bloc.on<LogoutRequested>((event, emit) {}),
        throwsStateError,
      );
      await bloc.close();
    });

    test('DevToolsService handles dispatch on BlocSignalMixin instances',
        () async {
      final service = DevToolsService.instance;
      final bloc = StringBlocService();
      service.trackCreate(bloc);

      // Dispatch event by name/string
      final response = await service.handleDispatch(
        'ext.bloc_signal.dispatch',
        {
          'hashCode': '${bloc.hashCode}',
          'event': 'inc',
        },
      );
      expect(response.result, isNotNull);
      expect(bloc.stateValue, 1);

      // Dispatch with invalid JSON payload string
      final invalidJsonResp = await service.handleDispatch(
        'ext.bloc_signal.dispatch',
        {
          'hashCode': '${bloc.hashCode}',
          'event': '{invalid json',
        },
      );
      expect(invalidJsonResp.isError(), isTrue);
      expect(invalidJsonResp.errorCode, equals(-32602));

      // Dispatch with missing hashCode
      final missingHashCodeResp = await service.handleDispatch(
        'ext.bloc_signal.dispatch',
        {},
      );
      expect(missingHashCodeResp.isError(), isTrue);

      service.trackClose(bloc);
      await bloc.close();
    });
  });

  group('Change Equality Edge Cases', () {
    test('Change equality handles matching currentState and nextState diff',
        () {
      const change1 = Change<int>(currentState: 0, nextState: 1);
      const change2 = Change<int>(currentState: 0, nextState: 2);
      expect(change1 == change2, isFalse);
    });
  });
}
