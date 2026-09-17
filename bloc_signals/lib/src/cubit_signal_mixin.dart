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

  @override
  @protected
  Object get zoneBlocKey => BlocSignalBase.ambientZoneBlocKey;

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
    try {
      BlocSignalObserver.observer?.onCreate(this);
    } on Object catch (e, stackTrace) {
      onError(e, stackTrace);
    }
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
  StateType get value {
    assert(
      _isInitialized,
      'initCubitSignal() must be called in the constructor of $runtimeType '
      'before accessing value.',
    );
    return _state.value;
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
      try {
        handleTransition(event as Object, oldState, newState);
      } on Object catch (e, stackTrace) {
        onError(e, stackTrace);
      }
    } else {
      try {
        BlocSignalObserver.observer?.onTransition(this, null, newState);
      } on Object catch (e, stackTrace) {
        onError(e, stackTrace);
      }
    }

    _state.value = newState;

    final change = Change<StateType>(
      currentState: oldState,
      nextState: newState,
    );
    try {
      onChange(change);
    } on Object catch (e, stackTrace) {
      onError(e, stackTrace);
    }
  }

  @override
  @protected
  void handleTransition(Object event, StateType oldState, StateType newState) {}

  @override
  @protected
  @mustCallSuper
  void onChange(Change<StateType> change) {
    try {
      BlocSignalObserver.observer?.onChange(this, change);
    } on Object catch (e, stackTrace) {
      onError(e, stackTrace);
    }
  }

  @override
  @protected
  @mustCallSuper
  void onError(Object error, StackTrace stackTrace) {
    final currentObserver = BlocSignalObserver.observer;
    if (currentObserver != null) {
      try {
        currentObserver.onError(this, error, stackTrace);
      } on Object catch (_) {
        // Prevent observer error in onError from causing infinite recursion
      }
    }
  }

  @override
  @protected
  @mustCallSuper
  void emitError(Object error, [StackTrace? stackTrace]) {
    onError(error, stackTrace ?? StackTrace.current);
  }

  @override
  @protected
  @mustCallSuper
  void addError(Object error, [StackTrace? stackTrace]) =>
      emitError(error, stackTrace);

  @override
  @protected
  void emitTelemetry(
    String name, {
    Object? event,
    Map<String, dynamic>? metadata,
  }) {
    if (BlocSignalObserver.observer == null) return;
    onTelemetry(name, event: event, metadata: metadata);
  }

  @override
  @protected
  @mustCallSuper
  void onTelemetry(
    String name, {
    Object? event,
    Map<String, dynamic>? metadata,
  }) {
    try {
      BlocSignalObserver.observer?.onTelemetry(
        this,
        name,
        event: event,
        metadata: metadata,
      );
    } on Object catch (e, stackTrace) {
      onError(e, stackTrace);
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
    try {
      BlocSignalObserver.observer?.onClose(this);
    } on Object catch (e, stackTrace) {
      onError(e, stackTrace);
    }
  }

  @override
  String toString() => '$runtimeType($stateValue)';
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
