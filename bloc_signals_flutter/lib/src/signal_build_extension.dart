import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_flutter/src/bloc_signal_builder.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// A zero-allocation callable functor wrapping a [ReadonlySignal] to build
/// reactive Flutter widgets fluently via `.build(...)` and `.build.child(...)`.
///
/// Example:
/// ```dart
/// final counter = signal<int>(0);
///
/// // Rebuild on every signal change:
/// counter.build((context, value) => Text('Count: $value'));
///
/// // Preserve a static child subtree across updates:
/// counter.build.child(
///   const Icon(Icons.star),
///   (context, value, child) => Row(
///     children: [
///       if (child != null) child,
///       Text('Count: $value'),
///     ],
///   ),
/// );
/// ```
extension type const SignalWidgetFunctor<T>(ReadonlySignal<T> signal) {
  /// Builds a reactive widget that rebuilds when [signal] changes.
  ///
  /// Supply [buildWhen] to filter rebuilds based on previous and current
  /// values, or [equals] to override the default `==` equality check.
  ///
  /// Example:
  /// ```dart
  /// final counter = signal<int>(0);
  /// final widget = counter.build(
  ///   (context, value) => Text('$value'),
  ///   buildWhen: (previous, current) => current.isEven,
  /// );
  /// ```
  Widget call(
    Widget Function(BuildContext context, T value) builder, {
    Key? key,
    bool Function(T previous, T current)? buildWhen,
    bool Function(T previous, T current)? equals,
  }) =>
      _SignalBuildWidget<T>(
        key: key,
        signal: signal,
        builder: builder,
        buildWhen: buildWhen,
        equals: equals,
      );

  /// Builds a reactive widget that preserves a static [child] subtree across
  /// signal-driven rebuilds.
  ///
  /// The [child] widget is constructed once by the parent and passed into
  /// [builder] on every rebuild without reconstructing the static subtree.
  ///
  /// Example:
  /// ```dart
  /// final counter = signal<int>(0);
  /// final widget = counter.build.child(
  ///   const Icon(Icons.add),
  ///   (context, value, child) => Row(
  ///     children: [
  ///       Text('$value'),
  ///       if (child != null) child,
  ///     ],
  ///   ),
  /// );
  /// ```
  Widget child(
    Widget? child,
    Widget Function(BuildContext context, T value, Widget? child) builder, {
    Key? key,
    bool Function(T previous, T current)? buildWhen,
    bool Function(T previous, T current)? equals,
  }) =>
      _SignalBuildWidget<T>.child(
        key: key,
        signal: signal,
        builder: builder,
        buildWhen: buildWhen,
        equals: equals,
        child: child,
      );
}

/// A zero-allocation callable functor wrapping a [BlocSignalBase] container to
/// build reactive Flutter widgets fluently via `.build(...)` and
/// `.build.child(...)`.
///
/// Example:
/// ```dart
/// final cubit = CounterCubit();
///
/// // Rebuild on every state emission:
/// cubit.build((context, state) => Text('Count: $state'));
///
/// // Preserve a static child subtree across emissions:
/// cubit.build.child(
///   const Icon(Icons.bolt),
///   (context, state, child) => Row(
///     children: [
///       if (child != null) child,
///       Text('Count: $state'),
///     ],
///   ),
/// );
/// ```
extension type const BlocSignalWidgetFunctor<T>(BlocSignalBase<T> bloc) {
  /// Builds a reactive widget that rebuilds when [bloc] emits a new state,
  /// delegating to [BlocSignalBuilder].
  ///
  /// Supply [buildWhen] to filter rebuilds based on previous and current
  /// states.
  ///
  /// Example:
  /// ```dart
  /// final cubit = CounterCubit();
  /// final widget = cubit.build(
  ///   (context, state) => Text('$state'),
  ///   buildWhen: (previous, current) => current > 0,
  /// );
  /// ```
  Widget call(
    Widget Function(BuildContext context, T state) builder, {
    Key? key,
    bool Function(T previous, T current)? buildWhen,
  }) =>
      BlocSignalBuilder<BlocSignalBase<T>, T>(
        key: key,
        bloc: bloc,
        buildWhen: buildWhen,
        builder: builder,
      );

  /// Builds a reactive widget that preserves a static [child] subtree across
  /// state emissions, delegating to [BlocSignalBuilder.child].
  ///
  /// Example:
  /// ```dart
  /// final cubit = CounterCubit();
  /// final widget = cubit.build.child(
  ///   const Icon(Icons.add),
  ///   (context, state, child) => Row(
  ///     children: [
  ///       Text('$state'),
  ///       if (child != null) child,
  ///     ],
  ///   ),
  /// );
  /// ```
  Widget child(
    Widget? child,
    Widget Function(BuildContext context, T state, Widget? child) builder, {
    Key? key,
    bool Function(T previous, T current)? buildWhen,
  }) =>
      BlocSignalBuilder<BlocSignalBase<T>, T>.child(
        key: key,
        bloc: bloc,
        buildWhen: buildWhen,
        builder: builder,
        child: child,
      );
}

