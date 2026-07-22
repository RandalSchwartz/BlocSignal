import 'package:bloc_signals/bloc_signals.dart';
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
    ProviderListenable<T> listenable,
  ) : super(initialState: container.read(listenable)) {
    _subscription = container.listen<T>(
      listenable,
      (previous, next) => emit(next),
    );
  }

  /// Creates a [RiverpodBlocSignal] using a Riverpod [Ref].
  ///
  /// Automatically registers [ref.onDispose] to close this [RiverpodBlocSignal]
  /// when the [ref]'s scope is disposed.
  factory RiverpodBlocSignal.fromRef(
    Ref ref,
    ProviderListenable<T> listenable,
  ) {
    final bloc = RiverpodBlocSignal<T>(ref.container, listenable);
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

/// Extension methods on [ProviderListenable] for [BlocSignalBase] conversion.
extension ProviderListenableBlocSignalX<T> on ProviderListenable<T> {
  /// Adapts this Riverpod [ProviderListenable] into a [BlocSignalBase] container.
  ///
  /// The [refOrContainer] parameter must be either a [Ref], WidgetRef, or a
  /// [ProviderContainer]. If a [Ref] or object exposing `onDispose` is provided,
  /// `onDispose` is automatically registered to close the container when the
  /// provider/widget is disposed.
  BlocSignalBase<T> toBlocSignal(Object refOrContainer) {
    if (refOrContainer is Ref) {
      return RiverpodBlocSignal<T>.fromRef(refOrContainer, this);
    } else if (refOrContainer is ProviderContainer) {
      return RiverpodBlocSignal<T>(refOrContainer, this);
    } else {
      try {
        final dynamic obj = refOrContainer;
        final container = obj.container as ProviderContainer;
        final bloc = RiverpodBlocSignal<T>(container, this);
        try {
          obj.onDispose(bloc.close);
        } catch (_) {}
        return bloc;
      } catch (_) {
        throw ArgumentError(
          'refOrContainer must be a Ref, WidgetRef, or ProviderContainer, but was '
          '${refOrContainer.runtimeType}.',
        );
      }
    }
  }
}

class _BlocSignalNotifier<T> extends Notifier<T> {
  _BlocSignalNotifier(this.bloc);
  final BlocSignalBase<T> bloc;

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
extension BlocSignalRiverpodX<T> on BlocSignalBase<T> {
  /// Converts this [BlocSignalBase] into a Riverpod [NotifierProvider].
  ///
  /// Subscribes to [state] updates and automatically unbinds the subscription
  /// when the Riverpod provider is disposed via [ref.onDispose].
  NotifierProvider<Notifier<T>, T> toProvider() {
    return NotifierProvider<Notifier<T>, T>(
      () => _BlocSignalNotifier<T>(this),
    );
  }
}

/// Extension methods on Riverpod [AsyncValue] for Signals [AsyncState] conversion.
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

/// Extension methods on Signals [AsyncState] for Riverpod [AsyncValue] conversion.
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
