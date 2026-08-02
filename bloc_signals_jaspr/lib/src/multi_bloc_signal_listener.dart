import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_jaspr/src/bloc_signal_listener.dart';
import 'package:jaspr/jaspr.dart';

/// A Jaspr component that merges multiple [BlocSignalListener]s into a single
/// linear component hierarchy to improve readability.
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
class MultiBlocSignalListener extends StatelessComponent {
  /// Creates a [MultiBlocSignalListener] that runs multiple [listeners].
  const MultiBlocSignalListener({
    required this.child,
    required this.listeners,
    super.key,
  });

  /// The list of [BlocSignalListener] instances to run.
  final List<BlocSignalListener<BlocSignalBase<dynamic>, dynamic>> listeners;

  /// The child component subtree.
  final Component child;

  @override
  Component build(BuildContext context) {
    var current = child;
    for (final listener in listeners.reversed) {
      current = listener.copyWith(current);
    }
    return current;
  }
}
