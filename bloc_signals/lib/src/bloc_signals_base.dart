import 'dart:async';

import 'package:bloc_signals/src/bloc_signal_mixin.dart';
import 'package:bloc_signals/src/change.dart';
import 'package:bloc_signals/src/cubit_signal_mixin.dart';
import 'package:meta/meta.dart';
import 'package:preact_signals/preact_signals.dart' show SignalEquality;
import 'package:signals_core/signals_core.dart';

export 'bloc_signal_mixin.dart';
export 'change.dart';
export 'cubit_signal_mixin.dart';
export 'transition.dart';

/// An observer interface to watch all [BlocSignalBase] instances' lifecycles,
/// transitions, and events.
///
/// Implement this class and assign it to [BlocSignalObserver.observer] to
/// intercept and log events, transitions, and errors globally.
abstract class BlocSignalObserver {
  /// Creates a [BlocSignalObserver].
  const BlocSignalObserver();

  /// The global observer instance used to monitor all [BlocSignalBase]
  /// activity.
  static BlocSignalObserver? observer;

  /// Called when a [BlocSignalBase] is created.
  void onCreate(BlocSignalBase<dynamic> bloc) {}

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

  /// Called when a [BlocSignalBase] has a state change.
  void onChange(BlocSignalBase<dynamic> bloc, Change<dynamic> change) {}

  /// Called when an error is thrown during event processing or
  /// inside a state transition.
  void onError(
    BlocSignalBase<dynamic> bloc,
    Object error,
    StackTrace stackTrace,
  ) {}

  /// Called when a [BlocSignalBase] is closed.
  void onClose(BlocSignalBase<dynamic> bloc) {}
}

/// A base contract for all reactive state containers.
///
/// Manages the state signal, provides lifecycle hooks, and manages disposal.
abstract class BlocSignalBase<StateType> {
  /// Creates a [BlocSignalBase].
  const BlocSignalBase();

  /// Whether the state container is closed.
  ///
  /// A closed container will drop any subsequent events and state updates.
  bool get isClosed;

  /// Exposes read-only access to the state signal.
  ReadonlySignal<StateType> get state;

  /// Retrieves the current raw state value.
  StateType get stateValue;

  /// Compares [previous] and [current] state to determine if state has changed.
  ///
  /// Subclasses can override this method or pass `equals: identical` to force
  /// reference identity comparison.
  @protected
  bool equals(StateType previous, StateType current);

  /// Internal zone key used to track the causing event of a transition.
  @protected
  Object get zoneEventKey;

  /// Updates the state synchronously.
  ///
  /// If the [newState] is equal to the current state via [equals], the update
  /// is ignored. Otherwise, it triggers reactive effects and notifies the
  /// global [BlocSignalObserver].
  @protected
  @visibleForTesting
  void emit(StateType newState);

  /// Internal helper to dispatch transitions to the type-safe [BlocSignal].
  @protected
  void handleTransition(Object event, StateType oldState, StateType newState);

  /// Called when a state change occurs.
  @protected
  @mustCallSuper
  void onChange(Change<StateType> change);

  /// Called when an exception is thrown in event processing or state
  /// transition.
  ///
  /// Notifies the global [BlocSignalObserver] if one is registered.
  @protected
  @mustCallSuper
  void onError(Object error, StackTrace stackTrace);

  /// Creates a reactive [effect] that is automatically cleaned up when the
  /// state container is closed.
  ///
  /// Optionally accepts an [options] configuration object to customize effect
  /// options such as debug name or disposal callback.
  @protected
  void Function() createEffect(
    void Function() callback, {
    EffectOptions? options,
    void Function()? onDispose,
  });

  /// Shuts down all internal effects and disposes of the
  /// underlying [SignalModel].
  @mustCallSuper
  Future<void> close();
}

/// A clean base class for method-driven state management.
///
/// Exposes state and [emit] directly for subclass methods.
abstract class CubitSignal<StateType> extends BlocSignalBase<StateType>
    with CubitSignalMixin<StateType> {
  /// Creates a [CubitSignal] with the specified [initialState].
  ///
  /// Accepts an optional [equals] comparator callback (for example
  /// `equals: identical` to force reference-identity equality updates), and
  /// optional [options] to configure signal debug names ([SignalOptions.name])
  /// or custom [SignalEquality].
  ///
  /// ```dart
  /// class CounterCubit extends CubitSignal<int> {
  ///   CounterCubit() : super(initialState: 0);
  ///
  ///   void increment() => emit(stateValue + 1);
  /// }
  /// ```
  CubitSignal({
    required StateType initialState,
    bool Function(StateType previous, StateType current)? equals,
    SignalOptions<StateType>? options,
  }) {
    initCubitSignal(
      initialState: initialState,
      equals: equals,
      options: options,
    );
  }
}

/// A synchronous state management container integrating BLoC design patterns
/// with Rody Davis's signals v7.
///
/// State updates are immediate and synchronous, ensuring glitch-free rendering
/// and seamless integration with reactive contexts.
abstract class BlocSignal<Event, StateType> extends BlocSignalBase<StateType>
    with CubitSignalMixin<StateType>, BlocSignalMixin<Event, StateType> {
  /// Creates a [BlocSignal] with the specified [initialState].
  ///
  /// Accepts an optional [equals] comparator callback (for example
  /// `equals: identical` to force reference-identity equality updates), and
  /// optional [options] to configure signal debug names ([SignalOptions.name])
  /// or custom [SignalEquality].
  ///
  /// ```dart
  /// class CounterBloc extends BlocSignal<CounterEvent, int> {
  ///   CounterBloc() : super(initialState: 0) {
  ///     on<Increment>((event, emit) => emit(stateValue + 1));
  ///   }
  /// }
  /// ```
  BlocSignal({
    required StateType initialState,
    bool Function(StateType previous, StateType current)? equals,
    SignalOptions<StateType>? options,
  }) {
    initCubitSignal(
      initialState: initialState,
      equals: equals,
      options: options,
    );
  }
}
