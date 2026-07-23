import 'dart:async';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_hydrate/src/hydrated_storage.dart';
import 'package:meta/meta.dart';

/// A mixin that provides state persistence and hydration capabilities for
/// [BlocSignalBase] containers.
mixin HydratedMixin<StateType> on BlocSignalBase<StateType> {
  /// The initial default state for this container when no persisted state exists.
  StateType get initialState;

  /// An optional unique identifier for this instance when multiple instances
  /// of the same class exist concurrently.
  String? get id => null;

  /// The prefix key used to scope this class in [HydratedStorage]. Defaults to
  /// `runtimeType.toString()`.
  String get storagePrefix => runtimeType.toString();

  /// The unique storage token key derived from [storagePrefix] and optional [id].
  String get storageToken => '$storagePrefix${id != null ? '_$id' : ''}';

  /// An explicit [HydratedStorage] override instance for this container. If
  /// `null`, falls back to [HydratedStorage.storage].
  HydratedStorage? get storageOverride => null;

  /// Resolves the active [HydratedStorage] instance.
  @protected
  HydratedStorage? get activeStorage =>
      storageOverride ?? HydratedStorage.storage;

  /// Converts stored JSON representation ([Object?]) back into [StateType].
  ///
  /// Accepts Maps, Lists, Strings, Numbers, Booleans, or null. Return `null` to
  /// fall back to initial state.
  StateType? fromJson(dynamic json);

  /// Converts current [state] into a JSON-encodable representation ([Object?]).
  ///
  /// Can return a Map, List, String, number, boolean, or null. Returning `null`
  /// will delete the key from storage.
  dynamic toJson(StateType state);

  /// Initializes hydration by loading stored state during constructor execution.
  @protected
  StateType initHydratedState(StateType initial) {
    final storage = activeStorage;
    if (storage == null) return initial;
    try {
      final json = storage.read(storageToken);
      if (json != null) {
        final restored = fromJson(json);
        if (restored != null) return restored;
      }
    } on Object catch (error, stackTrace) {
      onError(error, stackTrace);
    }
    return initial;
  }

  /// Persists [state] to [activeStorage].
  @protected
  void persist(StateType state) {
    final storage = activeStorage;
    if (storage == null) return;
    try {
      final json = toJson(state);
      if (json != null) {
        unawaited(Future.value(storage.write(storageToken, json)));
      } else {
        unawaited(Future.value(storage.delete(storageToken)));
      }
    } on Object catch (error, stackTrace) {
      onError(error, stackTrace);
    }
  }

  /// Deletes stored state from storage and resets container state to [initialState].
  Future<void> clear() async {
    final storage = activeStorage;
    if (storage != null) {
      await storage.delete(storageToken);
    }
    super.emit(initialState);
  }
}

/// A reactive [CubitSignal] container that automatically persists and restores
/// state across app restarts or container instantiation.
abstract class HydratedCubitSignal<StateType> extends CubitSignal<StateType>
    with HydratedMixin<StateType> {
  /// Creates a [HydratedCubitSignal] with the specified [initialState].
  HydratedCubitSignal({
    required this.initialState,
    super.equals,
    this.id,
    HydratedStorage? storage,
  })  : _storageOverride = storage,
        super(initialState: initialState) {
    _hydrateState();
  }

  @override
  final StateType initialState;

  @override
  final String? id;

  final HydratedStorage? _storageOverride;

  @override
  HydratedStorage? get storageOverride => _storageOverride;

  void _hydrateState() {
    final restored = initHydratedState(initialState);
    if (restored != initialState) {
      emit(restored);
    }
  }

  @override
  void emit(StateType state) {
    super.emit(state);
    persist(state);
  }
}

/// A reactive [BlocSignal] container that automatically persists and restores
/// state across app restarts or container instantiation.
abstract class HydratedBlocSignal<Event, StateType>
    extends BlocSignal<Event, StateType> with HydratedMixin<StateType> {
  /// Creates a [HydratedBlocSignal] with the specified [initialState].
  HydratedBlocSignal({
    required this.initialState,
    super.equals,
    this.id,
    HydratedStorage? storage,
  })  : _storageOverride = storage,
        super(initialState: initialState) {
    _hydrateState();
  }

  @override
  final StateType initialState;

  @override
  final String? id;

  final HydratedStorage? _storageOverride;

  @override
  HydratedStorage? get storageOverride => _storageOverride;

  void _hydrateState() {
    final restored = initHydratedState(initialState);
    if (restored != initialState) {
      emit(restored);
    }
  }

  @override
  void emit(StateType state) {
    super.emit(state);
    persist(state);
  }
}
