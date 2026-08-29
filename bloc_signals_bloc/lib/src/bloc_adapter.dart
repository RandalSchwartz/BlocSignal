import 'dart:async';

import 'package:bloc/bloc.dart' as bloc_lib;
import 'package:bloc_signals/bloc_signals.dart';
import 'package:signals_core/signals_core.dart';

/// A reactive state container wrapper that adapts an underlying classic
/// [bloc_lib.Bloc] from `package:bloc` into a [BlocSignal].
///
/// Dispatches incoming events directly to the wrapped [bloc] instance and
/// propagates state emissions synchronously through reactive signals.
///
/// Example:
/// ```dart
/// final classicBloc = CounterBloc();
/// final blocSignal = ClassicBlocSignal(classicBloc);
///
/// // Reactive read:
/// print(blocSignal.stateValue);
///
/// // Bidirectional event dispatch:
/// blocSignal.add(IncrementEvent());
/// ```
class ClassicBlocSignal<Event, State> extends BlocSignal<Event, State> {
  /// Creates a [ClassicBlocSignal] wrapping a classic [bloc] instance.
  ///
  /// If [autoClose] is `true`, calling [close] on this adapter will also
  /// close the underlying [bloc]. Defaults to `false`.
  ClassicBlocSignal(
    this.bloc, {
    this.autoClose = false,
    super.equals,
    super.options,
  }) : super(initialState: bloc.state) {
    _subscription = bloc.stream.listen(
      emit,
      onError: (Object error, StackTrace stackTrace) {
        onError(error, stackTrace);
      },
      onDone: () {
        if (!isClosed) {
          unawaited(close());
        }
      },
    );
  }

  /// The underlying classic [bloc_lib.Bloc] instance.
  final bloc_lib.Bloc<Event, State> bloc;

  /// Whether closing this adapter automatically closes the underlying [bloc].
  final bool autoClose;

  late final StreamSubscription<State> _subscription;

  @override
  void add(Event event) {
    if (isClosed) return;
    BlocSignalObserver.observer?.onEvent(this, event);
    bloc.add(event);
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    if (autoClose) {
      await bloc.close();
    }
    await super.close();
  }
}

/// A reactive state container wrapper that adapts an underlying classic
/// [bloc_lib.Cubit] from `package:bloc` into a [CubitSignal].
///
/// Provides typed access to the underlying [cubit] for method-driven
/// mutations and exposes state emissions synchronously as signals.
///
/// Example:
/// ```dart
/// final classicCubit = CounterCubit();
/// final cubitSignal = ClassicCubitSignal(classicCubit);
///
/// // Reactive read:
/// print(cubitSignal.stateValue);
///
/// // Typed method invocation:
/// cubitSignal.cubit.increment();
/// ```
class ClassicCubitSignal<C extends bloc_lib.Cubit<State>, State>
    extends CubitSignal<State> {
  /// Creates a [ClassicCubitSignal] wrapping a classic [cubit] instance.
  ///
  /// If [autoClose] is `true`, calling [close] on this adapter will also
  /// close the underlying [cubit]. Defaults to `false`.
  ClassicCubitSignal(
    this.cubit, {
    this.autoClose = false,
    super.equals,
    super.options,
  }) : super(initialState: cubit.state) {
    _subscription = cubit.stream.listen(
      emit,
      onError: (Object error, StackTrace stackTrace) {
        onError(error, stackTrace);
      },
      onDone: () {
        if (!isClosed) {
          unawaited(close());
        }
      },
    );
  }

  /// The underlying classic [bloc_lib.Cubit] instance.
  final C cubit;

  /// Whether closing this adapter automatically closes the underlying [cubit].
  final bool autoClose;

  late final StreamSubscription<State> _subscription;

  @override
  Future<void> close() async {
    await _subscription.cancel();
    if (autoClose) {
      await cubit.close();
    }
    await super.close();
  }
}

