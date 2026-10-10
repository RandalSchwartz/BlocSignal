import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_jaspr/src/bloc_signal_provider.dart';
import 'package:jaspr/jaspr.dart';
import 'package:signals_core/signals_core.dart';

class _NullComponent extends StatelessComponent {
  const _NullComponent();

  @override
  Component build(BuildContext context) => const Component.empty();
}

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
    required this.listener,
    this.child = const _NullComponent(),
    this.bloc,
    this.listenWhen,
    super.key,
  });

  /// The bloc to listen to. If null, it is looked up from the component tree.
  final T? bloc;

  /// The callback that runs whenever the state changes.
  final void Function(BuildContext context, S state) listener;

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
    return BlocSignalListener<T, S>(
      key: key,
      bloc: bloc,
      listener: listener,
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

    _cleanup = effect(
      () {
        final currentState = _bloc!.state.value;
        final previous = _previousState as S;

        if (!_bloc!.equals(previous, currentState)) {
          _previousState = currentState;

          if (component.listenWhen == null ||
              component.listenWhen!(previous, currentState)) {
            component.listener(context, currentState);
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
    if (_bloc != effectiveBloc) {
      _bloc = effectiveBloc;
      _subscribe();
    }
  }

  @override
  void didUpdateComponent(BlocSignalListener<T, S> oldComponent) {
    super.didUpdateComponent(oldComponent);
    final effectiveBloc =
        component.bloc ?? BlocSignalProvider.of<T>(context, listen: true);
    if (_bloc != effectiveBloc) {
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
