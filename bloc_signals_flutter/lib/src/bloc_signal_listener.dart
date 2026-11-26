import 'dart:async';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_flutter/src/bloc_signal_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// An interface for [BlocSignalListener] widgets that can be merged by
/// `MultiBlocSignalListener` into a single linear widget hierarchy.
///
/// Example:
/// ```dart
/// final List<BlocSignalListenerSingleChildWidget> listeners = [
///   BlocSignalListener<AuthBloc, AuthState>(
///     listener: (context, state) {},
///   ),
///   BlocSignalListener<ThemeBloc, ThemeState>(
///     listener: (context, state) {},
///   ),
/// ];
/// ```
abstract class BlocSignalListenerSingleChildWidget implements Widget {
  /// Clones this listener widget with a new [child] widget.
  Widget copyWith(Widget child);
}

/// A widget that listens to a [BlocSignal] and runs a callback
/// when its state updates.
///
/// Example:
/// ```dart
/// BlocSignalListener<AuthBloc, AuthState>(
///   listener: (context, state) {
///     if (state is Authenticated) {
///       Navigator.pushNamed(context, '/home');
///     }
///   },
///   child: const LoginForm(),
/// )
/// ```
class BlocSignalListener<T extends BlocSignalBase<S>, S> extends StatefulWidget
    implements BlocSignalListenerSingleChildWidget {
  /// Creates a [BlocSignalListener] widget.
  const BlocSignalListener({
    required void Function(BuildContext context, S state) listener,
    this.child = const SizedBox.shrink(),
    this.bloc,
    this.listenWhen,
    this.take,
    this.takeWhile,
    this.debounce,
    this.throttle,
    super.key,
  })  : assert(take == null || take >= 0, 'take must be non-negative.'),
        assert(
          debounce == null || throttle == null,
          'Cannot specify both debounce and throttle.',
        ),
        _listener = listener,
        _transitionListener = null;

  /// Creates a [BlocSignalListener] that debounces state emissions by
  /// [duration], invoking [listener] only after emissions pause for [duration].
  ///
  /// Example:
  /// ```dart
  /// BlocSignalListener<SearchBloc, SearchState>.debounce(
  ///   duration: const Duration(milliseconds: 300),
  ///   listener: (context, state) => logSearch(state),
  ///   child: const SearchResults(),
  /// )
  /// ```
  const BlocSignalListener.debounce({
    required Duration duration,
    required void Function(BuildContext context, S state) listener,
    this.child = const SizedBox.shrink(),
    this.bloc,
    this.listenWhen,
    this.take,
    this.takeWhile,
    super.key,
  })  : assert(take == null || take >= 0, 'take must be non-negative.'),
        debounce = duration,
        throttle = null,
        _listener = listener,
        _transitionListener = null;

  /// Creates a [BlocSignalListener] that throttles state emissions by
  /// [duration], invoking [listener] immediately on the leading edge and
  /// suppressing subsequent emissions until [duration] elapses.
  ///
  /// Example:
  /// ```dart
  /// BlocSignalListener<ScrollBloc, ScrollState>.throttle(
  ///   duration: const Duration(milliseconds: 200),
  ///   listener: (context, state) => trackScroll(state),
  ///   child: const ScrollView(),
  /// )
  /// ```
  const BlocSignalListener.throttle({
    required Duration duration,
    required void Function(BuildContext context, S state) listener,
    this.child = const SizedBox.shrink(),
    this.bloc,
    this.listenWhen,
    this.take,
    this.takeWhile,
    super.key,
  })  : assert(take == null || take >= 0, 'take must be non-negative.'),
        debounce = null,
        throttle = duration,
        _listener = listener,
        _transitionListener = null;

  /// Creates a [BlocSignalListener] whose [listener] receives both the
  /// `previous` and `current` state on each transition.
  ///
  /// Example:
  /// ```dart
  /// BlocSignalListener<CounterBloc, int>.transition(
  ///   listener: (context, previous, current) {
  ///     debugPrint('Changed from $previous to $current');
  ///   },
  ///   child: const CounterView(),
  /// )
  /// ```
  const BlocSignalListener.transition({
    required void Function(BuildContext context, S previous, S current)
        listener,
    this.child = const SizedBox.shrink(),
    this.bloc,
    this.listenWhen,
    this.take,
    this.takeWhile,
    this.debounce,
    this.throttle,
    super.key,
  })  : assert(take == null || take >= 0, 'take must be non-negative.'),
        assert(
          debounce == null || throttle == null,
          'Cannot specify both debounce and throttle.',
        ),
        _listener = null,
        _transitionListener = listener;

  /// The bloc to listen to. If null, it is looked up from the widget tree.
  final T? bloc;

  final void Function(BuildContext context, S state)? _listener;

  final void Function(BuildContext context, S previous, S current)?
      _transitionListener;

  /// The callback that runs whenever the state changes.
  void Function(BuildContext context, S state) get listener =>
      _listener ??
      (context, state) => _transitionListener!(context, state, state);

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

  /// Optional trailing-edge debounce duration.
  ///
  /// When set, [listener] is invoked only after matching emissions pause for
  /// [debounce]. Mutually exclusive with [throttle].
  final Duration? debounce;

  /// Optional leading-edge throttle duration.
  ///
  /// When set, [listener] is invoked immediately on the first matching
  /// emission, then subsequent emissions are suppressed until [throttle]
  /// elapses. Mutually exclusive with [debounce].
  final Duration? throttle;

  /// The child widget subtree.
  final Widget child;

  /// Clones this listener with a new child widget.
  @override
  BlocSignalListener<T, S> copyWith(Widget child) {
    if (_transitionListener != null) {
      return BlocSignalListener<T, S>.transition(
        key: key,
        bloc: bloc,
        listener: _transitionListener,
        listenWhen: listenWhen,
        take: take,
        takeWhile: takeWhile,
        debounce: debounce,
        throttle: throttle,
        child: child,
      );
    }
    return BlocSignalListener<T, S>(
      key: key,
      bloc: bloc,
      listener: _listener!,
      listenWhen: listenWhen,
      take: take,
      takeWhile: takeWhile,
      debounce: debounce,
      throttle: throttle,
      child: child,
    );
  }

  @override
  State<BlocSignalListener<T, S>> createState() =>
      _BlocSignalListenerState<T, S>();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<T>('bloc', bloc, defaultValue: null))
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
      )
      ..add(
        DiagnosticsProperty<Duration>('debounce', debounce, defaultValue: null),
      )
      ..add(
        DiagnosticsProperty<Duration>('throttle', throttle, defaultValue: null),
      );
  }
}

