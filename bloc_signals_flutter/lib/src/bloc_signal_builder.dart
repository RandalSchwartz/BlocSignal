import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_flutter/src/bloc_signal_provider.dart';
import 'package:flutter/foundation.dart';
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
    required Widget Function(BuildContext context, S state) builder,
    super.key,
    this.bloc,
    this.buildWhen,
  })  : _builder = builder,
        child = null,
        _childBuilder = null;

  /// Creates a [BlocSignalBuilder] that preserves a static [child] subtree
  /// across state rebuilds.
  ///
  /// The [child] widget is built once by the parent and passed into [builder]
  /// on every state-driven rebuild without reconstructing the static subtree.
  ///
  /// Example:
  /// ```dart
  /// BlocSignalBuilder<CounterBloc, int>.child(
  ///   child: const Icon(Icons.add),
  ///   builder: (context, state, child) {
  ///     return Row(
  ///       children: [
  ///         Text('Count: $state'),
  ///         if (child != null) child,
  ///       ],
  ///     );
  ///   },
  /// )
  /// ```
  const BlocSignalBuilder.child({
    required Widget Function(BuildContext context, S state, Widget? child)
        builder,
    super.key,
    this.bloc,
    this.buildWhen,
    this.child,
  })  : _builder = null,
        _childBuilder = builder;

  /// The [BlocSignal] to listen to. If null, it is retrieved from the context.
  final T? bloc;

  /// An optional predicate function that takes the previous and current state
  /// and determines whether to rebuild the widget.
  final bool Function(S previous, S current)? buildWhen;

  final Widget Function(BuildContext context, S state)? _builder;

  /// The builder function that creates the widget tree given the current state.
  Widget Function(BuildContext context, S state) get builder =>
      _builder ?? (context, state) => _childBuilder!(context, state, child);

  /// An optional static child widget passed through to the `builder` callback
  /// in [BlocSignalBuilder.child].
  final Widget? child;

  final Widget Function(BuildContext context, S state, Widget? child)?
      _childBuilder;

  @override
  State<BlocSignalBuilder<T, S>> createState() =>
      _BlocSignalBuilderState<T, S>();

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
      );
  }
}

class _BlocSignalBuilderState<T extends BlocSignalBase<S>, S>
    extends State<BlocSignalBuilder<T, S>> {
  T? _bloc;
  S? _state;
  S? _previousState;
  EffectCleanup? _cleanup;
  bool _isActive = true;
  bool _hasPendingUpdate = false;

  void _reconcileState(S currentState, {required bool notify}) {
    final previous = _previousState as S;
    if (!_bloc!.equals(previous, currentState)) {
      _previousState = currentState;
      if (widget.buildWhen == null ||
          widget.buildWhen!(previous, currentState)) {
        _state = currentState;
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
    final initialState = _bloc!.state.value;
    _state = initialState;
    _previousState = initialState;
    var isInitial = true;

    _cleanup = effect(
      () {
        final currentState = _bloc!.state.value;
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
          _reconcileState(currentState, notify: true);
        });
      },
      options: EffectOptions(name: 'BlocSignalBuilder<$T, $S>.effect'),
    );
  }

  @override
  void activate() {
    super.activate();
    _isActive = true;
    if (_hasPendingUpdate) {
      _hasPendingUpdate = false;
      untracked(() {
        _reconcileState(_bloc!.state.value, notify: false);
      });
    }
  }

  @override
  void deactivate() {
    _isActive = false;
    super.deactivate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final effectiveBloc =
        widget.bloc ?? BlocSignalProvider.of<T>(context, listen: true);
    if (!identical(_bloc, effectiveBloc)) {
      _bloc = effectiveBloc;
      _subscribe();
    }
  }

  @override
  void didUpdateWidget(BlocSignalBuilder<T, S> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final effectiveBloc =
        widget.bloc ?? BlocSignalProvider.of<T>(context, listen: true);
    if (!identical(_bloc, effectiveBloc)) {
      _bloc = effectiveBloc;
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
      return childBuilder(context, _state as S, widget.child);
    }
    return widget.builder(context, _state as S);
  }
}
