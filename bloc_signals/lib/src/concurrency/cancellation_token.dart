import 'dart:async';

import 'package:bloc_signals/src/bloc_signals_base.dart';
import 'package:meta/meta.dart';

/// Internal mutable slot stored in `BlocSignalMixin.add`'s zone values so
/// `restartable()` can bind a [CancellationToken] without allocating an extra
/// `runZoned` wrapper on the synchronous fast-path.
@internal
final class CancellationTokenSlot {
  /// The active [CancellationToken] for the current dispatch zone, if any.
  CancellationToken? token;
}

/// A cooperative cancellation token bound to the current [Zone] during
/// cancelable event handler execution (such as `restartable()`).
///
/// Handlers can poll [isCanceled] after asynchronous `await` gaps or register
/// LIFO cleanup callbacks with [onCancel] to abort in-flight HTTP requests,
/// timers, or stream subscriptions when superseded or when the host container
/// closes.
///
/// ```dart
/// class SearchBloc extends BlocSignal<SearchEvent, SearchState> {
///   SearchBloc() : super(initialState: SearchInitial()) {
///     on<QueryChanged>(
///       (event, emit) async {
///         final token = CancellationToken.current;
///         final timer = Timer(const Duration(seconds: 1), () {});
///         token?.onCancel(timer.cancel);
///
///         await Future<void>.delayed(const Duration(milliseconds: 50));
///         if (token?.isCanceled ?? false) return;
///         emit(SearchLoaded(event.query));
///       },
///       transformer: restartable(),
///     );
///   }
/// }
/// ```
final class CancellationToken {
  /// Creates a new [CancellationToken] bound to an optional [host] container
  /// and captured [zone].
  @internal
  CancellationToken({
    required Zone zone,
    BlocSignalBase<dynamic>? host,
  })  : _host = host,
        _zone = zone;

  final BlocSignalBase<dynamic>? _host;
  Zone _zone;
  bool _isCanceled = false;
  List<void Function()>? _callbacks;

  /// Rebinds the captured execution [zone] for this token when a fallback
  /// `runZoned` wrapper is used.
  @internal
  // Method form clarifies imperative Zone binding in fallback paths.
  // ignore: use_setters_to_change_properties
  void bindZone(Zone zone) {
    _zone = zone;
  }

  /// Returns the [CancellationToken] bound to the current [Zone], or `null`
  /// if no cancelable handler is active.
  ///
  /// ```dart
  /// final token = CancellationToken.current;
  /// if (token?.isCanceled ?? false) return;
  /// ```
  static CancellationToken? get current {
    final value = Zone.current[BlocSignalBase.ambientZoneCancellationTokenKey];
    if (value is CancellationTokenSlot) {
      return value.token;
    }
    if (value is CancellationToken) {
      return value;
    }
    return null;
  }

  /// Whether this token has been canceled due to event preemption or container
  /// disposal.
  bool get isCanceled => _isCanceled;

  /// Registers a synchronous [cleanup] callback to run in LIFO (last-in,
  /// first-out) order when this token is canceled.
  ///
  /// If [isCanceled] is already `true`, [cleanup] is invoked immediately and
  /// synchronously.
  void onCancel(void Function() cleanup) {
    if (_isCanceled) {
      _runCallback(cleanup);
      return;
    }
    (_callbacks ??= <void Function()>[]).add(cleanup);
  }

  /// Marks this token as canceled and executes all registered cleanup callbacks
  /// synchronously in LIFO order inside the captured handler [Zone].
  ///
  /// Repeated calls are idempotent no-ops. Exceptions thrown by individual
  /// cleanup callbacks are isolated via [BlocSignalBase.onError] (or the
  /// captured [Zone] when no host is bound) so remaining callbacks and
  /// container disposal continue uninterrupted.
  @internal
  void cancel() {
    if (_isCanceled) return;
    _isCanceled = true;
    final callbacks = _callbacks;
    if (callbacks == null) return;
    _callbacks = null;

    _zone.run(() {
      for (var i = callbacks.length - 1; i >= 0; i--) {
        _runCallback(callbacks[i]);
      }
    });
  }

  void _runCallback(void Function() callback) {
    try {
      callback();
    } on Exception catch (error, stackTrace) {
      if (_host != null) {
        reportContainerError(_host, error, stackTrace);
      } else {
        _zone.handleUncaughtError(error, stackTrace);
      }
    }
  }
}

/// Whether the current cancelable event handler has been canceled.
///
/// Returns `false` when called outside a cancelable transformer (such as
/// `restartable()`).
///
/// ```dart
/// on<FetchData>(
///   (event, emit) async {
///     final result = await api.fetch();
///     if (isCanceled) return;
///     emit(DataLoaded(result));
///   },
///   transformer: restartable(),
/// );
/// ```
bool get isCanceled => CancellationToken.current?.isCanceled ?? false;

/// Registers a synchronous [cleanup] callback for the current cancelable event
/// handler.
///
/// Callbacks run in LIFO (last-in, first-out) order inside the handler's
/// captured [Zone] when the handler is superseded by a newer event or when the
/// host container closes. If the handler is already canceled, [cleanup] runs
/// immediately and synchronously. Calling [onCancel] outside a cancelable
/// transformer is a safe no-op.
///
/// ```dart
/// on<FetchData>(
///   (event, emit) async {
///     final client = HttpClient();
///     onCancel(() => client.close(force: true));
///     final data = await client.get(event.uri);
///     if (isCanceled) return;
///     emit(DataLoaded(data));
///   },
///   transformer: restartable(),
/// );
/// ```
void onCancel(void Function() cleanup) {
  CancellationToken.current?.onCancel(cleanup);
}
