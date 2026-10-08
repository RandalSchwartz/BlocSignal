import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_jaspr/src/bloc_signal_provider.dart';
import 'package:jaspr/jaspr.dart';
import 'package:signals_core/signals_core.dart';

/// Base options type accepted by [BlocSignalSelector.options], compatible with
/// [ComputedOptions], [ReadonlySignalOptions], and [SignalOptions].
typedef BlocSignalSelectorOptions<V> = Object;

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
    this.equals,
    super.key,
  }) : assert(
          options == null ||
              options is ComputedOptions<V> ||
              options is SignalOptions<V> ||
              options is ReadonlySignalOptions<V>,
          'options must be a ComputedOptions<$V>, SignalOptions<$V>, '
          'or ReadonlySignalOptions<$V>.',
        );

  /// The bloc to select from. If null, it is looked up from the component tree.
  final T? bloc;

  /// Optional configuration options for the underlying computed signal.
  ///
  /// Accepts [ComputedOptions], [ReadonlySignalOptions], or [SignalOptions]
  /// (including custom `equality` / `equalityCheck` configuration).
  final BlocSignalSelectorOptions<V>? options;

  /// Optional custom equality comparator for the selected value [V].
  ///
  /// When provided, takes precedence over `options.equalityCheck` (when
  /// [options] is a [SignalOptions]) and defaults to `==` when both are null.
  final bool Function(V previous, V current)? equals;

  /// The function that selects the sub-value from the state.
  final V Function(S state) selector;

  /// The builder function that rebuilds when the selected value changes.
  final Component Function(BuildContext context, V value) builder;

  @override
  State<BlocSignalSelector<T, S, V>> createState() =>
      _BlocSignalSelectorState<T, S, V>();
}

@immutable
class _SelectorSlot<V> {
  const _SelectorSlot(this.value, this.customEquals);

  final V value;
  final bool Function(V previous, V current)? customEquals;

  @override
  bool operator ==(Object other) =>
      other is _SelectorSlot<V> &&
      (customEquals != null
          ? customEquals!(value, other.value)
          : value == other.value);

  @override
  int get hashCode => value.hashCode;
}

class _BlocSignalSelectorState<T extends BlocSignalBase<S>, S, V>
    extends State<BlocSignalSelector<T, S, V>> {
  T? _bloc;
  late Computed<_SelectorSlot<V>> _computed;
  void Function()? _cleanup;
  late V _selectedValue;

  void _initComputed() {
    _cleanup?.call();
    final options = component.options;
    final signalEquality =
        options is SignalOptions<V> ? options.equalityCheck : null;
    final customEquals = component.equals ?? signalEquality?.equals;
    final (debugName, autoDispose, watched, unwatched) = switch (options) {
      ComputedOptions<V>(
        :final name,
        :final autoDispose,
        :final watched,
        :final unwatched
      ) =>
        (name, autoDispose, watched, unwatched),
      SignalOptions<V>(
        :final name,
        :final autoDispose,
        :final watched,
        :final unwatched
      ) =>
        (name, autoDispose, watched, unwatched),
      ReadonlySignalOptions<V>(
        :final name,
        :final autoDispose,
        :final watched,
        :final unwatched
      ) =>
        (name, autoDispose, watched, unwatched),
      _ => (null, false, null, null),
    };
    _computed = computed<_SelectorSlot<V>>(
      () => _SelectorSlot<V>(
        component.selector(_bloc!.state.value),
        customEquals,
      ),
      options: ComputedOptions<_SelectorSlot<V>>(
        name: debugName ?? 'BlocSignalSelector<$T, $S, $V>.computed',
        autoDispose: autoDispose,
        watched: watched,
        unwatched: unwatched,
      ),
    );
    var currentSlot = _computed.value;
    _selectedValue = currentSlot.value;

    _cleanup = effect(
      () {
        final nextSlot = _computed.value;
        if (currentSlot != nextSlot) {
          currentSlot = nextSlot;
          _selectedValue = nextSlot.value;
          if (mounted) {
            setState(() {});
          }
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
    final effectiveBloc =
        component.bloc ?? BlocSignalProvider.of<T>(context, listen: true);
    if (_bloc != effectiveBloc ||
        oldComponent.selector != component.selector ||
        oldComponent.options != component.options ||
        oldComponent.equals != component.equals) {
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
