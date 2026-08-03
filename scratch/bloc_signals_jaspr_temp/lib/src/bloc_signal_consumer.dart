import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_jaspr/src/bloc_signal_builder.dart';
import 'package:bloc_signals_jaspr/src/bloc_signal_listener.dart';
import 'package:bloc_signals_jaspr/src/bloc_signal_provider.dart';
import 'package:jaspr/jaspr.dart';

/// A Jaspr component that combines a [BlocSignalBuilder] and [BlocSignalListener]
/// into one.
///
/// Example:
/// ```dart
/// BlocSignalConsumer<CounterBloc, int>(
///   listener: (context, state) {
///     if (state == 10) {
///       // Perform side effect
///     }
///   },
///   builder: (context, state) {
///     return div([.text('Count: $state')]);
///   },
/// )
/// ```
class BlocSignalConsumer<T extends BlocSignalBase<S>, S>
    extends StatelessComponent {
  /// Creates a [BlocSignalConsumer] component.
  const BlocSignalConsumer({
    required this.builder,
    required this.listener,
    this.bloc,
    this.listenWhen,
    super.key,
  });

  /// The bloc to listen and build from. If null, it is looked up from the
  /// component tree.
  final T? bloc;

  /// The builder function that rebuilds when the state changes.
  final Component Function(BuildContext context, S state) builder;

  /// The callback that runs whenever the state changes.
  final void Function(BuildContext context, S state) listener;

  /// A function that determines whether the [listener] should be called.
  ///
  /// Defaults to null, in which case the listener will be called on every
  /// change.
  final bool Function(S previous, S current)? listenWhen;

  @override
  Component build(BuildContext context) {
    final effectiveBloc =
        bloc ?? BlocSignalProvider.of<T>(context, listen: true);
    return BlocSignalListener<T, S>(
      bloc: effectiveBloc,
      listener: listener,
      listenWhen: listenWhen,
      child: BlocSignalBuilder<T, S>(
        bloc: effectiveBloc,
        builder: builder,
      ),
    );
  }
}
