import 'dart:async';

import 'package:bloc_signals/src/bloc_signals_base.dart';
import 'package:bloc_signals/src/bloc_telemetry_keys.dart';
import 'package:bloc_signals/src/concurrency/mutex.dart';

const _droppableDroppedMetadata = <String, dynamic>{
  'transformer': 'droppable',
  'reason': 'in_flight',
};

const _restartablePreemptedMetadata = <String, dynamic>{
  'transformer': 'restartable',
  'reason': 'superseded',
};

const _debounceCoalescedMetadata = <String, dynamic>{
  'transformer': 'debounce',
  'reason': 'coalesced',
};

const _throttleDroppedMetadata = <String, dynamic>{
  'transformer': 'throttle',
  'reason': 'throttled',
};

const _throttleCoalescedMetadata = <String, dynamic>{
  'transformer': 'throttle',
  'reason': 'coalesced',
};

BlocSignalBase<dynamic>? _resolveHost(BlocSignalBase<dynamic>? bloc) =>
    bloc ??
    (Zone.current[BlocSignalBase.ambientZoneBlocKey]
        as BlocSignalBase<dynamic>?);

void Function(StateType) _guardedEmit<StateType>(
  BlocSignalBase<dynamic>? host,
  void Function(StateType) emit,
) {
  return (state) {
    if (host != null && host.isClosed) return;
    emit(state);
  };
}

void _executeAndSettle<E, StateType>({
  required E event,
  required EventHandler<E, StateType> handler,
  required void Function(StateType) emit,
  required BlocSignalBase<dynamic>? host,
  required Zone zone,
  required Completer<void> completer,
}) {
  zone.run(() {
    try {
      final result = handler(event, _guardedEmit(host, emit));
      if (result is Future) {
        unawaited(
          result.then<void>(
            (_) {
              if (!completer.isCompleted) {
                completer.complete();
              }
            },
            onError: (Object error, StackTrace stackTrace) {
              if (!completer.isCompleted) {
                completer.completeError(error, stackTrace);
              }
            },
          ),
        );
      } else if (!completer.isCompleted) {
        completer.complete();
      }
      // Intentional `on Object catch` (SCAR-ERR-02): forward synchronous
      // handler throwables to the tracked Completer so `BlocSignalMixin`
      // routes them to `onError` and `onEventCompleted`.
    } on Object catch (error, stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
    }
  });
}

/// A function handler signature for processing event [E] and emitting state
/// updates.
///
/// Handlers can be synchronous or asynchronous (returning a [FutureOr]).
typedef EventHandler<E, StateType> = FutureOr<void> Function(
  E event,
  void Function(StateType state) emit,
);

/// A transformer function signature for controlling concurrency and execution
/// flow of an [EventHandler].
///
/// In `BlocSignal`, event transformers are **streamless higher-order
/// functions** rather than stream operators. Unlike classic `package:bloc`
/// which transforms incoming `Stream<Event>` pipelines using Rx operators,
/// `BlocSignal` passes each incoming [event], its target [handler], and the
/// [emit] callback directly to the transformer.
///
/// This streamless architecture eliminates `StreamController` and subscription
/// allocations while executing handlers synchronously when possible.
///
/// ### Writing a Custom Event Transformer
///
/// Custom transformers wrap the invocation of `handler(event, emit)` using
/// standard Dart primitives such as [Timer], [Mutex], or conditional guards.
///
/// #### Filter / Predicate Transformer
/// Executes the handler only when a given condition on [event] is satisfied:
/// ```dart
/// EventTransformer<E, S> filterEvents<E, S>(bool Function(E) predicate) {
///   return (event, handler, emit) {
///     if (predicate(event)) {
///       return handler(event, emit);
///     }
///   };
/// }
/// ```
///
/// #### Sample / Delay Transformer
/// Delays handler execution by a fixed `duration` while tracking completion
/// via a [Completer] so asynchronous errors route to `onError`:
/// ```dart
/// EventTransformer<E, S> delayEvents<E, S>(Duration duration) {
///   return (event, handler, emit) {
///     final completer = Completer<void>();
///     Timer(duration, () async {
///       try {
///         await handler(event, emit);
///         completer.complete();
///       } on Object catch (error, stackTrace) {
///         completer.completeError(error, stackTrace);
///       }
///     });
///     return completer.future;
///   };
/// }
/// ```
///
/// See also:
/// - [concurrent], which processes incoming events concurrently.
/// - [droppable], which ignores new events while a handler is in-flight.
/// - [sequential], which processes events in FIFO order using a [Mutex].
/// - [restartable], which supersedes in-flight handler executions.
/// - [debounce], which delays execution until a quiet period elapses.
/// - [throttle], which rate-limits execution to at most once per window.
typedef EventTransformer<E, StateType> = FutureOr<void> Function(
  E event,
  EventHandler<E, StateType> handler,
  void Function(StateType state) emit,
);

