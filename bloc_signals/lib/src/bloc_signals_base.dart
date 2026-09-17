import 'dart:async';

import 'package:bloc_signals/src/change.dart';
import 'package:meta/meta.dart';
import 'package:signals_core/signals_core.dart';

export 'change.dart';
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

  /// Adds an [observer] to the global observation pipeline.
  ///
  /// If no observer is currently set, [observer] becomes the active global
  /// observer. If an observer is already set, it is upgraded into a
  /// [CompositeBlocSignalObserver] containing both observers without
  /// disconnecting existing diagnostic sinks.
  static void addObserver(BlocSignalObserver observer) {
    final current = BlocSignalObserver.observer;
    if (current == null) {
      BlocSignalObserver.observer = observer;
    } else if (current is CompositeBlocSignalObserver) {
      current.add(observer);
    } else {
      BlocSignalObserver.observer =
          CompositeBlocSignalObserver([current, observer]);
    }
  }

  /// Removes an [observer] from the global observation pipeline.
  ///
  /// Returns `true` if the observer was found and removed.
  static bool removeObserver(BlocSignalObserver observer) {
    final current = BlocSignalObserver.observer;
    if (current == null) return false;
    if (identical(current, observer)) {
      BlocSignalObserver.observer = null;
      return true;
    }
    if (current is CompositeBlocSignalObserver) {
      final removed = current.remove(observer);
      if (current.observers.isEmpty) {
        BlocSignalObserver.observer = null;
      }
      return removed;
    }
    return false;
  }

  /// Called when a [BlocSignalBase] is created.
  void onCreate(BlocSignalBase<dynamic> bloc) {}

  /// Called when an event is dispatched to any event-driven container
  /// via `add`.
  void onEvent(BlocSignalBase<dynamic> bloc, Object? event) {}

  /// Called when processing of an event has completed (synchronously or
  /// asynchronously).
  void onEventCompleted(BlocSignalBase<dynamic> bloc, Object? event) {}

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

  /// Called when a container or concurrency transformer emits
  /// diagnostic or observability telemetry (for example: dropped events,
  /// task preemption, queue latencies, cache events, or rate-limiting).
  void onTelemetry(
    BlocSignalBase<dynamic> bloc,
    String name, {
    Object? event,
    Map<String, dynamic>? metadata,
  }) {}

  /// Called when a [BlocSignalBase] is closed.
  void onClose(BlocSignalBase<dynamic> bloc) {}
}

/// A composite [BlocSignalObserver] that broadcasts lifecycle notifications
/// to multiple inner observers in the order they were registered.
///
/// Exceptions thrown by individual observers are isolated: an error thrown by
/// one observer will not prevent subsequent observers from receiving the hook,
/// and the failure is forwarded to [BlocSignalBase.onError].
class CompositeBlocSignalObserver extends BlocSignalObserver {
  /// Creates a [CompositeBlocSignalObserver] with the provided [observers].
  CompositeBlocSignalObserver([Iterable<BlocSignalObserver>? observers])
      : _observers = List<BlocSignalObserver>.from(observers ?? const []);

  final List<BlocSignalObserver> _observers;

  /// An unmodifiable view of the currently registered observers.
  List<BlocSignalObserver> get observers => List.unmodifiable(_observers);

  /// Registers an [observer] at the end of the composite pipeline.
  void add(BlocSignalObserver observer) {
    _observers.add(observer);
  }

  /// Removes the first occurrence of [observer] from the composite pipeline.
  ///
  /// Returns `true` if an observer was removed.
  bool remove(BlocSignalObserver observer) {
    return _observers.remove(observer);
  }

  /// Removes all observers from this composite pipeline.
  void clear() {
    _observers.clear();
  }

  @override
  void onCreate(BlocSignalBase<dynamic> bloc) {
    for (final observer in _observers) {
      try {
        observer.onCreate(bloc);
      } on Object catch (e, stackTrace) {
        bloc.onError(e, stackTrace);
      }
    }
  }

  @override
  void onEvent(BlocSignalBase<dynamic> bloc, Object? event) {
    for (final observer in _observers) {
      try {
        observer.onEvent(bloc, event);
      } on Object catch (e, stackTrace) {
        bloc.onError(e, stackTrace);
      }
    }
  }

  @override
  void onEventCompleted(BlocSignalBase<dynamic> bloc, Object? event) {
    for (final observer in _observers) {
      try {
        observer.onEventCompleted(bloc, event);
      } on Object catch (e, stackTrace) {
        bloc.onError(e, stackTrace);
      }
    }
  }

  @override
  void onTransition(
    BlocSignalBase<dynamic> bloc,
    Object? event,
    Object? state,
  ) {
    for (final observer in _observers) {
      try {
        observer.onTransition(bloc, event, state);
      } on Object catch (e, stackTrace) {
        bloc.onError(e, stackTrace);
      }
    }
  }

