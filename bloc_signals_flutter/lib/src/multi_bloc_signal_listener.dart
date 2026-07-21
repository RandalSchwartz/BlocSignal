import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_flutter/src/bloc_signal_listener.dart';
import 'package:flutter/widgets.dart';

/// A widget that merges multiple [BlocSignalListener]s into a single linear
/// widget hierarchy to improve readability.
///
/// Example:
/// ```dart
/// MultiBlocSignalListener(
///   listeners: [
///     BlocSignalListener<AuthBloc, AuthState>(
///       listener: (context, state) => {},
///     ),
///     BlocSignalListener<ThemeBloc, ThemeState>(
///       listener: (context, state) => {},
///     ),
///   ],
///   child: HomeScreen(),
/// )
/// ```
class MultiBlocSignalListener extends StatelessWidget {
  /// Creates a [MultiBlocSignalListener] that runs multiple [listeners].
  const MultiBlocSignalListener({
    required this.child,
    required this.listeners,
    super.key,
  });

  /// The list of [BlocSignalListener] instances to run.
  final List<BlocSignalListener<BlocSignalBase<dynamic>, dynamic>> listeners;

  /// The child widget subtree.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    var current = child;
    for (final listener in listeners.reversed) {
      current = listener.copyWith(current);
    }
    return current;
  }
}
