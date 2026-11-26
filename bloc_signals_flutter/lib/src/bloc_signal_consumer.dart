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
    required Widget Function(BuildContext context, S state) builder,
    required this.listener,
    this.bloc,
    this.buildWhen,
    this.listenWhen,
    super.key,
  })  : _builder = builder,
        child = null,
        _childBuilder = null;

  /// Creates a [BlocSignalConsumer] that preserves a static [child] subtree
  /// across state rebuilds while listening for state changes.
  ///
  /// The [child] widget is built once by the parent and passed into [builder]
  /// on every state-driven rebuild without reconstructing the static subtree.
  ///
  /// Example:
  /// ```dart
  /// BlocSignalConsumer<CounterBloc, int>.child(
  ///   listener: (context, state) {
  ///     if (state == 10) {
  ///       showSnackBar(context, 'Limit reached!');
  ///     }
  ///   },
  ///   child: const Icon(Icons.notifications),
  ///   builder: (context, state, child) {
  ///     return Row(
  ///       children: [
  ///         if (child != null) child,
  ///         Text('Count: $state'),
  ///       ],
  ///     );
  ///   },
  /// )
  /// ```
  const BlocSignalConsumer.child({
    required Widget Function(BuildContext context, S state, Widget? child)
        builder,
    required this.listener,
    this.bloc,
    this.buildWhen,
    this.listenWhen,
    this.child,
    super.key,
  })  : _builder = null,
        _childBuilder = builder;

  /// The bloc to listen and build from. If null, it is looked up from the
  /// widget tree.
  final T? bloc;

  final Widget Function(BuildContext context, S state)? _builder;

  /// The builder function that rebuilds when the state changes.
  Widget Function(BuildContext context, S state) get builder =>
      _builder ?? (context, state) => _childBuilder!(context, state, child);

  /// The callback that runs whenever the state changes.
  final void Function(BuildContext context, S state) listener;

  /// An optional predicate function that determines whether [builder] should
  /// rebuild.
  final bool Function(S previous, S current)? buildWhen;

  /// A function that determines whether the [listener] should be called.
  ///
  /// Defaults to null, in which case the listener will be called on every
  /// change.
  final bool Function(S previous, S current)? listenWhen;

  /// An optional static child widget passed through to the `builder` callback
  /// in [BlocSignalConsumer.child].
  final Widget? child;

  final Widget Function(BuildContext context, S state, Widget? child)?
      _childBuilder;

  @override
  Widget build(BuildContext context) {
    final effectiveBloc =
        bloc ?? BlocSignalProvider.of<T>(context, listen: true);
    final childBuilder = _childBuilder;

    return BlocSignalListener<T, S>(
      bloc: effectiveBloc,
      listener: listener,
      listenWhen: listenWhen,
      child: childBuilder != null
          ? BlocSignalBuilder<T, S>.child(
              bloc: effectiveBloc,
              buildWhen: buildWhen,
              builder: childBuilder,
              child: child,
            )
          : BlocSignalBuilder<T, S>(
              bloc: effectiveBloc,
              buildWhen: buildWhen,
              builder: builder,
            ),
    );
  }
}
