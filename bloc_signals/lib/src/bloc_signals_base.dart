import 'dart:async';

import 'package:signals/signals.dart';

/// An observer interface to watch all [BlocSignal] instances' lifecycles,
/// transitions, and events.
///
/// Implement this class and assign it to [BlocSignalObserver.observer] to
/// intercept and log events, transitions, and errors globally.
abstract class BlocSignalObserver {
  /// The global observer instance used to monitor all [BlocSignal] activity.
  static BlocSignalObserver? observer;

  /// Called when an event is dispatched to any [BlocSignal]
  /// via [BlocSignal.add].
  void onEvent(BlocSignal<dynamic, dynamic> bloc, Object? event) {}

  /// Called when any [BlocSignal] transitions to a new state
  /// via [BlocSignal.emit].
  void onTransition(
    BlocSignal<dynamic, dynamic> bloc,
    Object? event,
    Object? state,
  ) {}

  /// Called when an error is thrown during event processing in
  /// [BlocSignal.onEvent] or inside a state transition.
  void onError(
    BlocSignal<dynamic, dynamic> bloc,
    Object error,
    StackTrace stackTrace,
  ) {}
}

/// A synchronous state management container integrating BLoC design patterns
/// with Rody Davis's signals v7.
///
/// State updates are immediate and synchronous, ensuring glitch-free rendering
/// and seamless integration with reactive contexts.
///
/// Example:
/// ```dart
/// sealed class CounterEvent {}
/// class Increment extends CounterEvent {}
///
/// class CounterBloc extends BlocSignal<CounterEvent, int> {
///   CounterBloc() : super(initialState: 0);
///
///   @override
///   void onEvent(CounterEvent event) {
///     switch (event) {
///       case Increment():
///         emit(stateValue + 1);
///     }
///   }
/// }
/// ```
abstract class BlocSignal<Event, StateType> {
  /// Creates a [BlocSignal] with the specified [initialState].
  ///
  /// Instantiates the underlying state signal and registers a lifecycle
  /// [SignalModel] tracking internal state changes.
  BlocSignal({required StateType initialState})
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

  /// Whether the [BlocSignal] is closed.
  ///
  /// A closed [BlocSignal] will drop any subsequent events and state updates.
  bool get isClosed => _isClosed;

  final Signal<StateType> _state;
  late final SignalModel<void> _lifecycleModel;
  final Object _zoneEventKey = Object();

  /// Exposes read-only access to the state signal.
  ReadonlySignal<StateType> get state => _state;

  /// Retrieves the current raw state value.
  StateType get stateValue => _state.value;

  /// Updates the state synchronously.
  ///
  /// If the [newState] is equal to the current state, the update is ignored.
  /// Otherwise, it triggers reactive effects and notifies the
  /// global [BlocSignalObserver].
  void emit(StateType newState) {
    if (_isClosed) return;
    final oldState = _state.value;
    if (oldState == newState) return;
    _state.value = newState;

    final currentObserver = BlocSignalObserver.observer;
    if (currentObserver != null) {
      final raw = Zone.current[_zoneEventKey];
      final event = raw is Event ? raw : null;
      currentObserver.onTransition(this, event, newState);
    }
  }

  /// Dispatches an event to the [onEvent] handler.
  ///
  /// Notifies the global [BlocSignalObserver] of the incoming event and catches
  /// errors thrown in [onEvent], delegating them to [onError].
  void add(Event event) {
    if (_isClosed) return;
    final currentObserver = BlocSignalObserver.observer;
    if (currentObserver != null) {
      currentObserver.onEvent(this, event);
    }

    runZoned(
      () {
        try {
          final result = onEvent(event);
          if (result is Future) {
            unawaited(() async {
              try {
                await result;
              } catch (e, stackTrace) {
                onError(e, stackTrace);
                if (e is Error) {
                  Error.throwWithStackTrace(e, stackTrace);
                }
              }
            }());
          }
        } catch (e, stackTrace) {
          onError(e, stackTrace);
          if (e is Error) rethrow;
        }
      },
      zoneValues: {_zoneEventKey: event},
    );
  }

  /// Override this method to handle incoming events and [emit] new states.
  FutureOr<void> onEvent(Event event);

  /// Called when an exception is thrown in [onEvent].
  ///
  /// Notifies the global [BlocSignalObserver] if one is registered.
  void onError(Object error, StackTrace stackTrace) {
    final currentObserver = BlocSignalObserver.observer;
    if (currentObserver != null) {
      currentObserver.onError(this, error, stackTrace);
    }
  }

  void _onStateChangedInternal(StateType latestState) {
    // Hooks for logging or syncing inside the SignalModel lifecycle
  }

  /// Shuts down all internal effects and disposes of the
  /// underlying [SignalModel].
  void close() {
    if (_isClosed) return;
    _isClosed = true;
    _lifecycleModel.dispose();
  }
}