/// A transformer function signature for controlling concurrency and execution
/// flow with access to the host [bloc] instance.
///
/// In `BlocSignal`, contextual event transformers receive the host [bloc]
/// instance as their first argument, allowing access to
/// [BlocSignalBase.stateValue], operational telemetry
/// ([BlocSignalBase.emitTelemetry]), and container metadata without manual
/// closure captures or instance plumbing.
///
/// ### Example
/// ```dart
/// BlocEventTransformer<E, S> droppableWithTelemetry<E, S>() {
///   var isProcessing = false;
///   return (bloc, event, handler, emit) async {
///     if (isProcessing) {
///       bloc.emitTelemetry(
///         BlocTelemetryKeys.eventDropped,
///         event: event,
///         metadata: const {'reason': 'in_flight'},
///       );
///       return;
///     }
///     isProcessing = true;
///     try {
///       final result = handler(event, emit);
///       if (result is Future) {
///         await result;
///       }
///     } finally {
///       isProcessing = false;
///     }
///   };
/// }
/// ```
///
/// See also:
/// - [EventTransformer], the standard 3-parameter transformer signature.
/// - [EventTransformerExtension.toBlocTransformer], which lifts an
///   [EventTransformer] into a [BlocEventTransformer].
/// - `withBloc`, which adapts a [BlocEventTransformer] to a
///   standard [EventTransformer].
typedef BlocEventTransformer<E, StateType> = FutureOr<void> Function(
  BlocSignalBase<StateType> bloc,
  E event,
  EventHandler<E, StateType> handler,
  void Function(StateType state) emit,
);

/// Extension methods for converting between transformer representations.
extension EventTransformerExtension<E, StateType>
    on EventTransformer<E, StateType> {
  /// Lifts this 3-parameter [EventTransformer] into a contextual 4-parameter
  /// [BlocEventTransformer] that ignores the host bloc argument.
  ///
  /// This allows standard transformers (such as [droppable] or [sequential])
  /// to be passed directly to APIs expecting a [BlocEventTransformer].
  ///
  /// ```dart
  /// on<SearchQueryChanged>(
  ///   _onSearchQueryChanged,
  ///   blocTransformer: droppable<SearchQueryChanged, SearchState>()
  ///       .toBlocTransformer(),
  /// );
  /// ```
  BlocEventTransformer<E, StateType> toBlocTransformer() =>
      (bloc, event, handler, emit) => this(event, handler, emit);
}

/// Returns an [EventTransformer] that drops incoming events if a handler for
/// that event type is currently executing.
///
/// Once the active handler completes (whether synchronously or asynchronously),
/// subsequent incoming events will be processed normally.
///
/// ### Example
/// ```dart
/// class SearchBloc extends BlocSignal<SearchEvent, SearchState> {
///   SearchBloc() : super(initialState: SearchInitial()) {
///     on<SearchSubmitted>(
///       (event, emit) async {
///         emit(SearchLoading());
///         final results = await api.search(event.query);
///         emit(SearchSuccess(results));
///       },
///       transformer: droppable(),
///     );
///   }
/// }
/// ```
EventTransformer<E, StateType> droppable<E, StateType>({
  BlocSignalBase<dynamic>? bloc,
}) {
  var isProcessing = false;
  return (event, handler, emit) {
    if (isProcessing) {
      if (BlocSignalObserver.observer != null) {
        final host = bloc ??
            (Zone.current[BlocSignalBase.ambientZoneBlocKey]
                as BlocSignalBase<dynamic>?);
        if (host != null) {
          emitContainerTelemetry(
            host,
            BlocTelemetryKeys.eventDropped,
            event: event,
            metadata: _droppableDroppedMetadata,
          );
        }
      }
      return null;
    }
    isProcessing = true;
    try {
      final result = handler(event, emit);
      if (result is Future) {
        return result.whenComplete(() {
          isProcessing = false;
        });
      }
      isProcessing = false;
      // Intentional `on Object catch` (SCAR-ERR-02): reset `isProcessing`
      // concurrency flag before rethrowing any synchronous `Exception` or
      // `Error` so subsequent events are never permanently dropped.
    } on Object catch (_) {
      isProcessing = false;
      rethrow;
    }
  };
}

