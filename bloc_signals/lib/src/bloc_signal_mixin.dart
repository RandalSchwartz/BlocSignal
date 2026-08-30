import 'dart:async';

import 'package:bloc_signals/src/bloc_signals_base.dart';
import 'package:bloc_signals/src/concurrency/event_transformers.dart';
import 'package:meta/meta.dart';

/// A mixin providing event-driven state container capabilities for any
/// [BlocSignalBase] class.
///
/// Mixing [BlocSignalMixin] enables event registration via [on], event
/// dispatch via [add], custom concurrency transformations via
/// [EventTransformer], and transition tracking via [onTransition].
///
/// ```dart
/// class AuthenticationBlocService extends BaseService
///     with
///         CubitSignalMixin<AuthState>,
///         BlocSignalMixin<AuthEvent, AuthState> {
///   AuthenticationBlocService() {
///     initCubitSignal(initialState: AuthInitial());
///
///     on<LoginRequested>((event, emit) async {
///       emit(AuthLoading());
///       final user = await authApi.login(event.username, event.password);
///       emit(AuthAuthenticated(user));
///     });
///
///     on<LogoutRequested>((event, emit) {
///       emit(AuthUnauthenticated());
///     });
///   }
/// }
/// ```
mixin BlocSignalMixin<Event, StateType> on BlocSignalBase<StateType> {
  final List<_HandlerRegistry<Event, StateType>> _handlers = [];

  /// Called when a transition occurs.
  ///
  /// Forwards the transition details to [BlocSignalObserver.onTransition]
  /// if a global observer is registered.
  @protected
  @mustCallSuper
  void onTransition(Transition<Event, StateType> transition) {
    BlocSignalObserver.observer
        ?.onTransition(this, transition.event, transition.nextState);
  }

  @override
  @protected
  void handleTransition(Object event, StateType oldState, StateType newState) {
    onTransition(
      Transition<Event, StateType>(
        currentState: oldState,
        event: event as Event,
        nextState: newState,
      ),
    );
  }

  /// Dispatches an event to the [onEvent] handler.
  ///
  /// Notifies the global [BlocSignalObserver] of the incoming event and catches
  /// errors thrown in [onEvent], delegating them to [onError].
  void add(Event event) {
    if (isClosed) return;
    final currentObserver = BlocSignalObserver.observer;
    if (currentObserver != null) {
      currentObserver.onEvent(this, event);
    }

    runZoned(
      () {
        try {
          final result = onEvent(event);
          if (result is Future) {
            unawaited(_handleAsyncResult(result));
          }
        } catch (e, stackTrace) {
          onError(e, stackTrace);
          if (e is Error) rethrow;
        }
      },
      zoneValues: {zoneEventKey: event},
    );
  }

  Future<void> _handleAsyncResult(Future<dynamic> result) async {
    try {
      await result;
    } catch (e, stackTrace) {
      onError(e, stackTrace);
      if (e is Error) {
        Error.throwWithStackTrace(e, stackTrace);
      }
    }
  }

  /// Registers an event handler for events of type [E].
  ///
  /// By default, handlers are invoked immediately when an event of type [E]
  /// is added. If [transformer] is provided, it intercepts each incoming event
  /// to control concurrency (such as dropping, queuing, or debouncing).
  ///
  /// ```dart
  /// class CounterBloc extends BlocSignal<CounterEvent, int> {
  ///   CounterBloc() : super(initialState: 0) {
  ///     // Basic handler:
  ///     on<Increment>((event, emit) => emit(stateValue + 1));
  ///
  ///     // Handler with concurrency transformer:
  ///     on<IncrementAsync>(
  ///       (event, emit) async {
  ///         await Future<void>.delayed(const Duration(milliseconds: 100));
  ///         emit(stateValue + 1);
  ///       },
  ///       transformer: restartable(),
  ///     );
  ///   }
  /// }
  /// ```
  @protected
  void on<E extends Event>(
    FutureOr<void> Function(
      E event,
      void Function(StateType state) emit,
    ) handler, {
    EventTransformer<E, StateType>? transformer,
  }) {
    if (_handlers.any((h) => h.type == E)) {
      throw StateError(
        'on<$E> was called multiple times. '
        'There should only be a single event handler for each event.',
      );
    }
    _handlers.add(
      _HandlerRegistry<Event, StateType>(
        type: E,
        isType: (dynamic e) => e is E,
        handler: (dynamic event, void Function(StateType state) emit) {
          if (transformer != null) {
            return transformer(
              event as E,
              (e, em) => handler(e, em),
              emit,
            );
          }
          return handler(event as E, emit);
        },
      ),
    );
  }

  /// Handles incoming events and delegates them to registered handlers.
  ///
  /// Can be overridden to customize event routing or behavior.
  @mustCallSuper
  FutureOr<void> onEvent(Event event) {
    final matched = _handlers.where((h) => h.isType(event));
    List<Future<dynamic>>? futures;
    for (final registry in matched) {
      final result = registry.handler(event, emit) as dynamic;
      if (result is Future) {
        (futures ??= []).add(result);
      }
    }
    if (futures != null) {
      return Future.wait(futures).then<void>((_) {});
    }
  }
}

class _HandlerRegistry<Event, StateType> {
  _HandlerRegistry({
    required this.type,
    required this.isType,
    required this.handler,
  });

  final Type type;
  final bool Function(dynamic) isType;
  final FutureOr<dynamic> Function(
    dynamic event,
    void Function(StateType state) emit,
  ) handler;
}