  @override
  void onChange(BlocSignalBase<dynamic> bloc, Change<dynamic> change) {
    for (final observer in _observers) {
      try {
        observer.onChange(bloc, change);
      } on Object catch (e, stackTrace) {
        bloc.onError(e, stackTrace);
      }
    }
  }

  @override
  void onError(
    BlocSignalBase<dynamic> bloc,
    Object error,
    StackTrace stackTrace,
  ) {
    for (final observer in _observers) {
      try {
        observer.onError(bloc, error, stackTrace);
      } on Object catch (_) {
        // Prevent observer error in onError from causing infinite recursion
      }
    }
  }

  @override
  void onTelemetry(
    BlocSignalBase<dynamic> bloc,
    String name, {
    Object? event,
    Map<String, dynamic>? metadata,
  }) {
    for (final observer in _observers) {
      try {
        observer.onTelemetry(
          bloc,
          name,
          event: event,
          metadata: metadata,
        );
      } on Object catch (e, stackTrace) {
        bloc.onError(e, stackTrace);
      }
    }
  }

  @override
  void onClose(BlocSignalBase<dynamic> bloc) {
    for (final observer in _observers) {
      try {
        observer.onClose(bloc);
      } on Object catch (e, stackTrace) {
        bloc.onError(e, stackTrace);
      }
    }
  }
}

/// Emits operational telemetry diagnostics on [bloc] from custom or built-in
/// concurrency transformers.
///
/// Use this public entrypoint to attach telemetry events (such as dropped
/// events, preemption, or queue latencies) from custom concurrency
/// transformers without requiring subclassing or protected method access.
void emitContainerTelemetry(
  BlocSignalBase<dynamic> bloc,
  String name, {
  Object? event,
  Map<String, dynamic>? metadata,
}) {
  bloc.emitTelemetry(name, event: event, metadata: metadata);
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
  ///
  /// This is the preferred modern getter for reading raw container state,
  /// establishing 1:1 symmetry with [state] (`bloc.state` / `bloc.value`),
  /// Flutter context extensions (`context.state` / `context.value`), and
  /// Flutter's `ValueListenable.value`.
  ///
  /// ```dart
  /// final counterBloc = CounterBloc();
  /// print(counterBloc.value); // 0
  /// ```
  StateType get value;

  /// Retrieves the current raw state value.
  ///
  /// This getter remains fully supported for backward compatibility with
  /// earlier releases, but [value] is preferred for concise and symmetrical
  /// code.
  StateType get stateValue;

  /// Compares [previous] and [current] state to determine if state has changed.
  ///
  /// Subclasses can override this method or pass `equals: identical` to force
  /// reference identity comparison.
  @protected
  bool equals(StateType previous, StateType current);

  /// Canonical zone key used to track the ambient host [BlocSignalBase]
  /// instance.
  static final Object ambientZoneBlocKey = Object();

  /// Internal zone key used to track the causing event of a transition.
  @protected
  Object get zoneEventKey;

  /// Internal zone key used to track the host bloc instance.
  @protected
  Object get zoneBlocKey;

  /// Updates the state synchronously.
  ///
  /// If the [newState] is equal to the current state via [equals], the update
  /// is ignored. Otherwise, it triggers reactive effects and notifies the
  /// global [BlocSignalObserver].
  @protected
  @visibleForTesting
  void emit(StateType newState);

  /// Internal helper to dispatch transitions to event-driven containers.
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

  /// Emits an error to this container and the global [BlocSignalObserver].
  ///
  /// Forwards directly to [onError].
  @protected
  @mustCallSuper
  void emitError(Object error, [StackTrace? stackTrace]);

  /// Backward-compatible alias for [emitError] to maintain classic BLoC
  /// protocol parity.
  @protected
  @mustCallSuper
  void addError(Object error, [StackTrace? stackTrace]);

  /// Emits an operational telemetry diagnostic event to this container
  /// and the global [BlocSignalObserver].
  ///
  /// Telemetry events represent non-state operational physics (such as cache
  /// hits/misses, queue wait times, or dropped events) or business milestones
  /// (such as checkout initiated) that must not pollute UI domain state.
  ///
  /// ```dart
  /// emitTelemetry(
  ///   'cache_hit',
  ///   metadata: {'key': itemId, 'latency_ms': 5},
  /// );
  /// ```
  @protected
  void emitTelemetry(
    String name, {
    Object? event,
    Map<String, dynamic>? metadata,
  });

  /// Hook invoked when telemetry is emitted. Subclasses can override to
  /// enrich or filter telemetry before passing to the global observer.
  @protected
  @mustCallSuper
  void onTelemetry(
    String name, {
    Object? event,
    Map<String, dynamic>? metadata,
  });

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