/// Returns an [EventTransformer] that queues incoming events and processes
/// them sequentially in FIFO order using a [Mutex].
///
/// Even if multiple events of type [E] arrive concurrently, each handler
/// execution runs to completion before the next queued event begins.
///
/// Optionally accepts an explicit host [bloc] reference to emit operational
/// telemetry ([BlocTelemetryKeys.eventQueued]) and record queue wait latencies.
/// If omitted, ambient zone resolution is used.
///
/// ### Example
/// ```dart
/// class CounterBloc extends BlocSignal<CounterEvent, int> {
///   CounterBloc() : super(initialState: 0) {
///     on<IncrementAsync>(
///       (event, emit) async {
///         await Future<void>.delayed(const Duration(milliseconds: 100));
///         emit(stateValue + 1);
///       },
///       transformer: sequential(),
///     );
///   }
/// }
/// ```
EventTransformer<E, StateType> sequential<E, StateType>({
  BlocSignalBase<dynamic>? bloc,
}) {
  final mutex = Mutex();
  return (event, handler, emit) {
    final host = bloc ??
        (Zone.current[BlocSignalBase.ambientZoneBlocKey]
            as BlocSignalBase<dynamic>?);
    if (host != null && host.isClosed) {
      return null;
    }
    final isQueued = mutex.isLocked;
    final stopwatch = isQueued && BlocSignalObserver.observer != null
        ? (Stopwatch()..start())
        : null;

    return mutex.protect(() async {
      if (host != null && host.isClosed) {
        return;
      }
      if (stopwatch != null) {
        stopwatch.stop();
        if (host != null) {
          emitContainerTelemetry(
            host,
            BlocTelemetryKeys.eventQueued,
            event: event,
            metadata: {
              'transformer': 'sequential',
              'queue_wait_ms': stopwatch.elapsedMilliseconds,
            },
          );
        }
      }
      final result = handler(
        event,
        (state) {
          if (host != null && host.isClosed) return;
          emit(state);
        },
      );
      if (result is Future) {
        await result;
      }
    });
  };
}

/// Returns an [EventTransformer] that allows new incoming events to supersede
/// previous in-flight handler executions, dropping state emissions from older
/// executions.
///
/// When a new event arrives, an internal generation token is incremented.
/// State emissions produced by earlier, in-flight handlers whose generation
/// token does not match the latest token are discarded automatically.
///
/// Optionally accepts an explicit host [bloc] reference to emit operational
/// telemetry ([BlocTelemetryKeys.taskPreempted]) when an in-flight execution is
/// superseded. If omitted, ambient zone resolution is used.
///
/// ### Example
/// ```dart
/// class AutocompleteBloc extends BlocSignal<QueryEvent, AutocompleteState> {
///   AutocompleteBloc() : super(initialState: AutocompleteInitial()) {
///     on<TextChanged>(
///       (event, emit) async {
///         emit(AutocompleteLoading());
///         final suggestions = await api.fetchSuggestions(event.query);
///         emit(AutocompleteLoaded(suggestions));
///       },
///       transformer: restartable(),
///     );
///   }
/// }
/// ```
EventTransformer<E, StateType> restartable<E, StateType>({
  BlocSignalBase<dynamic>? bloc,
}) {
  var executionToken = 0;
  int? activeExecutionToken;
  E? activeEvent;
  return (event, handler, emit) {
    if (activeExecutionToken != null && BlocSignalObserver.observer != null) {
      final host = bloc ??
          (Zone.current[BlocSignalBase.ambientZoneBlocKey]
              as BlocSignalBase<dynamic>?);
      if (host != null) {
        emitContainerTelemetry(
          host,
          BlocTelemetryKeys.taskPreempted,
          event: activeEvent,
          metadata: _restartablePreemptedMetadata,
        );
      }
    }
    final currentToken = ++executionToken;
    activeExecutionToken = currentToken;
    activeEvent = event;

    void onComplete() {
      if (activeExecutionToken == currentToken) {
        activeExecutionToken = null;
        activeEvent = null;
      }
    }

    try {
      final result = handler(
        event,
        (state) {
          if (currentToken == executionToken) {
            emit(state);
          }
        },
      );
      if (result is Future) {
        return result.whenComplete(onComplete);
      }
      onComplete();
      // Intentional `on Object catch` (SCAR-ERR-02): clear active execution
      // token on synchronous `Exception` or `Error` before rethrowing.
    } on Object catch (_) {
      onComplete();
      rethrow;
    }
  };
}

