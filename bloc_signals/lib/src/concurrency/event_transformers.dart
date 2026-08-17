import 'dart:async';

import 'package:bloc_signals/src/concurrency/mutex.dart';

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
/// #### Debounce Transformer
/// Delays handler execution until a quiet period of the given duration has
/// passed:
/// ```dart
/// EventTransformer<E, S> debounce<E, S>(Duration duration) {
///   Timer? timer;
///   return (event, handler, emit) {
///     timer?.cancel();
///     timer = Timer(duration, () {
///       final result = handler(event, emit);
///       if (result is Future) {
///         unawaited(result);
///       }
///     });
///   };
/// }
/// ```
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
/// See also:
/// - [droppable], which ignores new events while a handler is in-flight.
/// - [sequential], which processes events in FIFO order using a [Mutex].
/// - [restartable], which supersedes in-flight handler executions.
typedef EventTransformer<E, StateType> = FutureOr<void> Function(
  E event,
  EventHandler<E, StateType> handler,
  void Function(StateType state) emit,
);

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
EventTransformer<E, StateType> droppable<E, StateType>() {
  var isProcessing = false;
  return (event, handler, emit) async {
    if (isProcessing) return;
    isProcessing = true;
    try {
      final result = handler(event, emit);
      if (result is Future) {
        await result;
      }
    } finally {
      isProcessing = false;
    }
  };
}

/// Returns an [EventTransformer] that queues incoming events and processes
/// them sequentially in FIFO order using a [Mutex].
///
/// Even if multiple events of type [E] arrive concurrently, each handler
/// execution runs to completion before the next queued event begins.
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
EventTransformer<E, StateType> sequential<E, StateType>() {
  final mutex = Mutex();
  return (event, handler, emit) {
    return mutex.protect(() async {
      final result = handler(event, emit);
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
EventTransformer<E, StateType> restartable<E, StateType>() {
  var executionToken = 0;
  return (event, handler, emit) async {
    final currentToken = ++executionToken;
    final result = handler(
      event,
      (state) {
        if (currentToken == executionToken) {
          emit(state);
        }
      },
    );
    if (result is Future) {
      await result;
    }
  };
}
