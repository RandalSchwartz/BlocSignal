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
class BlocSignalBuilder<T extends BlocSignalBase<S>, S> extends StatefulWidget {
  /// Creates a [BlocSignalBuilder] that listens to the specified [bloc].
  ///
  /// If [bloc] is null, it is looked up from the widget tree
  /// via [BlocSignalProvider].
  const BlocSignalBuilder({
    required this.builder,
    super.key,
    this.bloc,
    this.buildWhen,
  });

  /// The [BlocSignal] to listen to. If null, it is retrieved from the context.
  final T? bloc;

  /// An optional predicate function that takes the previous and current state
  /// and determines whether to rebuild the widget.
  final bool Function(S previous, S current)? buildWhen;

  /// The builder function that creates the widget tree given the current state.
  final Widget Function(BuildContext context, S state) builder;

  @override
  State<BlocSignalBuilder<T, S>> createState() =>
      _BlocSignalBuilderState<T, S>();
}

class _BlocSignalBuilderState<T extends BlocSignalBase<S>, S>
    extends State<BlocSignalBuilder<T, S>> {
  T? _bloc;
  S? _state;
  EffectCleanup? _cleanup;

  void _subscribe() {
    _cleanup?.call();
    _state = _bloc!.state.value;

    _cleanup = effect(() {
      final currentState = _bloc!.state.value;
      if (_state != currentState) {
        final previous = _state as S;
        if (widget.buildWhen == null ||
            widget.buildWhen!(previous, currentState)) {
          _state = currentState;
          if (mounted) {
            setState(() {});
          }
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final effectiveBloc =
        widget.bloc ?? BlocSignalProvider.of<T>(context, listen: true);
    if (_bloc != effectiveBloc) {
      _bloc = effectiveBloc;
      _subscribe();
    }
  }

  @override
  void didUpdateWidget(BlocSignalBuilder<T, S> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final effectiveBloc =
        widget.bloc ?? BlocSignalProvider.of<T>(context, listen: true);
    if (_bloc != effectiveBloc) {
      _bloc = effectiveBloc;
      _subscribe();
    }
  }

  @override
  void dispose() {
    _cleanup?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _state as S);
  }
}
