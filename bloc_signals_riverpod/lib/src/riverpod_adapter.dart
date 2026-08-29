import 'package:bloc_signals/bloc_signals.dart';
// `ProviderListenable` is exported via Riverpod's internal library entrypoint
// (`package:riverpod/src/internals.dart`) for third-party adapter authors.
// ignore: implementation_imports
import 'package:riverpod/src/internals.dart'
    hide AsyncData, AsyncError, AsyncLoading;
import 'package:signals_core/signals_core.dart';

/// A reactive state container wrapper that adapts an underlying Riverpod
/// [ProviderListenable] into a [BlocSignalBase].
class RiverpodBlocSignal<T> extends CubitSignal<T> {
  /// Creates a [RiverpodBlocSignal] wrapping a Riverpod [listenable] using a
  /// [container].
  RiverpodBlocSignal(
    ProviderContainer container,
    ProviderListenable<T> listenable, {
    super.equals,
    super.options,
  }) : super(initialState: container.read(listenable)) {
    _subscription = container.listen<T>(
      listenable,
      (previous, next) => emit(next),
    );
  }

  /// Creates a [RiverpodBlocSignal] using a Riverpod [Ref].
  ///
  /// Automatically registers `ref.onDispose` to close this [RiverpodBlocSignal]
  /// when the [ref]'s scope is disposed.
  factory RiverpodBlocSignal.fromRef(
    Ref ref,
    ProviderListenable<T> listenable, {
    bool Function(T previous, T current)? equals,
    SignalOptions<T>? options,
  }) {
    final bloc = RiverpodBlocSignal<T>(
      ref.container,
      listenable,
      equals: equals,
      options: options,
    );
    ref.onDispose(bloc.close);
    return bloc;
  }

  late final ProviderSubscription<T> _subscription;

  @override
  Future<void> close() async {
    _subscription.close();
    await super.close();
  }
}

/// A [RiverpodBlocSignal] that provides typed access to the underlying
/// Riverpod [notifier].
///
/// ```dart
/// final counterCubit = counterProvider.toBlocSignal(ref);
/// print(counterCubit.stateValue); // 0
/// counterCubit.notifier.increment();
/// ```
class RiverpodNotifierBlocSignal<NotifierT, T> extends RiverpodBlocSignal<T> {
  /// Creates a [RiverpodNotifierBlocSignal] wrapping a Riverpod provider with
  /// its [notifier] and [container].
  RiverpodNotifierBlocSignal(
    this.notifier,
    super.container,
    super.listenable, {
    super.equals,
    super.options,
  });

  /// Creates a [RiverpodNotifierBlocSignal] using a Riverpod [Ref].
  ///
  /// Automatically registers `ref.onDispose` to close this
  /// [RiverpodNotifierBlocSignal] when the [ref]'s scope is disposed.
  factory RiverpodNotifierBlocSignal.fromRef(
    NotifierT notifier,
    Ref ref,
    ProviderListenable<T> listenable, {
    bool Function(T previous, T current)? equals,
    SignalOptions<T>? options,
  }) {
    final bloc = RiverpodNotifierBlocSignal<NotifierT, T>(
      notifier,
      ref.container,
      listenable,
      equals: equals,
      options: options,
    );
    ref.onDispose(bloc.close);
    return bloc;
  }

  /// The underlying Riverpod notifier for dispatching mutations and actions.
  final NotifierT notifier;
}

ProviderContainer _resolveContainer(Object refOrContainer) {
  if (refOrContainer is Ref) {
    return refOrContainer.container;
  } else if (refOrContainer is ProviderContainer) {
    return refOrContainer;
  } else {
    try {
      final dynamic obj = refOrContainer;
      // Duck-typing support for flutter_riverpod WidgetRef container.
      // ignore: avoid_dynamic_calls
      return obj.container as ProviderContainer;
    } on Object catch (_) {
      throw ArgumentError(
        'refOrContainer must be a Ref, WidgetRef, or ProviderContainer, '
        'but was ${refOrContainer.runtimeType}.',
      );
    }
  }
}

void _bindDispose(Object refOrContainer, void Function() dispose) {
  if (refOrContainer is Ref) {
    refOrContainer.onDispose(dispose);
  } else if (refOrContainer is! ProviderContainer) {
    try {
      final dynamic obj = refOrContainer;
      // Duck-typing support for flutter_riverpod WidgetRef onDispose.
      // ignore: avoid_dynamic_calls
      obj.onDispose(dispose);
    } on Object catch (_) {}
  }
}

