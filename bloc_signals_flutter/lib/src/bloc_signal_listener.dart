import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_flutter/src/bloc_signal_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// An interface for [BlocSignalListener] widgets that can be merged by
/// `MultiBlocSignalListener` into a single linear widget hierarchy.
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
abstract class BlocSignalListenerSingleChildWidget implements Widget {
  /// Clones this listener widget with a new [child] widget.
  Widget copyWith(Widget child);
}

/// A widget that listens to a [BlocSignal] and runs a callback
/// when its state updates.
///
/// Example:
/// ```dart
/// BlocSignalListener<AuthBloc, AuthState>(
///   listener: (context, state) {
///     if (state is Authenticated) {
///       Navigator.pushNamed(context, '/home');
///     }
///   },
///   child: const LoginForm(),
/// )
/// ```
class BlocSignalListener<T extends BlocSignalBase<S>, S> extends StatefulWidget
    implements BlocSignalListenerSingleChildWidget {
  /// Creates a [BlocSignalListener] widget.
  const BlocSignalListener({
    required void Function(BuildContext context, S state) listener,
    this.child = const SizedBox.shrink(),
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
  ///     debugPrint('Changed from $previous to $current');
  ///   },
  ///   child: const CounterView(),
  /// )
  /// ```
  const BlocSignalListener.transition({
    required void Function(BuildContext context, S previous, S current)
        listener,
    this.child = const SizedBox.shrink(),
    this.bloc,
    this.listenWhen,
    super.key,
  })  : _listener = null,
        _transitionListener = listener;

  /// The bloc to listen to. If null, it is looked up from the widget tree.
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

  /// The child widget subtree.
  final Widget child;

  /// Clones this listener with a new child widget.
  @override
  BlocSignalListener<T, S> copyWith(Widget child) {
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

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<T>('bloc', bloc, defaultValue: null))
      ..add(
        ObjectFlagProperty<bool Function(S previous, S current)>.has(
          'listenWhen',
          listenWhen,
        ),
      );
  }
}

class _BlocSignalListenerState<T extends BlocSignalBase<S>, S>
    extends State<BlocSignalListener<T, S>> {
  T? _bloc;
  S? _previousState;
  EffectCleanup? _cleanup;

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

          if (widget.listenWhen == null ||
              widget.listenWhen!(previous, currentState)) {
            final transitionListener = widget._transitionListener;
            if (transitionListener != null) {
              transitionListener(context, previous, currentState);
            } else {
              widget._listener!(context, currentState);
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
        widget.bloc ?? BlocSignalProvider.of<T>(context, listen: true);
    if (!identical(_bloc, effectiveBloc)) {
      _bloc = effectiveBloc;
      _subscribe();
    }
  }

  @override
  void didUpdateWidget(BlocSignalListener<T, S> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final effectiveBloc =
        widget.bloc ?? BlocSignalProvider.of<T>(context, listen: true);
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
  Widget build(BuildContext context) {
    return widget.child;
  }
}
