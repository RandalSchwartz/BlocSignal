import 'dart:async';

import 'package:bloc_signals/src/concurrency/mutex.dart';

/// A function handler signature for processing event [E] and emitting state
/// updates.
typedef EventHandler<E, StateType> = FutureOr<void> Function(
  E event,
  void Function(StateType state) emit,
);

/// A transformer function signature for controlling concurrency and execution
/// flow of an [EventHandler].
typedef EventTransformer<E, StateType> = FutureOr<void> Function(
  E event,
  EventHandler<E, StateType> handler,
  void Function(StateType state) emit,
);

/// Returns an [EventTransformer] that drops incoming events if a handler for
/// that event type is currently executing.
///
/// Example:
/// ```dart
/// on<SearchQuery>(
///   (event, emit) async => emit(await api.search(event.query)),
///   transformer: droppable(),
/// );
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
/// Example:
/// ```dart
/// on<CounterEvent>(
///   (event, emit) async => emit(stateValue + 1),
///   transformer: sequential(),
/// );
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
/// Example:
/// ```dart
/// on<TypeAheadQuery>(
///   (event, emit) async => emit(await api.autocomplete(event.text)),
///   transformer: restartable(),
/// );
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