/// Extension methods on [NotifierProvider] for typed notifier access.
extension NotifierProviderBlocSignalX<NotifierT extends Notifier<T>, T>
    on NotifierProvider<NotifierT, T> {
  /// Adapts this [NotifierProvider] into a [RiverpodNotifierBlocSignal]
  /// providing both reactive signal state consumption and typed access to
  /// [notifier].
  RiverpodNotifierBlocSignal<NotifierT, T> toBlocSignal(
    Object refOrContainer, {
    bool Function(T previous, T current)? equals,
    SignalOptions<T>? options,
  }) {
    final container = _resolveContainer(refOrContainer);
    final notifier = container.read(this.notifier);
    final bloc = RiverpodNotifierBlocSignal<NotifierT, T>(
      notifier,
      container,
      this,
      equals: equals,
      options: options,
    );
    _bindDispose(refOrContainer, bloc.close);
    return bloc;
  }
}

/// Extension methods on [AsyncNotifierProvider] for typed notifier access.
extension AsyncNotifierProviderBlocSignalX<NotifierT extends AsyncNotifier<T>,
    T> on AsyncNotifierProvider<NotifierT, T> {
  /// Adapts this [AsyncNotifierProvider] into a [RiverpodNotifierBlocSignal]
  /// providing both reactive signal state consumption and typed access to
  /// [notifier].
  RiverpodNotifierBlocSignal<NotifierT, AsyncValue<T>> toBlocSignal(
    Object refOrContainer, {
    bool Function(AsyncValue<T> previous, AsyncValue<T> current)? equals,
    SignalOptions<AsyncValue<T>>? options,
  }) {
    final container = _resolveContainer(refOrContainer);
    final notifier = container.read(this.notifier);
    final bloc = RiverpodNotifierBlocSignal<NotifierT, AsyncValue<T>>(
      notifier,
      container,
      this,
      equals: equals,
      options: options,
    );
    _bindDispose(refOrContainer, bloc.close);
    return bloc;
  }
}

/// Extension methods on [StateNotifierProvider] for typed notifier access.
extension StateNotifierProviderBlocSignalX<NotifierT extends StateNotifier<T>,
    T> on StateNotifierProvider<NotifierT, T> {
  /// Adapts this [StateNotifierProvider] into a [RiverpodNotifierBlocSignal]
  /// providing both reactive signal state consumption and typed access to
  /// [notifier].
  RiverpodNotifierBlocSignal<NotifierT, T> toBlocSignal(
    Object refOrContainer, {
    bool Function(T previous, T current)? equals,
    SignalOptions<T>? options,
  }) {
    final container = _resolveContainer(refOrContainer);
    final notifier = container.read(this.notifier);
    final bloc = RiverpodNotifierBlocSignal<NotifierT, T>(
      notifier,
      container,
      this,
      equals: equals,
      options: options,
    );
    _bindDispose(refOrContainer, bloc.close);
    return bloc;
  }
}

/// Extension methods on [StateProvider] for typed notifier access.
extension StateProviderBlocSignalX<T> on StateProvider<T> {
  /// Adapts this [StateProvider] into a [RiverpodNotifierBlocSignal]
  /// providing both reactive signal state consumption and typed access to
  /// [StateController].
  RiverpodNotifierBlocSignal<StateController<T>, T> toBlocSignal(
    Object refOrContainer, {
    bool Function(T previous, T current)? equals,
    SignalOptions<T>? options,
  }) {
    final container = _resolveContainer(refOrContainer);
    final notifier = container.read(this.notifier);
    final bloc = RiverpodNotifierBlocSignal<StateController<T>, T>(
      notifier,
      container,
      this,
      equals: equals,
      options: options,
    );
    _bindDispose(refOrContainer, bloc.close);
    return bloc;
  }
}

/// Extension methods on [StreamNotifierProvider] for typed notifier access.
extension StreamNotifierProviderBlocSignalX<NotifierT extends StreamNotifier<T>,
    T> on StreamNotifierProvider<NotifierT, T> {
  /// Adapts this [StreamNotifierProvider] into a [RiverpodNotifierBlocSignal]
  /// providing both reactive signal state consumption and typed access to
  /// [notifier].
  RiverpodNotifierBlocSignal<NotifierT, AsyncValue<T>> toBlocSignal(
    Object refOrContainer, {
    bool Function(AsyncValue<T> previous, AsyncValue<T> current)? equals,
    SignalOptions<AsyncValue<T>>? options,
  }) {
    final container = _resolveContainer(refOrContainer);
    final notifier = container.read(this.notifier);
    final bloc = RiverpodNotifierBlocSignal<NotifierT, AsyncValue<T>>(
      notifier,
      container,
      this,
      equals: equals,
      options: options,
    );
    _bindDispose(refOrContainer, bloc.close);
    return bloc;
  }
}

