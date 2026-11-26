import 'dart:async';
import 'dart:collection';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:meta/meta.dart';
import 'package:signals_core/signals_core.dart';

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
///   CounterCubit() : super(initialState: 0);
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
  ReplayCubit({
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

  /// Creates a [ReplayCubit] with a positional [initialState].
  @Deprecated('Use named parameter initialState: instead')
  ReplayCubit.positional(
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

/// A base mixin which enables `undo` and `redo` operations for
/// [BlocSignalBase] classes.
///
/// ```dart
/// class CounterCubit extends CubitSignal<int> with ReplayMixin<int> {
///   CounterCubit() : super(initialState: 0);
///
///   void increment() => emit(stateValue + 1);
/// }
/// ```
///
/// ## Memory Management and Sensitive State
///
/// Because [ReplayMixin] retains historical state instances in memory,
/// applications holding sensitive state (for example passwords, authentication
/// tokens, or personally identifiable information) should configure a bounded
/// [limit] (or set `limit = 0` during sensitive flows) and call [clearHistory]
/// at logout or session boundaries. Calling [close] automatically invokes
/// [clearHistory] to release retained state references and reset [canUndo]
/// and [canRedo].
mixin ReplayMixin<State> on BlocSignalBase<State> {
  late final _changeStack = _ChangeStack<State>(shouldReplay: shouldReplay);

  /// The internal `undo`/`redo` size limit.
  ///
  /// If `null`, there is no limit. For containers holding sensitive state (for
  /// example passwords, authentication tokens, or personally identifiable
  /// information), configure a bounded [limit] or set `limit = 0` during
  /// sensitive flows to prevent unbounded retention in memory.
  int? get limit => _changeStack.limit;

  /// Sets the internal `undo`/`redo` size limit.
  ///
  /// By default there is no limit. Setting `limit` to `0` or less immediately
  /// clears existing history and disables further recording until a positive
  /// limit (or `null`) is configured.
  set limit(int? limit) => _changeStack.limit = limit;

  bool _isReplaying = false;

  late final Computed<bool> _canUndo = computed<bool>(() {
    _changeStack.revision;
    return _changeStack.canUndo;
  });

  late final Computed<bool> _canRedo = computed<bool>(() {
    _changeStack.revision;
    return _changeStack.canRedo;
  });

  @override
  void emit(State newState) {
    if (isClosed) return;
    if (equals(stateValue, newState)) return;

    final oldState = stateValue;
    batch(() {
      if (!_isReplaying && !isHistorySuppressed) {
        final last = _changeStack.lastChange;
        if (last != null &&
            shouldCoalesce(last._oldValue, oldState, newState)) {
          if (equals(last._oldValue, newState)) {
            _changeStack.dropLast();
          } else {
            final coalescedOld = last._oldValue;
            _changeStack.replaceLast(
              _Change<State>(
                coalescedOld,
                newState,
                () => onRedo(() => emit(newState)),
                (val) => onUndo(() => emit(val)),
              ),
            );
          }
        } else {
          _changeStack.add(
            _Change<State>(
              oldState,
              newState,
              () => onRedo(() => emit(newState)),
              (val) => onUndo(() => emit(val)),
            ),
          );
        }
      }
      super.emit(newState);
    });
  }

  /// Executes a redo restoration [action].
  ///
  /// Subclasses or mixins can override this to wrap restoration with event
  /// notifications or zone values.
  @protected
  void onRedo(void Function() action) => action();

  /// Executes an undo restoration [action].
  ///
  /// Subclasses or mixins can override this to wrap restoration with event
  /// notifications or zone values.
  @protected
  void onUndo(void Function() action) => action();

  /// Undo the last change.
  void undo() {
    if (isClosed) return;
    _isReplaying = true;
    try {
      batch(_changeStack.undo);
    } finally {
      _isReplaying = false;
    }
  }

  /// Redo the previous change.
  void redo() {
    if (isClosed) return;
    _isReplaying = true;
    try {
      batch(_changeStack.redo);
    } finally {
      _isReplaying = false;
    }
  }

  /// A reactive signal tracking whether [undo] can currently be performed.
  ///
  /// Useful for passing directly to signal builders or combining with other
  /// `computed` signals without wrapping in a getter.
  ReadonlySignal<bool> get canUndoSignal => _canUndo;

  /// A reactive signal tracking whether [redo] can currently be performed.
  ///
  /// Useful for passing directly to signal builders or combining with other
  /// `computed` signals without wrapping in a getter.
  ReadonlySignal<bool> get canRedoSignal => _canRedo;

  /// Checks whether the undo/redo stack can perform an undo operation.
  ///
  /// Reading [canUndo] inside a `computed`, `effect`, `Watch`, or
  /// `context.select` automatically subscribes to history changes.
  bool get canUndo => _canUndo.value;

  /// Checks whether the undo/redo stack can perform a redo operation.
  ///
  /// Reading [canRedo] inside a `computed`, `effect`, `Watch`, or
  /// `context.select` automatically subscribes to history changes.
  bool get canRedo => _canRedo.value;

  /// Clears internal undo/redo history.
  ///
  /// Call [clearHistory] at logout or session boundaries when a container
  /// holds sensitive state (for example passwords, authentication tokens, or
  /// personally identifiable information) to release retained state
  /// references immediately.
  void clearHistory() => batch(_changeStack.clear);

  @override
  @protected
  @mustCallSuper
  void onReset() {
    clearHistory();
    super.onReset();
  }

  /// Closes the container and clears the internal undo/redo history.
  ///
  /// Automatically invokes [clearHistory] to release retained state references
  /// and reset [canUndo] and [canRedo] to `false`.
  @override
  @mustCallSuper
  Future<void> close() {
    clearHistory();
    return super.close();
  }

  /// Checks whether the given state should be replayed from the undo/redo
  /// stack.
  ///
  /// This is called at the time the state is being restored.
  /// By default [shouldReplay] always returns `true`.
  bool shouldReplay(State state) => true;

  /// Determines whether an incoming transition from [currentState] to
  /// [nextState] should be coalesced into the previous undo entry whose
  /// starting state was [previousState].
  ///
  /// Override this hook to merge continuous gestures (such as slider drags,
  /// freehand drawing strokes, or rapid text edits) into a single undoable
  /// step. When this returns `true` and `equals(previousState, nextState)` is
  /// also `true`, the no-op undo entry is dropped automatically.
  ///
  /// Defaults to `false`.
  @protected
  bool shouldCoalesce(
    State previousState,
    State currentState,
    State nextState,
  ) =>
      false;
}

/// A mixin which enables `undo` and `redo` operations for [BlocSignalBase] and
/// [CubitSignal] classes.
///
/// ```dart
/// class CounterCubit extends CubitSignal<int> with ReplayCubitMixin<int> {
///   CounterCubit() : super(initialState: 0);
///
///   void increment() => emit(stateValue + 1);
/// }
/// ```
typedef ReplayCubitMixin<State> = ReplayMixin<State>;
