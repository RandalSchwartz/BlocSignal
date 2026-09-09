import 'package:bloc_signals/src/concurrency/event_transformers.dart';

/// Standard telemetry event names emitted by built-in concurrency transformers
/// and operational diagnostic pipelines.
///
/// Use these catalog keys rather than raw string literals to maintain
/// consistency across metrics dashboards, OpenTelemetry collectors, and
/// test assertions.
///
/// ```dart
/// expectTelemetry: () => [
///   isTelemetry(
///     BlocTelemetryKeys.eventDropped,
///     metadata: {'reason': 'in_flight'},
///   ),
/// ];
/// ```
abstract final class BlocTelemetryKeys {
  /// Emitted when a concurrency transformer (such as [droppable]) discards an
  /// incoming event because an existing handler is currently executing.
  static const String eventDropped = 'event_dropped';

  /// Emitted when a concurrency transformer (such as [restartable]) cancels or
  /// supersedes an in-flight execution upon the arrival of a newer event.
  static const String taskPreempted = 'task_preempted';

  /// Emitted when an in-flight task execution is explicitly canceled before
  /// completion.
  static const String taskCanceled = 'task_canceled';

  /// Emitted when an incoming event is enqueued by a sequential or buffered
  /// concurrency transformer (such as [sequential]).
  static const String eventQueued = 'event_queued';
}