/// Extension methods on [ProviderListenable] for [BlocSignalBase] conversion.
extension ProviderListenableBlocSignalX<T> on ProviderListenable<T> {
  /// Adapts this Riverpod [ProviderListenable] into a [BlocSignalBase]
  /// container.
  ///
  /// The [refOrContainer] parameter must be either a [Ref], `WidgetRef`, or a
  /// [ProviderContainer]. If a [Ref] or object exposing `onDispose` is
  /// provided, `onDispose` is automatically registered to close the container
  /// when the provider/widget is disposed.
  BlocSignalBase<T> toBlocSignal(
    Object refOrContainer, {
    bool Function(T previous, T current)? equals,
    SignalOptions<T>? options,
  }) {
    if (refOrContainer is Ref) {
      return RiverpodBlocSignal<T>.fromRef(
        refOrContainer,
        this,
        equals: equals,
        options: options,
      );
    } else if (refOrContainer is ProviderContainer) {
      return RiverpodBlocSignal<T>(
        refOrContainer,
        this,
        equals: equals,
        options: options,
      );
    } else {
      try {
        final dynamic obj = refOrContainer;
        // Duck-typing support for flutter_riverpod WidgetRef container.
        // ignore: avoid_dynamic_calls
        final container = obj.container as ProviderContainer;
        final bloc = RiverpodBlocSignal<T>(
          container,
          this,
          equals: equals,
          options: options,
        );
        try {
          // Duck-typing support for flutter_riverpod WidgetRef onDispose.
          // ignore: avoid_dynamic_calls
          obj.onDispose(bloc.close);
        } on Object catch (_) {}
        return bloc;
      } on Object catch (_) {
        throw ArgumentError(
          'refOrContainer must be a Ref, WidgetRef, or ProviderContainer, '
          'but was ${refOrContainer.runtimeType}.',
        );
      }
    }
  }
}

/// A Riverpod [Notifier] that wraps an underlying [BlocSignalBase] and exposes
/// it via [bloc] (and [cubit]).
class BlocSignalNotifier<B extends BlocSignalBase<T>, T> extends Notifier<T> {
  /// Creates a [BlocSignalNotifier] wrapping [bloc].
  BlocSignalNotifier(this.bloc);

  /// The underlying [BlocSignalBase] instance.
  final B bloc;

  /// Alias for [bloc] when wrapping a cubit container.
  B get cubit => bloc;

  @override
  T build() {
    final unsubscribe = bloc.state.subscribe((newValue) {
      state = newValue;
    });
    ref.onDispose(unsubscribe);
    return bloc.state.value;
  }
}

/// Extension methods on [BlocSignalBase] for Riverpod provider conversion.
extension BlocSignalRiverpodX<B extends BlocSignalBase<T>, T> on B {
  /// Converts this [BlocSignalBase] into a Riverpod [NotifierProvider].
  ///
  /// Subscribes to `state` updates and automatically unbinds the subscription
  /// when the Riverpod provider is disposed via `ref.onDispose`.
  ///
  /// The resulting provider's notifier exposes typed access to the underlying
  /// [BlocSignalNotifier.bloc] (and [BlocSignalNotifier.cubit]).
  NotifierProvider<BlocSignalNotifier<B, T>, T> toProvider() {
    return NotifierProvider<BlocSignalNotifier<B, T>, T>(
      () => BlocSignalNotifier<B, T>(this),
    );
  }
}

/// Extension methods on Riverpod [AsyncValue] for Signals [AsyncState]
/// conversion.
extension AsyncValueToAsyncStateX<T> on AsyncValue<T> {
  /// Converts this Riverpod [AsyncValue] into a Signals [AsyncState].
  AsyncState<T> toAsyncState() {
    if (hasValue) {
      return AsyncState<T>.data(requireValue);
    } else if (hasError) {
      return AsyncState<T>.error(error!, stackTrace);
    } else {
      return AsyncState<T>.loading();
    }
  }
}

/// Extension methods on Signals [AsyncState] for Riverpod [AsyncValue]
/// conversion.
extension AsyncStateToAsyncValueX<T> on AsyncState<T> {
  /// Converts this Signals [AsyncState] into a Riverpod [AsyncValue].
  AsyncValue<T> toAsyncValue() {
    if (hasValue) {
      return AsyncValue<T>.data(value as T);
    } else if (hasError) {
      return AsyncValue<T>.error(error!, stackTrace ?? StackTrace.empty);
    } else {
      return AsyncValue<T>.loading();
    }
  }
}
