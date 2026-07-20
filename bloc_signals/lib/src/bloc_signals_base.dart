import 'dart:async';

import 'package:meta/meta.dart';
import 'package:signals/signals.dart';

/// An observer interface to watch all [BlocSignalBase] instances' lifecycles,
/// transitions, and events.
///
/// Implement this class and assign it to [BlocSignalObserver.observer] to
/// intercept and log events, transitions, and errors globally.
abstract class BlocSignalObserver {
  /// The global observer instance used to monitor all [BlocSignalBase]
  /// activity.
  static BlocSignalObserver? observer;

  /// Called when an event is dispatched to any [BlocSignal]
  /// via [BlocSignal.add].
  void onEvent(BlocSignalBase<dynamic> bloc, Object? event) {}

  /// Called when any [BlocSignalBase] transitions to a new state
  /// via [BlocSignalBase.emit].
  void onTransition(
    BlocSignalBase<dynamic> bloc,
    Object? event,
    Object? state,
  ) {}

  /// Called when an error is thrown during event processing or
  /// inside a state transition.
  void onError(
    BlocSignalBase<dynamic> bloc,
    Object error,
    StackTrace stackTrace,
  ) {}
}

/// A base class for all reactive state containers.
///
/// Manages the state signal, provides lifecycle hooks, and manages disposal.
abstract class BlocSignalBase<StateType> {
  /// Creates a [BlocSignalBase] with the specified [initialState].
  BlocSignalBase({required StateType initialState})
      : _state = signal(initialState) {
    final modelConstructor = createModel(() {
      effect(() {
        _onStateChangedInternal(_state.value);
      });
      return null;
    });
    _lifecycleModel = modelConstructor();
  }

  bool _isClosed = false;

  /// Whether the state container is closed.
  ///
  /// A closed container will drop any subsequent events and state updates.
  bool get isClosed => _isClosed;

  final Signal<StateType> _state;
  late final SignalModel<void> _lifecycleModel;
  final List<void Function()> _effectsToDispose = [];

  /// Exposes read-only access to the state signal.
  ReadonlySignal<StateType> get state => _state;

  /// Retrieves the current raw state value.
  StateType get stateValue => _state.value;

  /// Internal zone key used to track the causing event of a transition.
  @protected
  Object get zoneEventKey => _zoneEventKey;
  final Object _zoneEventKey = Object();

  /// Updates the state synchronously.
  ///
  /// If the [newState] is equal to the current state, the update is ignored.
  /// Otherwise, it triggers reactive effects and notifies the
  /// global [BlocSignalObserver].
  @protected
  @visibleForTesting
  void emit(StateType newState) {
    assert(
      !_isClosed,
      'Cannot emit new states after calling close() on $runtimeType.',
    );
    if (_isClosed) return;
    final oldState = _state.value;
    if (oldState == newState) return;
    _state.value = newState;

    final currentObserver = BlocSignalObserver.observer;
    if (currentObserver != null) {
      final raw = Zone.current[zoneEventKey];
      currentObserver.onTransition(this, raw, newState);
    }
  }

  /// Called when an exception is thrown in event processing or state
  /// transition.
  ///
  /// Notifies the global [BlocSignalObserver] if one is registered.
  @protected
  @mustCallSuper
  void onError(Object error, StackTrace stackTrace) {
    final currentObserver = BlocSignalObserver.observer;
    if (currentObserver != null) {
      currentObserver.onError(this, error, stackTrace);
    }
  }

  void _onStateChangedInternal(StateType latestState) {
    // Hooks for logging or syncing inside the SignalModel lifecycle
  }

  /// Creates a reactive [effect] that is automatically cleaned up when the
  /// state container is closed.
  @protected
  void Function() createEffect(
    void Function() callback, {
    void Function()? onDispose,
  }) {
    final dispose = effect(
      callback,
      options: EffectOptions(onDispose: onDispose),
    );
    _effectsToDispose.add(dispose);
    return dispose;
  }

  /// Shuts down all internal effects and disposes of the
  /// underlying [SignalModel].
  @mustCallSuper
  void close() {
    if (_isClosed) return;
    _isClosed = true;
    for (final dispose in _effectsToDispose) {
      dispose();
    }
    _effectsToDispose.clear();
    _lifecycleModel.dispose();
  }
}

/// A clean base class for method-driven state management.
///
/// Exposes state and [emit] directly for subclass methods.
abstract class CubitSignal<StateType> extends BlocSignalBase<StateType> {
  /// Creates a [CubitSignal] with the specified [initialState].
  CubitSignal({required super.initialState});
}

/// A synchronous state management container integrating BLoC design patterns
/// with Rody Davis's signals v7.
///
/// State updates are immediate and synchronous, ensuring glitch-free rendering
/// and seamless integration with reactive contexts.
abstract class BlocSignal<Event, StateType> extends BlocSignalBase<StateType> {
  /// Creates a [BlocSignal] with the specified [initialState].
  BlocSignal({required super.initialState});

  final List<_HandlerRegistry<Event, StateType>> _handlers = [];

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
  /// ```dart
  /// class CounterBloc extends BlocSignal<CounterEvent, int> {
  ///   CounterBloc() : super(initialState: 0) {
  ///     on<Increment>((event, emit) => emit(stateValue + 1));
  ///   }
  /// }
  /// ```
  @protected
  void on<E extends Event>(
    FutureOr<void> Function(
      E event,
      void Function(StateType state) emit,
    ) handler,
  ) {
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
