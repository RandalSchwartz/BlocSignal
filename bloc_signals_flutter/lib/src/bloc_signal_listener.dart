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
    extends StatelessWidget {
  /// Creates a [BlocSignalListener] widget.
  const BlocSignalListener({
    required this.listener,
    required this.child,
    this.bloc,
    super.key,
  });

  /// The bloc to listen to. If null, it is looked up from the widget tree.
  final T? bloc;

  /// The callback that runs whenever the state changes.
  final void Function(BuildContext context, S state) listener;

  /// The child widget subtree.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final effectiveBloc = bloc ?? BlocSignalProvider.of<T>(context);
    return SignalListener(
      effect: (context) {
        final state = effectiveBloc.state.value;
        listener(context, state);
      },
      child: child,
    );
  }
}
