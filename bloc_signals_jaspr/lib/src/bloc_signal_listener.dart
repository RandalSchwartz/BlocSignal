import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_jaspr/src/bloc_signal_provider.dart';
import 'package:jaspr/jaspr.dart';
import 'package:signals_core/signals_core.dart';

/// An interface for [BlocSignalListener] components that can be merged by
/// `MultiBlocSignalListener` into a single linear component hierarchy.
///
/// Example:
/// ```dart
/// final List<BlocSignalListenerSingleChildComponent> listeners = [
///   BlocSignalListener<AuthBloc, AuthState>(
///     listener: (context, state) {},
///   ),
///   BlocSignalListener<ThemeBloc, ThemeState>(
///     listener: (context, state) {},
///   ),
/// ];
/// ```
abstract class BlocSignalListenerSingleChildComponent implements Component {
  /// Clones this listener component with a new [child] component.
  Component copyWith(Component child);
}

/// Alias for [BlocSignalListenerSingleChildComponent] for API symmetry with
/// `package:bloc_signals_flutter`.
///
/// Example:
/// ```dart
/// final List<BlocSignalListenerSingleChildWidget> listeners = [
///   BlocSignalListener<AuthBloc, AuthState>(
///     listener: (context, state) {},
///   ),
///   BlocSignalListener<ThemeBloc, ThemeState>(
///     listener: (context, state) {},
///   ),
/// ];
/// ```
typedef BlocSignalListenerSingleChildWidget
    = BlocSignalListenerSingleChildComponent;

/// A Jaspr component that listens to a [BlocSignal] and runs a callback
/// when its state updates.
///
/// Example:
/// ```dart
/// BlocSignalListener<AuthBloc, AuthState>(
///   listener: (context, state) {
///     if (state is Authenticated) {
///       // Perform side effect
///     }
///   },
///   child: const LoginForm(),
/// )
/// ```
class BlocSignalListener<T extends BlocSignalBase<S>, S>
    extends StatefulComponent
    implements BlocSignalListenerSingleChildComponent {
  /// Creates a [BlocSignalListener] component.
  const BlocSignalListener({
    required void Function(BuildContext context, S state) listener,
    this.child = const Component.empty(),
    this.bloc,
    this.listenWhen,
    super.key,
  })  : _listener = listener,
        _transitionListener = null;

  /// Creates a [BlocSignalListener] whose [listener] receives both the
  /// `previous` and `current` state on each transition.
  ///
  /// Example:
  /// ```dart
  /// BlocSignalListener<CounterBloc, int>.transition(
  ///   listener: (context, previous, current) {
  ///     // Perform side effect with previous and current
  ///   },
  ///   child: const CounterView(),
  /// )
  /// ```
  const BlocSignalListener.transition({
    required void Function(BuildContext context, S previous, S current)
        listener,
    this.child = const Component.empty(),
    this.bloc,
    this.listenWhen,
    super.key,
  })  : _listener = null,
        _transitionListener = listener;

  /// The bloc to listen to. If null, it is looked up from the component tree.
  final T? bloc;

  final void Function(BuildContext context, S state)? _listener;

  final void Function(BuildContext context, S previous, S current)?
      _transitionListener;

  /// The callback that runs whenever the state changes.
  void Function(BuildContext context, S state) get listener =>
      _listener ??
      (context, state) => _transitionListener!(context, state, state);

  /// A function that determines whether the [listener] should be called.
  ///
  /// Defaults to null, in which case the listener will be called on every
  /// change.
  final bool Function(S previous, S current)? listenWhen;

  /// The child component subtree.
  final Component child;

  /// Clones this listener with a new child component.
  @override
  BlocSignalListener<T, S> copyWith(Component child) {
    if (_transitionListener != null) {
      return BlocSignalListener<T, S>.transition(
        key: key,
        bloc: bloc,
        listener: _transitionListener,
        listenWhen: listenWhen,
        child: child,
      );
    }
    return BlocSignalListener<T, S>(
      key: key,
      bloc: bloc,
      listener: _listener!,
      listenWhen: listenWhen,
      child: child,
    );
  }

  @override
  State<BlocSignalListener<T, S>> createState() =>
      _BlocSignalListenerState<T, S>();
}

class _BlocSignalListenerState<T extends BlocSignalBase<S>, S>
    extends State<BlocSignalListener<T, S>> {
  T? _bloc;
  S? _previousState;
  void Function()? _cleanup;

  void _subscribe() {
    _cleanup?.call();
    _previousState = _bloc!.state.value;
    var isInitial = true;

    _cleanup = effect(
      () {
        final currentState = _bloc!.state.value;
        if (isInitial) {
          isInitial = false;
          return;
        }
        if (!mounted) return;
        final previous = _previousState as S;

        if (!_bloc!.equals(previous, currentState)) {
          _previousState = currentState;

          if (component.listenWhen == null ||
              component.listenWhen!(previous, currentState)) {
            final transitionListener = component._transitionListener;
            if (transitionListener != null) {
              transitionListener(context, previous, currentState);
            } else {
              component._listener!(context, currentState);
            }
          }
        }
      },
      options: EffectOptions(name: 'BlocSignalListener<$T, $S>.effect'),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final effectiveBloc =
        component.bloc ?? BlocSignalProvider.of<T>(context, listen: true);
    if (!identical(_bloc, effectiveBloc)) {
      _bloc = effectiveBloc;
      _subscribe();
    }
  }

  @override
  void didUpdateComponent(BlocSignalListener<T, S> oldComponent) {
    super.didUpdateComponent(oldComponent);
    final effectiveBloc =
        component.bloc ?? BlocSignalProvider.of<T>(context, listen: true);
    if (!identical(_bloc, effectiveBloc)) {
      _bloc = effectiveBloc;
      _subscribe();
    }
  }

  @override
  void dispose() {
    _cleanup?.call();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    return component.child;
  }
}
