import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_flutter/src/bloc_signal_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// Base options type accepted by [BlocSignalSelector.options], compatible with
/// [ComputedOptions], [ReadonlySignalOptions], and [SignalOptions].
typedef BlocSignalSelectorOptions<V> = Object;

/// A widget that filters rebuilds of its subtree by selecting
/// a sub-value of the [BlocSignal] state.
///
/// Example:
/// ```dart
/// BlocSignalSelector<UserBloc, UserState, String>(
///   selector: (state) => state.username,
///   options: ComputedOptions(name: 'UsernameSelector'),
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
    required Widget Function(BuildContext context, V value) builder,
    this.bloc,
    this.options,
    this.equals,
    super.key,
  })  : _builder = builder,
        child = null,
        _childBuilder = null,
        assert(
          options == null ||
              options is ComputedOptions<V> ||
              options is SignalOptions<V> ||
              options is ReadonlySignalOptions<V>,
          'options must be a ComputedOptions<$V>, SignalOptions<$V>, '
          'or ReadonlySignalOptions<$V>.',
        );

  /// Creates a [BlocSignalSelector] that preserves a static [child] subtree
  /// across selected-value rebuilds.
  ///
  /// The [child] widget is built once by the parent and passed into [builder]
  /// whenever the selected value changes.
  ///
  /// Example:
  /// ```dart
  /// BlocSignalSelector<UserBloc, UserState, String>.child(
  ///   selector: (state) => state.username,
  ///   child: const Icon(Icons.person),
  ///   builder: (context, username, child) {
  ///     return Row(
  ///       children: [
  ///         if (child != null) child,
  ///         Text('Username: $username'),
  ///       ],
  ///     );
  ///   },
  /// )
  /// ```
  const BlocSignalSelector.child({
    required this.selector,
    required Widget Function(BuildContext context, V value, Widget? child)
        builder,
    this.bloc,
    this.options,
    this.equals,
    this.child,
    super.key,
  })  : _builder = null,
        _childBuilder = builder,
        assert(
          options == null ||
              options is ComputedOptions<V> ||
              options is SignalOptions<V> ||
              options is ReadonlySignalOptions<V>,
          'options must be a ComputedOptions<$V>, SignalOptions<$V>, '
          'or ReadonlySignalOptions<$V>.',
        );

  /// The bloc to select from. If null, it is looked up from the widget tree.
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

  final Widget Function(BuildContext context, V value)? _builder;

  /// The builder function that rebuilds when the selected value changes.
  Widget Function(BuildContext context, V value) get builder =>
      _builder ?? (context, value) => _childBuilder!(context, value, child);

  /// An optional static child widget passed through to the `builder` callback
  /// in [BlocSignalSelector.child].
  final Widget? child;

  final Widget Function(BuildContext context, V value, Widget? child)?
      _childBuilder;

  @override
  State<BlocSignalSelector<T, S, V>> createState() =>
      _BlocSignalSelectorState<T, S, V>();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<T>('bloc', bloc, defaultValue: null))
      ..add(
        DiagnosticsProperty<BlocSignalSelectorOptions<V>>(
          'options',
          options,
          defaultValue: null,
        ),
      )
      ..add(
        ObjectFlagProperty<bool Function(V previous, V current)>.has(
          'equals',
          equals,
        ),
      );
  }
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
  EffectCleanup? _cleanup;
  late V _selectedValue;

  void _initComputed() {
    _cleanup?.call();
    final options = widget.options;
    final signalEquality =
        options is SignalOptions<V> ? options.equalityCheck : null;
    final customEquals = widget.equals ?? signalEquality?.equals;
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
        widget.selector(_bloc!.state.value),
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
    var isInitial = true;

    _cleanup = effect(
      () {
        final nextSlot = _computed.value;
        if (isInitial) {
          isInitial = false;
          return;
        }
        if (!mounted) return;
        if (currentSlot != nextSlot) {
          currentSlot = nextSlot;
          _selectedValue = nextSlot.value;
          setState(() {});
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
        widget.bloc ?? BlocSignalProvider.of<T>(context, listen: true);
    if (!identical(_bloc, effectiveBloc)) {
      _bloc = effectiveBloc;
      _initComputed();
    }
  }

  @override
  void didUpdateWidget(BlocSignalSelector<T, S, V> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final effectiveBloc =
        widget.bloc ?? BlocSignalProvider.of<T>(context, listen: true);
    if (!identical(_bloc, effectiveBloc) ||
        oldWidget.selector != widget.selector ||
        oldWidget.options != widget.options ||
        oldWidget.equals != widget.equals) {
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
    final childBuilder = widget._childBuilder;
    if (childBuilder != null) {
      return childBuilder(context, _selectedValue, widget.child);
    }
    return widget.builder(context, _selectedValue);
  }
}
