import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_jaspr/src/bloc_signal_provider.dart';
import 'package:jaspr/jaspr.dart';
import 'package:signals_core/signals_core.dart';

/// A Jaspr component that rebuilds dynamically when the state of a
/// [BlocSignal] changes.
///
/// Example:
/// ```dart
/// BlocSignalBuilder<CounterBloc, int>(
///   builder: (context, state) {
///     return div([Component.text('Count: $state')]);
///   },
/// )
/// ```
class BlocSignalBuilder<T extends BlocSignalBase<S>, S>
    extends StatefulComponent {
  /// Creates a [BlocSignalBuilder] that listens to the specified [bloc].
  ///
  /// If [bloc] is null, it is looked up from the component tree
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
  /// and determines whether to rebuild the component.
  final bool Function(S previous, S current)? buildWhen;

  /// The builder function that creates the component subtree given the
  /// current state.
  final Component Function(BuildContext context, S state) builder;

  @override
  State<BlocSignalBuilder<T, S>> createState() =>
      _BlocSignalBuilderState<T, S>();
}

class _BlocSignalBuilderState<T extends BlocSignalBase<S>, S>
    extends State<BlocSignalBuilder<T, S>> {
  T? _bloc;
  S? _state;
  void Function()? _cleanup;

  void _subscribe() {
    _cleanup?.call();
    _state = _bloc!.state.value;

    _cleanup = effect(
      () {
        final currentState = _bloc!.state.value;
        if (_state != currentState) {
          final previous = _state as S;
          if (component.buildWhen == null ||
              component.buildWhen!(previous, currentState)) {
            _state = currentState;
            if (mounted) {
              setState(() {});
            }
          }
        }
      },
      options: EffectOptions(name: 'BlocSignalBuilder<$T, $S>.effect'),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final effectiveBloc =
        component.bloc ?? BlocSignalProvider.of<T>(context, listen: true);
    if (_bloc != effectiveBloc) {
      _bloc = effectiveBloc;
      _subscribe();
    }
  }

  @override
  void didUpdateComponent(BlocSignalBuilder<T, S> oldComponent) {
    super.didUpdateComponent(oldComponent);
    final effectiveBloc =
        component.bloc ?? BlocSignalProvider.of<T>(context, listen: true);
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
  Component build(BuildContext context) {
    return component.builder(context, _state as S);
  }
}
