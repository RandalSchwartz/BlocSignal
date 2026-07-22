import 'package:bloc_signals/bloc_signals.dart';
import 'package:riverpod/src/internals.dart';

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
  /// The [refOrContainer] parameter must be either a [Ref] or a
  /// [ProviderContainer]. If a [Ref] is provided, [ref.onDispose] is
  /// automatically registered to close the container when the provider is
  /// disposed.
  BlocSignalBase<T> toBlocSignal(Object refOrContainer) {
    if (refOrContainer is Ref) {
      return RiverpodBlocSignal<T>.fromRef(refOrContainer, this);
    } else if (refOrContainer is ProviderContainer) {
      return RiverpodBlocSignal<T>(refOrContainer, this);
    } else {
      throw ArgumentError(
        'refOrContainer must be a Ref or ProviderContainer, but was '
        '${refOrContainer.runtimeType}.',
      );
    }
  }
}

/// Extension methods on [BlocSignalBase] for Riverpod provider conversion.
extension BlocSignalRiverpodX<T> on BlocSignalBase<T> {
  /// Converts this [BlocSignalBase] into a Riverpod [Provider].
  ///
  /// Subscribes to [state] updates and automatically unbinds the subscription
  /// when the Riverpod provider is disposed via [ref.onDispose].
  Provider<T> toProvider() {
    return Provider<T>((ref) {
      final unsubscribe = state.subscribe((_) {
        ref.invalidateSelf();
      });
      ref.onDispose(unsubscribe);
      return state.value;
    });
  }
}
