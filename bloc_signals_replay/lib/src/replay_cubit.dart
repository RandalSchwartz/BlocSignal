import 'dart:async';
import 'dart:collection';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:meta/meta.dart';

part 'change_stack.dart';
part 'replay_bloc.dart';

/// {@template replay_cubit}
/// A specialized [CubitSignal] which supports `undo` and `redo` operations.
///
/// [ReplayCubit] accepts an optional `limit` which determines
/// the max size of the history stack.
///
/// ```dart
/// class CounterCubit extends ReplayCubit<int> {
///   CounterCubit() : super(0);
///
///   void increment() => emit(stateValue + 1);
/// }
/// ```
///
/// Then the built-in `undo` and `redo` operations can be used:
///
/// ```dart
/// final cubit = CounterCubit();
/// cubit.increment(); // 1
/// cubit.undo();      // 0
/// cubit.redo();      // 1
/// ```
/// {@endtemplate}
abstract class ReplayCubit<State> extends CubitSignal<State>
    with ReplayCubitMixin<State> {
  /// {@macro replay_cubit}
  ReplayCubit(
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

/// A mixin which enables `undo` and `redo` operations for [BlocSignalBase] and
/// [CubitSignal] classes.
mixin ReplayCubitMixin<State> on BlocSignalBase<State> {
  late final _changeStack = _ChangeStack<State>(shouldReplay: shouldReplay);

  /// Sets the internal `undo`/`redo` size limit.
  ///
  /// By default there is no limit.
  set limit(int limit) => _changeStack.limit = limit;

  @override
  void emit(State state) {
    _changeStack.add(
      _Change<State>(
        stateValue,
        state,
        () => super.emit(state),
        (val) => super.emit(val),
      ),
    );
    super.emit(state);
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
