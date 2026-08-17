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
///   CounterBloc() : super(0) {
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
    extends BlocSignal<Event, State> with ReplayBlocMixin<Event, State> {
  /// {@macro replay_bloc}
  ReplayBloc(
    State initialState, {
    int? limit,
    super.equals,
    super.options,
  }) : super(initialState: initialState) {
    if (limit != null) {
      this.limit = limit;
    }
  }
}

/// A mixin which enables `undo` and `redo` operations for [BlocSignal] classes.
mixin ReplayBlocMixin<Event extends ReplayEvent, State>
    on BlocSignal<Event, State> {
  late final _changeStack = _ChangeStack<State>(shouldReplay: shouldReplay);

  /// Sets the internal `undo`/`redo` size limit.
  ///
  /// By default there is no limit.
  set limit(int limit) => _changeStack.limit = limit;

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
      BlocSignalObserver.observer
          ?.onTransition(this, transition.event, transition.nextState);
    }
  }

  @override
  @mustCallSuper
  FutureOr<void> onEvent(covariant ReplayEvent event) {
    if (event is _Undo || event is _Redo) {
      BlocSignalObserver.observer?.onEvent(this, event);
    }
    if (event is Event) {
      return super.onEvent(event);
    }
  }

  @override
  void emit(State newState) {
    _changeStack.add(
      _Change<State>(
        stateValue,
        newState,
        () {
          final event = _Redo();
          unawaited(Future.value(onEvent(event)));
          onTransition(
            Transition<ReplayEvent, State>(
              currentState: stateValue,
              event: event,
              nextState: newState,
            ),
          );
          super.emit(newState);
        },
        (val) {
          final event = _Undo();
          unawaited(Future.value(onEvent(event)));
          onTransition(
            Transition<ReplayEvent, State>(
              currentState: stateValue,
              event: event,
              nextState: val,
            ),
          );
          super.emit(val);
        },
      ),
    );
    super.emit(newState);
  }

  /// Undo the last change.
  void undo() => _changeStack.undo();

  /// Redo the previous change.
  void redo() => _changeStack.redo();

  /// Checks whether the undo/redo stack can perform an undo operation.
  bool get canUndo => _changeStack.canUndo;

  /// Checks whether the undo/redo stack can perform a redo operation.
  bool get canRedo => _changeStack.canRedo;

  /// Clears internal undo/redo history.
  void clearHistory() => _changeStack.clear();

  /// Checks whether the given state should be replayed from the undo/redo
  /// stack.
  ///
  /// This is called at the time the state is being restored.
  /// By default [shouldReplay] always returns `true`.
  bool shouldReplay(State state) => true;
}
