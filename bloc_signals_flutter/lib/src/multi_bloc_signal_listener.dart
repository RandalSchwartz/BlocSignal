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

  /// The list of listener widgets (such as [BlocSignalListener]) to run.
  final List<dynamic> listeners;

  /// The child widget subtree.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    var current = child;
    for (final listener in listeners.reversed) {
      if (listener is BlocSignalListener) {
        current = (listener as dynamic).copyWith(current) as Widget;
      }
    }
    return current;
  }
}
