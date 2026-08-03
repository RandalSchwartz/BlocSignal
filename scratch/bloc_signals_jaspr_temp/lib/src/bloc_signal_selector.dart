import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_jaspr/src/bloc_signal_provider.dart';
import 'package:jaspr/jaspr.dart';
import 'package:signals_core/signals_core.dart';

/// A Jaspr component that filters rebuilds of its subtree by selecting
/// a sub-value of the [BlocSignal] state.
///
/// Example:
/// ```dart
/// BlocSignalSelector<UserBloc, UserState, String>(
///   selector: (state) => state.username,
///   options: ComputedOptions(name: 'UsernameSelector'),
///   builder: (context, username) {
///     return div([Component.text('Username: $username')]);
///   },
/// )
/// ```
class BlocSignalSelector<T extends BlocSignalBase<S>, S, V>
    extends StatefulComponent {
  /// Creates a [BlocSignalSelector] component.
  const BlocSignalSelector({
    required this.selector,
    required this.builder,
    this.bloc,
    this.options,
    super.key,
  });

  /// The bloc to select from. If null, it is looked up from the component tree.
  final T? bloc;

  /// Optional configuration options for the underlying computed signal.
  final ComputedOptions<V>? options;

  /// The function that selects the sub-value from the state.
  final V Function(S state) selector;

  /// The builder function that rebuilds when the selected value changes.
  final Component Function(BuildContext context, V value) builder;

  @override
  State<BlocSignalSelector<T, S, V>> createState() =>
      _BlocSignalSelectorState<T, S, V>();
}

class _BlocSignalSelectorState<T extends BlocSignalBase<S>, S, V>
    extends State<BlocSignalSelector<T, S, V>> {
  T? _bloc;
  late Computed<V> _computed;
  void Function()? _cleanup;
  late V _selectedValue;

  void _initComputed() {
    _cleanup?.call();
    final debugName =
        component.options?.name ?? 'BlocSignalSelector<$T, $S, $V>.computed';
    _computed = computed(
      () => component.selector(_bloc!.state.value),
      options: ComputedOptions<V>(
        name: debugName,
        autoDispose: component.options?.autoDispose ?? false,
        watched: component.options?.watched,
        unwatched: component.options?.unwatched,
      ),
    );
    _selectedValue = _computed.value;

    _cleanup = effect(
      () {
        final newValue = _computed.value;
        if (newValue != _selectedValue) {
          setState(() {
            _selectedValue = newValue;
          });
        }
      },
      options: EffectOptions(
        name: 'BlocSignalSelector<$T, $S, $V>.effect',
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final effectiveBloc =
        component.bloc ?? BlocSignalProvider.of<T>(context, listen: true);
    if (_bloc != effectiveBloc) {
      _bloc = effectiveBloc;
      _initComputed();
    }
  }

  @override
  void didUpdateComponent(BlocSignalSelector<T, S, V> oldComponent) {
    super.didUpdateComponent(oldComponent);
    final effectiveBloc = component.bloc ?? BlocSignalProvider.of<T>(context);
    if (_bloc != effectiveBloc || oldComponent.selector != component.selector) {
      _bloc = effectiveBloc;
      _initComputed();
    }
  }

  @override
  void dispose() {
    _cleanup?.call();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    return component.builder(context, _selectedValue);
  }
}
