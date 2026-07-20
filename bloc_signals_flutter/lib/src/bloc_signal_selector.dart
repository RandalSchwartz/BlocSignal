import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_flutter/src/bloc_signal_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// A widget that filters rebuilds of its subtree by selecting
/// a sub-value of the [BlocSignal] state.
///
/// Example:
/// ```dart
/// BlocSignalSelector<UserBloc, UserState, String>(
///   selector: (state) => state.username,
///   builder: (context, username) {
///     return Text('Username: $username');
///   },
/// )
/// ```
class BlocSignalSelector<T extends BlocSignalBase<S>, S, V>
    extends StatefulWidget {
  /// Creates a [BlocSignalSelector] widget.
  const BlocSignalSelector({
    required this.selector,
    required this.builder,
    this.bloc,
    super.key,
  });

  /// The bloc to select from. If null, it is looked up from the widget tree.
  final T? bloc;

  /// The function that selects the sub-value from the state.
  final V Function(S state) selector;

  /// The builder function that rebuilds when the selected value changes.
  final Widget Function(BuildContext context, V value) builder;

  @override
  State<BlocSignalSelector<T, S, V>> createState() =>
      _BlocSignalSelectorState<T, S, V>();
}

class _BlocSignalSelectorState<T extends BlocSignalBase<S>, S, V>
    extends State<BlocSignalSelector<T, S, V>> {
  T? _bloc;
  late Computed<V> _computed;
  EffectCleanup? _cleanup;
  late V _selectedValue;

  void _initComputed() {
    _cleanup?.call();
    _computed = computed(() => widget.selector(_bloc!.state.value));
    _selectedValue = _computed.value;

    _cleanup = effect(() {
      final newValue = _computed.value;
      if (newValue != _selectedValue) {
        setState(() {
          _selectedValue = newValue;
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final effectiveBloc = widget.bloc ?? BlocSignalProvider.of<T>(context);
    if (_bloc != effectiveBloc) {
      _bloc = effectiveBloc;
      _initComputed();
    }
  }

  @override
  void didUpdateWidget(BlocSignalSelector<T, S, V> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final effectiveBloc = widget.bloc ?? BlocSignalProvider.of<T>(context);
    if (_bloc != effectiveBloc) {
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
  Widget build(BuildContext context) {
    return widget.builder(context, _selectedValue);
  }
}
