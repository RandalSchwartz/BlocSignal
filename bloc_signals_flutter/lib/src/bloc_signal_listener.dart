import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_flutter/src/bloc_signal_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:signals_flutter/signals_flutter.dart';

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
class BlocSignalListener<T extends BlocSignalBase<S>, S>
    extends StatefulWidget {
  /// Creates a [BlocSignalListener] widget.
  const BlocSignalListener({
    required this.listener,
    required this.child,
    this.bloc,
    this.listenWhen,
    super.key,
  });

  /// The bloc to listen to. If null, it is looked up from the widget tree.
  final T? bloc;

  /// The callback that runs whenever the state changes.
  final void Function(BuildContext context, S state) listener;

  /// A function that determines whether the [listener] should be called.
  ///
  /// Defaults to null, in which case the listener will be called on every
  /// change.
  final bool Function(S previous, S current)? listenWhen;

  /// The child widget subtree.
  final Widget child;

  /// Clones this listener with a new child widget.
  BlocSignalListener<T, S> copyWith(Widget child) {
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
  EffectCleanup? _cleanup;

  void _subscribe() {
    _cleanup?.call();
    _previousState = _bloc!.state.value;

    _cleanup = effect(() {
      final currentState = _bloc!.state.value;

      if (_previousState != currentState) {
        final previous = _previousState as S;
        _previousState = currentState;

        if (widget.listenWhen == null ||
            widget.listenWhen!(previous, currentState)) {
          widget.listener(context, currentState);
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final effectiveBloc = widget.bloc ?? BlocSignalProvider.of<T>(context);
    if (_bloc != effectiveBloc) {
      _bloc = effectiveBloc;
      _subscribe();
    }
  }

  @override
  void didUpdateWidget(BlocSignalListener<T, S> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final effectiveBloc = widget.bloc ?? BlocSignalProvider.of<T>(context);
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
  Widget build(BuildContext context) {
    return widget.child;
  }
}
