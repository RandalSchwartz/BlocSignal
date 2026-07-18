import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_flutter/src/bloc_signal_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// A widget that rebuilds dynamically when the state of a [BlocSignal] changes.
///
/// Example:
/// ```dart
/// BlocSignalBuilder<CounterBloc, int>(
///   builder: (context, state) {
///     return Text('Count: $state');
///   },
/// )
/// ```
class BlocSignalBuilder<T extends BlocSignal<dynamic, S>, S>
    extends StatelessWidget {
  /// Creates a [BlocSignalBuilder] that listens to the specified [bloc].
  ///
  /// If [bloc] is null, it is looked up from the widget tree
  /// via [BlocSignalProvider].
  const BlocSignalBuilder({
    required this.builder,
    super.key,
    this.bloc,
  });

  /// The [BlocSignal] to listen to. If null, it is retrieved from the context.
  final T? bloc;

  /// The builder function that creates the widget tree given the current state.
  final Widget Function(BuildContext context, S state) builder;

  @override
  Widget build(BuildContext context) {
    final effectiveBloc = bloc ?? BlocSignalProvider.of<T>(context);
    return SignalBuilder(
      builder: (context) {
        return builder(context, effectiveBloc.state.value);
      },
    );
  }
}