/// A classic [bloc_lib.Bloc] adapter that wraps a modern [BlocSignal]
/// state container for backwards compatibility with legacy `flutter_bloc`
/// widgets such as `BlocBuilder` and `BlocListener`.
///
/// Example:
/// ```dart
/// final modernBloc = ModernCounterBloc();
/// final classicAdapter = BlocSignalToClassicBloc(modernBloc);
///
/// // Consumed by legacy flutter_bloc widgets:
/// BlocBuilder<BlocSignalToClassicBloc<CounterEvent, int>, int>(
///   bloc: classicAdapter,
///   builder: (context, state) => Text('$state'),
/// );
/// ```
class BlocSignalToClassicBloc<Event, State>
    extends bloc_lib.Bloc<Event, State> {
  /// Creates a [BlocSignalToClassicBloc] adapter wrapping [blocSignal].
  ///
  /// If [autoClose] is `true`, closing this classic bloc will also close
  /// the underlying [blocSignal]. Defaults to `false`.
  BlocSignalToClassicBloc(
    this.blocSignal, {
    this.autoClose = false,
  }) : super(blocSignal.stateValue) {
    _unsubscribe = blocSignal.state.subscribe((newState) {
      if (!isClosed && state != newState) {
        // package:bloc marks emit with @visibleForTesting in Bloc.
        // ignore: invalid_use_of_visible_for_testing_member
        emit(newState);
      }
    });
    on<Event>((event, emit) {
      blocSignal.add(event);
    });
  }

  /// The underlying modern [BlocSignal] instance.
  final BlocSignal<Event, State> blocSignal;

  /// Whether closing this classic bloc also closes the underlying [blocSignal].
  final bool autoClose;

  late final void Function() _unsubscribe;

  @override
  Future<void> close() async {
    _unsubscribe();
    if (autoClose) {
      await blocSignal.close();
    }
    await super.close();
  }
}

/// A classic [bloc_lib.Cubit] adapter that wraps a modern [BlocSignalBase]
/// or [CubitSignal] state container for backwards compatibility with legacy
/// `flutter_bloc` widgets such as `BlocBuilder` and `BlocListener`.
///
/// Example:
/// ```dart
/// final modernCubit = ModernCounterCubit();
/// final classicCubit = BlocSignalToClassicCubit(modernCubit);
///
/// // Consumed by legacy flutter_bloc widgets:
/// BlocBuilder<BlocSignalToClassicCubit<ModernCounterCubit, int>, int>(
///   bloc: classicCubit,
///   builder: (context, state) => Text('$state'),
/// );
/// ```
class BlocSignalToClassicCubit<B extends BlocSignalBase<State>, State>
    extends bloc_lib.Cubit<State> {
  /// Creates a [BlocSignalToClassicCubit] adapter wrapping [blocSignal].
  ///
  /// If [autoClose] is `true`, closing this classic cubit will also close
  /// the underlying [blocSignal]. Defaults to `false`.
  BlocSignalToClassicCubit(
    this.blocSignal, {
    this.autoClose = false,
  }) : super(blocSignal.stateValue) {
    _unsubscribe = blocSignal.state.subscribe((newState) {
      if (!isClosed && state != newState) {
        emit(newState);
      }
    });
  }

  /// The underlying modern [BlocSignalBase] instance.
  final B blocSignal;

  /// Alias for [blocSignal] when wrapping a cubit container.
  B get cubit => blocSignal;

  /// Whether closing this classic cubit also closes the underlying
  /// [blocSignal].
  final bool autoClose;

  late final void Function() _unsubscribe;

  @override
  Future<void> close() async {
    _unsubscribe();
    if (autoClose) {
      await blocSignal.close();
    }
    await super.close();
  }
}

/// Extension methods on classic [bloc_lib.Bloc] for [BlocSignal] conversion.
extension ClassicBlocToBlocSignalX<Event, State>
    on bloc_lib.Bloc<Event, State> {
  /// Adapts this classic [bloc_lib.Bloc] into a [ClassicBlocSignal] container
  /// providing synchronous reactive signal reading and bidirectional event
  /// dispatching.
  ///
  /// Example:
  /// ```dart
  /// final blocSignal = classicBloc.toBlocSignal();
  /// blocSignal.add(IncrementEvent());
  /// ```
  ClassicBlocSignal<Event, State> toBlocSignal({
    bool autoClose = false,
    bool Function(State previous, State current)? equals,
    SignalOptions<State>? options,
  }) {
    return ClassicBlocSignal<Event, State>(
      this,
      autoClose: autoClose,
      equals: equals,
      options: options,
    );
  }
}

