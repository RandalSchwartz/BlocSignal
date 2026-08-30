import 'dart:async';

import 'package:bloc_signals/src/bloc_signals_base.dart';
import 'package:meta/meta.dart';
import 'package:preact_signals/preact_signals.dart' show SignalEquality;
import 'package:signals_core/signals_core.dart';

/// A mixin providing reactive state container capabilities for any Dart class.
///
/// Mixing [CubitSignalMixin] allows an existing class to implement
/// [BlocSignalBase] and gain reactive signals, synchronous state emissions,
/// automatic de-duplication, and lifecycle observation without occupying its
/// single `extends` inheritance slot.
///
/// ```dart
/// class UserProfileRepository extends BaseRepository
///     with CubitSignalMixin<UserProfileState> {
///   UserProfileRepository() {
///     initCubitSignal(initialState: const UserProfileInitial());
///   }
///
///   Future<void> fetchProfile(String id) async {
///     emit(const UserProfileLoading());
///     final user = await api.getUser(id);
///     emit(UserProfileLoaded(user));
///   }
/// }
/// ```
mixin CubitSignalMixin<StateType> implements BlocSignalBase<StateType> {
  bool _isInitialized = false;
  bool _isClosed = false;

  /// Whether [initCubitSignal] has been called on this instance.
  bool get isInitialized => _isInitialized;

  @override
  bool get isClosed => _isClosed;

  late final Signal<StateType> _state;
  late final SignalModel<void> _lifecycleModel;
  final List<void Function()> _effectsToDispose = [];

  bool Function(StateType previous, StateType current)? _customEquals;
  SignalEquality<StateType>? _optionsEquality;

  final Object _zoneEventKey = Object();

  @override
  @protected
  Object get zoneEventKey => _zoneEventKey;

  /// Initializes the state signal and lifecycle hooks for this container.
  ///
  /// Must be called in the constructor of the class that mixes in
  /// [CubitSignalMixin]. Accepts the required [initialState], an optional
  /// [equals] comparator callback, and optional [options] configuration.
  ///
  /// Throws a [StateError] if called more than once.
  ///
  /// ```dart
  /// class CounterController extends BaseController
  ///     with CubitSignalMixin<int> {
  ///   CounterController() {
  ///     initCubitSignal(initialState: 0);
  ///   }
  /// }
  /// ```
  @protected
  @mustCallSuper
  void initCubitSignal({
    required StateType initialState,
    bool Function(StateType previous, StateType current)? equals,
    SignalOptions<StateType>? options,
  }) {
    if (_isInitialized) {
      throw StateError('initCubitSignal was already called on $runtimeType.');
    }
    _isInitialized = true;
    _customEquals = equals;
    _optionsEquality = options?.equalityCheck;

    final debugName = options?.name ?? '$runtimeType.state';
    _state = signal<StateType>(
      initialState,
      options: SignalOptions<StateType>(
        name: debugName,
        autoDispose: options?.autoDispose ?? false,
        watched: options?.watched,
        unwatched: options?.unwatched,
        equality: options?.equalityCheck ??
            SignalEquality<StateType>.custom(
              (a, b) => this.equals(a, b),
            ),
      ),
    );

    final modelConstructor = createModel(() {
      effect(
        () {
          _onStateChangedInternal(_state.value);
        },
        options: EffectOptions(name: '$runtimeType.lifecycleEffect'),
      );
      return null;
    });
    _lifecycleModel = modelConstructor();
    BlocSignalObserver.observer?.onCreate(this);
  }

  @override
  ReadonlySignal<StateType> get state {
    assert(
      _isInitialized,
      'initCubitSignal() must be called in the constructor of $runtimeType '
      'before accessing state.',
    );
    return _state;
  }

  @override
  StateType get stateValue {
    assert(
      _isInitialized,
      'initCubitSignal() must be called in the constructor of $runtimeType '
      'before accessing stateValue.',
    );
    return _state.value;
  }

  @override
  @protected
  bool equals(StateType previous, StateType current) {
    final optEquality = _optionsEquality;
    if (optEquality != null) {
      return optEquality.equals(previous, current);
    }
    final custom = _customEquals;
    if (custom != null) {
      return custom(previous, current);
    }
    return previous == current;
  }

  @override
  @protected
  @visibleForTesting
  void emit(StateType newState) {
    assert(
      _isInitialized,
      'initCubitSignal() must be called in the constructor of $runtimeType '
      'before calling emit().',
    );
    assert(
      !_isClosed,
      'Cannot emit new states after calling close() on $runtimeType.',
    );
    if (_isClosed || !_isInitialized) return;
    final oldState = _state.peek();
    if (equals(oldState, newState)) return;

    final event = Zone.current[zoneEventKey];
    if (event != null) {
      handleTransition(event as Object, oldState, newState);
    } else {
      BlocSignalObserver.observer?.onTransition(this, null, newState);
    }

    _state.value = newState;

    final change = Change<StateType>(
      currentState: oldState,
      nextState: newState,
    );
    onChange(change);
  }

  @override
  @protected
  void handleTransition(Object event, StateType oldState, StateType newState) {}

  @override
  @protected
  @mustCallSuper
  void onChange(Change<StateType> change) {
    BlocSignalObserver.observer?.onChange(this, change);
  }

  @override
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

  @override
  @protected
  void Function() createEffect(
    void Function() callback, {
    EffectOptions? options,
    void Function()? onDispose,
  }) {
    final debugName =
        options?.name ?? '$runtimeType.effect#${_effectsToDispose.length + 1}';
    final dispose = effect(
      callback,
      options: EffectOptions(
        name: debugName,
        onDispose: onDispose ?? options?.onDispose,
      ),
    );
    _effectsToDispose.add(dispose);
    return dispose;
  }

  @override
  @mustCallSuper
  Future<void> close() async {
    if (_isClosed) return;
    _isClosed = true;
    for (final dispose in _effectsToDispose) {
      dispose();
    }
    _effectsToDispose.clear();
    if (_isInitialized) {
      _lifecycleModel.dispose();
    }
    BlocSignalObserver.observer?.onClose(this);
  }

  @override
  String toString() => '$runtimeType($stateValue)';
}
