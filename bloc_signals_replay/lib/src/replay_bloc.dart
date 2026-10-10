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
    if (event is ReplayEvent) {
      onTransition(
        Transition<ReplayEvent, State>(
          currentState: oldState,
          event: event,
          nextState: newState,
        ),
      );
    } else {
      super.handleTransition(event, oldState, newState);
    }
  }

  @override
  @mustCallSuper
  void onTransition(covariant Transition<ReplayEvent, State> transition) {
    if (transition.event is Event) {
      super.onTransition(
        Transition<Event, State>(
          currentState: transition.currentState,
          event: transition.event as Event,
          nextState: transition.nextState,
        ),
      );
    } else {
      try {
        BlocSignalObserver.observer
            ?.onTransition(this, transition.event, transition.nextState);
      } on Exception catch (e, stackTrace) {
        onError(e, stackTrace);
      }
    }
  }

  @override
  @mustCallSuper
  FutureOr<void> onEvent(covariant ReplayEvent event) {
    if (event is _Undo || event is _Redo) {
      try {
        BlocSignalObserver.observer?.onEvent(this, event);
      } on Exception catch (e, stackTrace) {
        onError(e, stackTrace);
      }
    }
    if (event is Event) {
      return super.onEvent(event);
    }
  }

  void _notifyReplayEvent(ReplayEvent event) {
    try {
      unawaited(
        Future.value(onEvent(event)).catchError(
          onError,
          test: (e) => e is Exception,
        ),
      );
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
            runZoned(
              () => emit(newState),
              zoneValues: {
                zoneEventKey: event,
                zoneBlocKey: this,
              },
            );
          },
          (val) {
            final event = _Undo();
            _notifyReplayEvent(event);
            runZoned(
              () => emit(val),
              zoneValues: {
                zoneEventKey: event,
                zoneBlocKey: this,
              },
            );
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
