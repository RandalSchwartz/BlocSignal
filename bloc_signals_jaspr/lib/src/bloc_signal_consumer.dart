import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_jaspr/src/bloc_signal_builder.dart';
import 'package:bloc_signals_jaspr/src/bloc_signal_listener.dart';
import 'package:bloc_signals_jaspr/src/bloc_signal_provider.dart';
import 'package:jaspr/jaspr.dart';

/// A Jaspr component that combines a [BlocSignalBuilder] and
/// [BlocSignalListener] into one.
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
    required void Function(BuildContext context, S state) listener,
    this.bloc,
    this.buildWhen,
    this.listenWhen,
    super.key,
  })  : _listener = listener,
        _transitionListener = null;

  /// Creates a [BlocSignalConsumer] whose [listener] receives both the
  /// `previous` and `current` state on each transition.
  ///
  /// Example:
  /// ```dart
  /// BlocSignalConsumer<CounterBloc, int>.transition(
  ///   listener: (context, previous, current) {
  ///     // Perform side effect with previous and current
  ///   },
  ///   builder: (context, state) => div([.text('Count: $state')]),
  /// )
  /// ```
  const BlocSignalConsumer.transition({
    required this.builder,
    required void Function(BuildContext context, S previous, S current)
        listener,
    this.bloc,
    this.buildWhen,
    this.listenWhen,
    super.key,
  })  : _listener = null,
        _transitionListener = listener;

  /// The bloc to listen and build from. If null, it is looked up from the
  /// component tree.
  final T? bloc;

  /// The builder function that rebuilds when the state changes.
  final Component Function(BuildContext context, S state) builder;

  final void Function(BuildContext context, S state)? _listener;

  final void Function(BuildContext context, S previous, S current)?
      _transitionListener;

  /// The callback that runs whenever the state changes.
  void Function(BuildContext context, S state) get listener =>
      _listener ??
      (context, state) => _transitionListener!(context, state, state);

  /// An optional predicate function that determines whether [builder] should
  /// rebuild.
  final bool Function(S previous, S current)? buildWhen;

  /// A function that determines whether the [listener] should be called.
  ///
  /// Defaults to null, in which case the listener will be called on every
  /// change.
  final bool Function(S previous, S current)? listenWhen;

  @override
  Component build(BuildContext context) {
    final effectiveBloc =
        bloc ?? BlocSignalProvider.of<T>(context, listen: true);
    final child = BlocSignalBuilder<T, S>(
      bloc: effectiveBloc,
      buildWhen: buildWhen,
      builder: builder,
    );
    if (_transitionListener != null) {
      return BlocSignalListener<T, S>.transition(
        bloc: effectiveBloc,
        listener: _transitionListener,
        listenWhen: listenWhen,
        child: child,
      );
    }
    return BlocSignalListener<T, S>(
      bloc: effectiveBloc,
      listener: _listener!,
      listenWhen: listenWhen,
      child: child,
    );
  }
}