class _BlocSignalListenerState<T extends BlocSignalBase<S>, S>
    extends State<BlocSignalListener<T, S>> {
  T? _bloc;
  S? _previousState;
  EffectCleanup? _cleanup;
  Timer? _rateLimitTimer;
  S? _pendingPrevious;
  S? _pendingCurrent;
  bool _hasPendingTrailing = false;
  int _invocationCount = 0;
  bool _isDetached = false;
  bool _detachedByTakeWhile = false;

  void _validateDurations() {
    if (widget.debounce != null && widget.debounce!.isNegative) {
      throw ArgumentError.value(
        widget.debounce,
        'debounce',
        'must be non-negative',
      );
    }
    if (widget.throttle != null && widget.throttle!.isNegative) {
      throw ArgumentError.value(
        widget.throttle,
        'throttle',
        'must be non-negative',
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _validateDurations();
  }

  void _cancelRateLimit() {
    _rateLimitTimer?.cancel();
    _rateLimitTimer = null;
    _hasPendingTrailing = false;
    _pendingPrevious = null;
    _pendingCurrent = null;
  }

  void _detach() {
    _isDetached = true;
    _cancelRateLimit();
    _cleanup?.call();
    _cleanup = null;
  }

  void _dispatch(S previous, S current, {Duration? throttleDuration}) {
    if (widget.takeWhile != null && !widget.takeWhile!(current)) {
      _detachedByTakeWhile = true;
      _detach();
      return;
    }
    _invocationCount++;
    if (widget.take != null && _invocationCount >= widget.take!) {
      _detach();
    }
    if (mounted && !_isDetached && throttleDuration != null) {
      _rateLimitTimer?.cancel();
      late final Timer timer;
      timer = Timer(throttleDuration, () {
        if (identical(_rateLimitTimer, timer)) {
          _rateLimitTimer = null;
        }
      });
      _rateLimitTimer = timer;
    }
    final transitionListener = widget._transitionListener;
    if (transitionListener != null) {
      transitionListener(context, previous, current);
    } else {
      widget._listener!(context, current);
    }
  }

  void _subscribe() {
    _cleanup?.call();
    _cleanup = null;
    if (_isDetached ||
        (widget.take != null && _invocationCount >= widget.take!)) {
      _isDetached = true;
      return;
    }
    _previousState = _bloc!.state.value;
    var isInitial = true;

    _cleanup = effect(
      () {
        final currentState = _bloc!.state.value;
        if (isInitial) {
          isInitial = false;
          return;
        }
        if (!mounted || _isDetached) return;
        final previous = _previousState as S;

        if (!_bloc!.equals(previous, currentState)) {
          _previousState = currentState;

          if (widget.listenWhen == null ||
              widget.listenWhen!(previous, currentState)) {
            final debounceDuration = widget.debounce;
            if (debounceDuration != null) {
              _rateLimitTimer?.cancel();
              if (!_hasPendingTrailing) {
                _pendingPrevious = previous;
                _hasPendingTrailing = true;
              }
              _pendingCurrent = currentState;
              _rateLimitTimer = Timer(debounceDuration, () {
                _rateLimitTimer = null;
                if (!mounted || _isDetached || !_hasPendingTrailing) return;
                final pendingPrev = _pendingPrevious as S;
                final pendingCurr = _pendingCurrent as S;
                _hasPendingTrailing = false;
                _pendingPrevious = null;
                _pendingCurrent = null;
                _dispatch(pendingPrev, pendingCurr);
              });
              return;
            }

            final throttleDuration = widget.throttle;
            if (throttleDuration != null) {
              if (_rateLimitTimer?.isActive ?? false) return;
              _dispatch(
                previous,
                currentState,
                throttleDuration: throttleDuration,
              );
              return;
            }

            _dispatch(previous, currentState);
          }
        }
      },
      options: EffectOptions(name: 'BlocSignalListener<$T, $S>.effect'),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final effectiveBloc =
        widget.bloc ?? BlocSignalProvider.of<T>(context, listen: true);
    if (!identical(_bloc, effectiveBloc)) {
      _cancelRateLimit();
      _bloc = effectiveBloc;
      _invocationCount = 0;
      _isDetached = false;
      _detachedByTakeWhile = false;
      _subscribe();
    }
  }

  @override
  void didUpdateWidget(BlocSignalListener<T, S> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _validateDurations();
    final effectiveBloc =
        widget.bloc ?? BlocSignalProvider.of<T>(context, listen: true);
    if (!identical(_bloc, effectiveBloc)) {
      _cancelRateLimit();
      _bloc = effectiveBloc;
      _invocationCount = 0;
      _isDetached = false;
      _detachedByTakeWhile = false;
      _subscribe();
      return;
    }

    if (widget.debounce != oldWidget.debounce ||
        widget.throttle != oldWidget.throttle) {
      _cancelRateLimit();
    }

    final takeWhileRemoved =
        oldWidget.takeWhile != null && widget.takeWhile == null;
    if (takeWhileRemoved) {
      _detachedByTakeWhile = false;
    }

    if (widget.take != oldWidget.take || takeWhileRemoved) {
      if (_detachedByTakeWhile) {
        return;
      }
      if (widget.take != null && _invocationCount >= widget.take!) {
        _detach();
      } else if (_isDetached) {
        _isDetached = false;
        _subscribe();
      }
    }
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