/// Returns an [EventTransformer] that processes incoming events concurrently
/// without queueing, dropping, or superseding in-flight executions.
///
/// Each incoming event dispatches immediately to its handler. Emissions after
/// the host container is closed are safely suppressed.
///
/// Optionally accepts an explicit host [bloc] reference; if omitted, ambient
/// zone resolution is used.
///
/// ### Example
/// ```dart
/// class NotificationBloc
///     extends BlocSignal<NotificationEvent, List<String>> {
///   NotificationBloc() : super(initialState: const []) {
///     on<FetchNotification>(
///       (event, emit) async {
///         final item = await api.fetch(event.id);
///         emit([...stateValue, item]);
///       },
///       transformer: concurrent(),
///     );
///   }
/// }
/// ```
EventTransformer<E, StateType> concurrent<E, StateType>({
  BlocSignalBase<dynamic>? bloc,
}) {
  return (event, handler, emit) {
    final host = _resolveHost(bloc);
    if (host != null && host.isClosed) {
      return null;
    }
    return handler(event, _guardedEmit(host, emit));
  };
}

/// Returns an [EventTransformer] that delays processing incoming events until
/// [duration] has elapsed without another event arriving.
///
/// Rapid bursts are coalesced so only the latest event executes. Superseded
/// events emit [BlocTelemetryKeys.eventDropped] with `reason: 'coalesced'` and
/// complete cleanly. Pending timers are automatically cancelled when the host
/// container closes.
///
/// Optionally accepts an explicit host [bloc] reference; if omitted, ambient
/// zone resolution is used.
///
/// ### Example
/// ```dart
/// class SearchBloc extends BlocSignal<SearchEvent, SearchState> {
///   SearchBloc() : super(initialState: SearchInitial()) {
///     on<SearchQueryChanged>(
///       (event, emit) async {
///         final results = await api.search(event.query);
///         emit(SearchLoaded(results));
///       },
///       transformer: debounce(const Duration(milliseconds: 300)),
///     );
///   }
/// }
/// ```
EventTransformer<E, StateType> debounce<E, StateType>(
  Duration duration, {
  BlocSignalBase<dynamic>? bloc,
}) {
  Timer? timer;
  Completer<void>? pendingCompleter;
  E? pendingEvent;
  Zone? pendingZone;
  final registeredHosts = Expando<bool>();

  void cancelPending() {
    timer?.cancel();
    timer = null;
    pendingEvent = null;
    pendingZone = null;
    final completer = pendingCompleter;
    pendingCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  return (event, handler, emit) {
    final host = _resolveHost(bloc);
    if (host != null && host.isClosed) {
      return null;
    }
    if (host != null && registeredHosts[host] == null) {
      registeredHosts[host] = true;
      host.registerCloseCallback(cancelPending);
    }

    while (timer?.isActive ?? false) {
      timer?.cancel();
      timer = null;
      final prevEvent = pendingEvent;
      final prevZone = pendingZone;
      final prevCompleter = pendingCompleter;
      pendingEvent = null;
      pendingZone = null;
      pendingCompleter = null;

      if (prevCompleter != null && !prevCompleter.isCompleted) {
        prevCompleter.complete();
      }
      if (host != null && BlocSignalObserver.observer != null) {
        (prevZone ?? Zone.current).run(() {
          emitContainerTelemetry(
            host,
            BlocTelemetryKeys.eventDropped,
            event: prevEvent,
            metadata: _debounceCoalescedMetadata,
          );
        });
      }
      if (host != null && host.isClosed) {
        return null;
      }
    }

    final eventZone = Zone.current;
    final completer = Completer<void>();
    pendingCompleter = completer;
    pendingEvent = event;
    pendingZone = eventZone;

    timer = Timer(duration, () {
      timer = null;
      pendingEvent = null;
      pendingZone = null;
      if (identical(pendingCompleter, completer)) {
        pendingCompleter = null;
      }
      if (host != null && host.isClosed) {
        if (!completer.isCompleted) {
          completer.complete();
        }
        return;
      }
      _executeAndSettle(
        event: event,
        handler: handler,
        emit: emit,
        host: host,
        zone: eventZone,
        completer: completer,
      );
    });

    return completer.future;
  };
}

/// Returns an [EventTransformer] that rate-limits incoming events to execute
/// at most once per [duration] window.
///
/// By default (`trailing: false`), the first event executes immediately and any
/// events arriving during the cooldown [duration] are dropped with
/// [BlocTelemetryKeys.eventDropped] (`reason: 'throttled'`).
///
/// When [trailing] is `true`, events arriving during the cooldown window
/// coalesce into a single trailing slot (superseding any prior queued trailing
/// event with `reason: 'coalesced'`) and the latest queued event executes when
/// the cooldown expires. Active cooldown timers are cancelled automatically
/// when the host container closes.
///
/// Optionally accepts an explicit host [bloc] reference; if omitted, ambient
/// zone resolution is used.
///
/// ### Example
/// ```dart
/// class ScrollBloc extends BlocSignal<ScrollEvent, ScrollState> {
///   ScrollBloc() : super(initialState: ScrollInitial()) {
///     on<ScrollUpdated>(
///       (event, emit) => emit(ScrollState(offset: event.offset)),
///       transformer: throttle(
///         const Duration(milliseconds: 100),
///         trailing: true,
///       ),
///     );
///   }
/// }
/// ```
EventTransformer<E, StateType> throttle<E, StateType>(
  Duration duration, {
  bool trailing = false,
  BlocSignalBase<dynamic>? bloc,
}) {
  Timer? cooldownTimer;
  Completer<void>? trailingCompleter;
  E? trailingEvent;
  EventHandler<E, StateType>? trailingHandler;
  void Function(StateType)? trailingEmit;
  BlocSignalBase<dynamic>? trailingHost;
  Zone? trailingZone;
  final registeredHosts = Expando<bool>();

  void cancelPending() {
    cooldownTimer?.cancel();
    cooldownTimer = null;
    trailingEvent = null;
    trailingHandler = null;
    trailingEmit = null;
    trailingHost = null;
    trailingZone = null;
    final completer = trailingCompleter;
    trailingCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  void startCooldown() {
    void onExpired() {
      cooldownTimer = null;
      final completer = trailingCompleter;
      if (completer == null) {
        return;
      }
      final event = trailingEvent as E;
      final handler = trailingHandler!;
      final emit = trailingEmit!;
      final host = trailingHost;
      final zone = trailingZone!;
      trailingEvent = null;
      trailingHandler = null;
      trailingEmit = null;
      trailingHost = null;
      trailingZone = null;
      trailingCompleter = null;

      if (host != null && host.isClosed) {
        if (!completer.isCompleted) {
          completer.complete();
        }
        return;
      }

      cooldownTimer = zone.run(() => Timer(duration, onExpired));
      _executeAndSettle(
        event: event,
        handler: handler,
        emit: emit,
        host: host,
        zone: zone,
        completer: completer,
      );
    }

    cooldownTimer = Timer(duration, onExpired);
  }

  return (event, handler, emit) {
    final host = _resolveHost(bloc);
    if (host != null && host.isClosed) {
      return null;
    }
    if (host != null && registeredHosts[host] == null) {
      registeredHosts[host] = true;
      host.registerCloseCallback(cancelPending);
    }

    if (cooldownTimer?.isActive ?? false) {
      if (!trailing) {
        if (host != null && BlocSignalObserver.observer != null) {
          emitContainerTelemetry(
            host,
            BlocTelemetryKeys.eventDropped,
            event: event,
            metadata: _throttleDroppedMetadata,
          );
        }
        return null;
      }

      while (trailingCompleter != null) {
        final prevEvent = trailingEvent;
        final prevZone = trailingZone;
        final prevCompleter = trailingCompleter!;
        trailingEvent = null;
        trailingHandler = null;
        trailingEmit = null;
        trailingHost = null;
        trailingZone = null;
        trailingCompleter = null;

        if (!prevCompleter.isCompleted) {
          prevCompleter.complete();
        }
        if (host != null && BlocSignalObserver.observer != null) {
          (prevZone ?? Zone.current).run(() {
            emitContainerTelemetry(
              host,
              BlocTelemetryKeys.eventDropped,
              event: prevEvent,
              metadata: _throttleCoalescedMetadata,
            );
          });
        }
        if (host != null && host.isClosed) {
          return null;
        }
      }

      final completer = Completer<void>();
      trailingCompleter = completer;
      trailingEvent = event;
      trailingHandler = handler;
      trailingEmit = emit;
      trailingHost = host;
      trailingZone = Zone.current;
      return completer.future;
    }

    startCooldown();
    return handler(event, _guardedEmit(host, emit));
  };
}
