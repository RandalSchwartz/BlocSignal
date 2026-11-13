part of 'replay_cubit.dart';

/// {@template replay_event}
/// Base event class for all [ReplayBloc] events.
/// {@endtemplate}
abstract class ReplayEvent {
  /// {@macro replay_event}
  const ReplayEvent();
}

/// Notifies a [ReplayBloc] of a Redo operation.
class _Redo extends ReplayEvent {
  @override
  String toString() => 'Redo';
}

/// Notifies a [ReplayBloc] of an Undo operation.
class _Undo extends ReplayEvent {
  @override
  String toString() => 'Undo';
}

/// {@template replay_bloc}
/// A specialized [BlocSignal] which supports `undo` and `redo` operations.
///
/// [ReplayBloc] accepts an optional `limit` which determines
/// the max size of the history stack.
///
/// ```dart
/// sealed class CounterEvent extends ReplayEvent {
///   const CounterEvent();
/// }
/// final class Increment extends CounterEvent {
///   const Increment();
/// }
///
/// class CounterBloc extends ReplayBloc<CounterEvent, int> {
///   CounterBloc() : super(initialState: 0) {
///     on<Increment>((event, emit) => emit(stateValue + 1));
///   }
/// }
/// ```
///
/// Then the built-in `undo` and `redo` operations can be used:
///
/// ```dart
/// final bloc = CounterBloc();
/// bloc.add(const Increment());
/// bloc.undo();
/// bloc.redo();
/// ```
/// {@endtemplate}
abstract class ReplayBloc<Event extends ReplayEvent, State>
    extends BlocSignal<Event, State>
    with ReplayMixin<State>, ReplayBlocMixin<Event, State> {
  /// {@macro replay_bloc}
  ReplayBloc({
    required super.initialState,
    int? limit,
    int? maxHistoryLength,
    super.equals,
    super.options,
  }) {
    final effectiveLimit = limit ?? maxHistoryLength;
    if (effectiveLimit != null) {
      this.limit = effectiveLimit;
    }
  }

  /// Creates a [ReplayBloc] with a positional [initialState].
  @Deprecated('Use named parameter initialState: instead')
  ReplayBloc.positional(
    State initialState, {
    int? limit,
    int? maxHistoryLength,
    super.equals,
    super.options,
  }) : super(initialState: initialState) {
    final effectiveLimit = limit ?? maxHistoryLength;
    if (effectiveLimit != null) {
      this.limit = effectiveLimit;
    }
  }
}

/// A mixin which enables `undo` and `redo` operations for [BlocSignal] classes.
///
/// Apply alongside [ReplayMixin] (or [ReplayCubitMixin]) when composing onto a
/// [BlocSignal] class:
///
/// ```dart
/// class CounterBloc extends BlocSignal<CounterEvent, int>
///     with ReplayMixin<int>, ReplayBlocMixin<CounterEvent, int> {
///   CounterBloc() : super(initialState: 0) {
///     on<Increment>((event, emit) => emit(stateValue + 1));
///   }
/// }
/// ```
mixin ReplayBlocMixin<Event extends ReplayEvent, State>
    on BlocSignal<Event, State>, ReplayMixin<State> {
  @override
  @protected
  void handleTransition(Object event, State oldState, State newState) {
    if (event is Event) {
      super.handleTransition(event, oldState, newState);
    } else if (event is ReplayEvent) {
      try {
        BlocSignalObserver.observer?.onTransition(this, event, newState);
      } on Exception catch (e, stackTrace) {
        onError(e, stackTrace);
      }
    } else {
      super.handleTransition(event, oldState, newState);
    }
  }

  /// Called whenever a synthetic [ReplayEvent] (`Undo` or `Redo`) is
  /// dispatched during [undo] or [redo].
  ///
  /// Notifies [BlocSignalObserver.observer] via `onEvent` while isolating any
  /// thrown [Exception] to [onError]. Subclasses that override [onReplay] must
  /// call `super.onReplay(event)`.
  ///
  /// ```dart
  /// class LoggingCounterBloc extends ReplayBloc<CounterEvent, int> {
  ///   LoggingCounterBloc() : super(initialState: 0) {
  ///     on<CounterIncrementPressed>((event, emit) => emit(stateValue + 1));
  ///   }
  ///
  ///   @override
  ///   FutureOr<void> onReplay(ReplayEvent event) {
  ///     super.onReplay(event);
  ///     // Record or inspect synthetic Undo / Redo events.
  ///   }
  /// }
  /// ```
  @protected
  @mustCallSuper
  FutureOr<void> onReplay(ReplayEvent event) {
    try {
      BlocSignalObserver.observer?.onEvent(this, event);
    } on Exception catch (e, stackTrace) {
      onError(e, stackTrace);
    }
  }

  void _notifyReplayEvent(ReplayEvent event) {
    try {
      unawaited(
        Future.value(onReplay(event)).catchError(
          onError,
          test: (e) => e is Exception,
        ),
      );
    } on Exception catch (e, stackTrace) {
      onError(e, stackTrace);
    }
  }

  void _notifyReplayEventCompleted(ReplayEvent event) {
    try {
      BlocSignalObserver.observer?.onEventCompleted(this, event);
    } on Exception catch (e, stackTrace) {
      onError(e, stackTrace);
    }
  }

  @override
  void emit(State newState) {
    if (isClosed) return;
    if (equals(stateValue, newState)) return;

    if (!_isReplaying) {
      _changeStack.add(
        _Change<State>(
          stateValue,
          newState,
          () {
            final event = _Redo();
            _notifyReplayEvent(event);
            try {
              runZoned(
                () => emit(newState),
                zoneValues: {
                  zoneEventKey: event,
                  zoneBlocKey: this,
                },
              );
            } finally {
              _notifyReplayEventCompleted(event);
            }
          },
          (val) {
            final event = _Undo();
            _notifyReplayEvent(event);
            try {
              runZoned(
                () => emit(val),
                zoneValues: {
                  zoneEventKey: event,
                  zoneBlocKey: this,
                },
              );
            } finally {
              _notifyReplayEventCompleted(event);
            }
          },
        ),
      );
    }
    final previousReplaying = _isReplaying;
    _isReplaying = true;
    try {
      super.emit(newState);
    } finally {
      _isReplaying = previousReplaying;
    }
  }
}