/// Extension methods on classic [bloc_lib.Cubit] for [CubitSignal] conversion.
extension ClassicCubitToBlocSignalX<C extends bloc_lib.Cubit<State>, State>
    on C {
  /// Adapts this classic [bloc_lib.Cubit] into a [ClassicCubitSignal] container
  /// providing synchronous reactive signal reading and typed access to the
  /// underlying classic cubit via [ClassicCubitSignal.cubit].
  ///
  /// Example:
  /// ```dart
  /// final cubitSignal = classicCubit.toBlocSignal();
  /// cubitSignal.cubit.increment();
  /// ```
  ClassicCubitSignal<C, State> toBlocSignal({
    bool autoClose = false,
    bool Function(State previous, State current)? equals,
    SignalOptions<State>? options,
  }) {
    return ClassicCubitSignal<C, State>(
      this,
      autoClose: autoClose,
      equals: equals,
      options: options,
    );
  }
}

/// Extension methods on modern [BlocSignal] for classic [bloc_lib.Bloc]
/// conversion.
extension BlocSignalToClassicBlocX<Event, State> on BlocSignal<Event, State> {
  /// Adapts this modern [BlocSignal] into a classic [BlocSignalToClassicBloc]
  /// for consumption by legacy `flutter_bloc` widgets.
  ///
  /// Example:
  /// ```dart
  /// final classicBloc = modernBloc.toClassicBloc();
  /// ```
  BlocSignalToClassicBloc<Event, State> toClassicBloc({
    bool autoClose = false,
  }) {
    return BlocSignalToClassicBloc<Event, State>(
      this,
      autoClose: autoClose,
    );
  }
}

/// Extension methods on modern [CubitSignal] for classic [bloc_lib.Cubit]
/// conversion.
extension CubitSignalToClassicCubitX<State> on CubitSignal<State> {
  /// Adapts this modern [CubitSignal] into a classic
  /// [BlocSignalToClassicCubit] for consumption by legacy `flutter_bloc`
  /// widgets.
  ///
  /// Example:
  /// ```dart
  /// final classicCubit = modernCubit.toClassicCubit();
  /// ```
  BlocSignalToClassicCubit<CubitSignal<State>, State> toClassicCubit({
    bool autoClose = false,
  }) {
    return BlocSignalToClassicCubit<CubitSignal<State>, State>(
      this,
      autoClose: autoClose,
    );
  }

  /// Adapts this modern [CubitSignal] into a classic
  /// [BlocSignalToClassicCubit] for consumption by legacy `flutter_bloc`
  /// widgets.
  ///
  /// Example:
  /// ```dart
  /// final classicBloc = modernCubit.toClassicBloc();
  /// ```
  BlocSignalToClassicCubit<CubitSignal<State>, State> toClassicBloc({
    bool autoClose = false,
  }) {
    return BlocSignalToClassicCubit<CubitSignal<State>, State>(
      this,
      autoClose: autoClose,
    );
  }
}

/// Extension methods on modern [BlocSignalBase] for classic [bloc_lib.Cubit]
/// conversion.
extension BlocSignalBaseToClassicCubitX<State> on BlocSignalBase<State> {
  /// Adapts this modern [BlocSignalBase] into a classic
  /// [BlocSignalToClassicCubit] for consumption by legacy `flutter_bloc`
  /// widgets.
  ///
  /// Example:
  /// ```dart
  /// final classicCubit = modernBase.toClassicCubit();
  /// ```
  BlocSignalToClassicCubit<BlocSignalBase<State>, State> toClassicCubit({
    bool autoClose = false,
  }) {
    return BlocSignalToClassicCubit<BlocSignalBase<State>, State>(
      this,
      autoClose: autoClose,
    );
  }

  /// Adapts this modern [BlocSignalBase] into a classic
  /// [BlocSignalToClassicCubit] for consumption by legacy `flutter_bloc`
  /// widgets.
  ///
  /// Example:
  /// ```dart
  /// final classicBloc = modernBase.toClassicBloc();
  /// ```
  BlocSignalToClassicCubit<BlocSignalBase<State>, State> toClassicBloc({
    bool autoClose = false,
  }) {
    return BlocSignalToClassicCubit<BlocSignalBase<State>, State>(
      this,
      autoClose: autoClose,
    );
  }
}
