import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_flutter/src/bloc_signal_builder.dart';
import 'package:bloc_signals_flutter/src/bloc_signal_listener.dart';
import 'package:bloc_signals_flutter/src/bloc_signal_provider.dart';
import 'package:flutter/widgets.dart';

/// A widget that combines a [BlocSignalBuilder] and [BlocSignalListener]
/// into one.
///
/// Example:
/// ```dart
/// BlocSignalConsumer<CounterBloc, int>(
///   listener: (context, state) {
///     if (state == 10) {
///       showSnackBar(context, 'Limit reached!');
///     }
///   },
///   builder: (context, state) {
///     return Text('Count: $state');
///   },
/// )
/// ```
class BlocSignalConsumer<T extends BlocSignalBase<S>, S>
    extends StatelessWidget {
  /// Creates a [BlocSignalConsumer] widget.
  const BlocSignalConsumer({
    required this.builder,
    required this.listener,
    this.bloc,
    super.key,
  });

  /// The bloc to listen and build from. If null, it is looked up from the
  /// widget tree.
  final T? bloc;

  /// The builder function that rebuilds when the state changes.
  final Widget Function(BuildContext context, S state) builder;

  /// The callback that runs whenever the state changes.
  final void Function(BuildContext context, S state) listener;

  @override
  Widget build(BuildContext context) {
    final effectiveBloc = bloc ?? BlocSignalProvider.of<T>(context);
    return BlocSignalListener<T, S>(
      bloc: effectiveBloc,
      listener: listener,
      child: BlocSignalBuilder<T, S>(
        bloc: effectiveBloc,
        builder: builder,
      ),
    );
  }
}
