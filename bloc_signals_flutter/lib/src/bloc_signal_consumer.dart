import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_flutter/src/bloc_signal_builder.dart';
import 'package:bloc_signals_flutter/src/bloc_signal_listener.dart';
import 'package:bloc_signals_flutter/src/bloc_signal_provider.dart';
import 'package:flutter/foundation.dart';
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
    required void Function(BuildContext context, S state) listener,
    this.bloc,
    this.buildWhen,
    this.listenWhen,
    this.take,
    this.takeWhile,
    super.key,
  })  : assert(take == null || take >= 0, 'take must be non-negative.'),
        _builder = builder,
        _listener = listener,
        _transitionListener = null,
        child = null,
        _childBuilder = null;

  /// Creates a [BlocSignalConsumer] whose [listener] receives both the
  /// `previous` and `current` state on each transition.
  ///
  /// Example:
  /// ```dart
  /// BlocSignalConsumer<CounterBloc, int>.transition(
  ///   listener: (context, previous, current) {
  ///     debugPrint('Changed from $previous to $current');
  ///   },
  ///   builder: (context, state) => Text('Count: $state'),
  /// )
  /// ```
  const BlocSignalConsumer.transition({
    required Widget Function(BuildContext context, S state) builder,
    required void Function(BuildContext context, S previous, S current)
        listener,
    this.bloc,
    this.buildWhen,
    this.listenWhen,
    this.take,
    this.takeWhile,
    super.key,
  })  : assert(take == null || take >= 0, 'take must be non-negative.'),
        _builder = builder,
        _listener = null,
        _transitionListener = listener,
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
    required void Function(BuildContext context, S state) listener,
    this.bloc,
    this.buildWhen,
    this.listenWhen,
    this.take,
    this.takeWhile,
    this.child,
    super.key,
  })  : assert(take == null || take >= 0, 'take must be non-negative.'),
        _builder = null,
        _listener = listener,
        _transitionListener = null,
        _childBuilder = builder;

  /// The bloc to listen and build from. If null, it is looked up from the
  /// widget tree.
  final T? bloc;

  final Widget Function(BuildContext context, S state)? _builder;

  /// The builder function that rebuilds when the state changes.
  Widget Function(BuildContext context, S state) get builder =>
      _builder ?? (context, state) => _childBuilder!(context, state, child);

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

  /// The maximum number of times [listener] will be invoked before detaching.
  ///
  /// Emissions filtered out by [listenWhen] do not consume this budget. When
  /// `0`, no active subscription is registered and [listener] is never called.
  /// Must be non-negative when provided.
  final int? take;

  /// A predicate evaluated against each matching state before invoking
  /// [listener].
  ///
  /// When it returns `false`, the listener detaches permanently without
  /// invoking [listener] for that emission or any subsequent emissions.
  final bool Function(S state)? takeWhile;

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
    final builtChild = childBuilder != null
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
          );

    if (_transitionListener != null) {
      return BlocSignalListener<T, S>.transition(
        bloc: effectiveBloc,
        listener: _transitionListener,
        listenWhen: listenWhen,
        take: take,
        takeWhile: takeWhile,
        child: builtChild,
      );
    }

    return BlocSignalListener<T, S>(
      bloc: effectiveBloc,
      listener: _listener!,
      listenWhen: listenWhen,
      take: take,
      takeWhile: takeWhile,
      child: builtChild,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<T>('bloc', bloc, defaultValue: null))
      ..add(
        ObjectFlagProperty<bool Function(S previous, S current)>.has(
          'buildWhen',
          buildWhen,
        ),
      )
      ..add(
        ObjectFlagProperty<bool Function(S previous, S current)>.has(
          'listenWhen',
          listenWhen,
        ),
      )
      ..add(IntProperty('take', take, defaultValue: null))
      ..add(
        ObjectFlagProperty<bool Function(S state)>.has(
          'takeWhile',
          takeWhile,
        ),
      );
  }
}