/// Adds the fluent `.build` widget builder functor to any [ReadonlySignal]
/// (including `Signal` and `Computed`).
///
/// Example:
/// ```dart
/// final count = signal<int>(0);
/// final widget = count.build((context, value) => Text('$value'));
/// ```
extension ReadonlySignalBuildExtension<T> on ReadonlySignal<T> {
  /// Returns a zero-allocation [SignalWidgetFunctor] for building reactive
  /// widgets directly from this signal.
  SignalWidgetFunctor<T> get build => SignalWidgetFunctor<T>(this);
}

/// Adds the fluent `.build` widget builder functor to any [BlocSignalBase]
/// container (`CubitSignal` and `BlocSignal`).
///
/// Example:
/// ```dart
/// final cubit = CounterCubit();
/// final widget = cubit.build((context, state) => Text('$state'));
/// ```
extension BlocSignalBuildExtension<T> on BlocSignalBase<T> {
  /// Returns a zero-allocation [BlocSignalWidgetFunctor] for building reactive
  /// widgets directly from this container.
  BlocSignalWidgetFunctor<T> get build => BlocSignalWidgetFunctor<T>(this);
}

class _SignalBuildWidget<T> extends StatefulWidget {
  const _SignalBuildWidget({
    required this.signal,
    required Widget Function(BuildContext context, T value) builder,
    super.key,
    this.buildWhen,
    this.equals,
  })  : _builder = builder,
        child = null,
        _childBuilder = null;

  const _SignalBuildWidget.child({
    required this.signal,
    required Widget Function(BuildContext context, T value, Widget? child)
        builder,
    super.key,
    this.buildWhen,
    this.equals,
    this.child,
  })  : _builder = null,
        _childBuilder = builder;

  final ReadonlySignal<T> signal;
  final bool Function(T previous, T current)? buildWhen;
  final bool Function(T previous, T current)? equals;
  final Widget Function(BuildContext context, T value)? _builder;
  final Widget? child;
  final Widget Function(BuildContext context, T value, Widget? child)?
      _childBuilder;

  @override
  State<_SignalBuildWidget<T>> createState() => _SignalBuildWidgetState<T>();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<ReadonlySignal<T>>('signal', signal))
      ..add(DiagnosticsProperty<Widget?>('child', child, defaultValue: null))
      ..add(
        ObjectFlagProperty<bool Function(T previous, T current)>.has(
          'buildWhen',
          buildWhen,
        ),
      )
      ..add(
        ObjectFlagProperty<bool Function(T previous, T current)>.has(
          'equals',
          equals,
        ),
      );
  }
}

class _SignalBuildWidgetState<T> extends State<_SignalBuildWidget<T>> {
  late T _value;
  late T _previousValue;
  EffectCleanup? _cleanup;
  bool _isActive = true;
  bool _hasPendingUpdate = false;

  void _reconcileValue(T current, {required bool notify}) {
    final previous = _previousValue;
    final areEqual = widget.equals != null && widget.equals!(previous, current);
    if (!areEqual) {
      _previousValue = current;
      if (widget.buildWhen == null || widget.buildWhen!(previous, current)) {
        _value = current;
        if (notify) {
          setState(() {});
        }
      }
    }
  }

  void _subscribe() {
    _cleanup?.call();
    _cleanup = null;
    _hasPendingUpdate = false;
    final initial = widget.signal.value;
    _value = initial;
    _previousValue = initial;
    var isInitial = true;

    _cleanup = effect(
      () {
        final current = widget.signal.value;
        if (isInitial) {
          isInitial = false;
          return;
        }
        untracked(() {
          if (!mounted) return;
          if (!_isActive) {
            _hasPendingUpdate = true;
            return;
          }
          _reconcileValue(current, notify: true);
        });
      },
      options: EffectOptions(name: 'SignalWidgetFunctor<$T>.effect'),
    );
  }

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void activate() {
    super.activate();
    _isActive = true;
    if (_hasPendingUpdate) {
      _hasPendingUpdate = false;
      untracked(() {
        _reconcileValue(widget.signal.value, notify: false);
      });
    }
  }

  @override
  void deactivate() {
    _isActive = false;
    super.deactivate();
  }

  @override
  void didUpdateWidget(_SignalBuildWidget<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.signal, widget.signal)) {
      _subscribe();
    }
  }

  @override
  void dispose() {
    _hasPendingUpdate = false;
    _cleanup?.call();
    _cleanup = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final childBuilder = widget._childBuilder;
    if (childBuilder != null) {
      return childBuilder(context, _value, widget.child);
    }
    return widget._builder!(context, _value);
  }
}
