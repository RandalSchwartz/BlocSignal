import 'package:a2ui_core/a2ui_core.dart';
import 'package:bloc_signals_genui/src/a2ui_action_response.dart'
    show A2uiActionResponse;
import 'package:bloc_signals_genui/src/a2ui_surface_bloc.dart'
    show A2uiSurfaceBloc;
import 'package:bloc_signals_genui/src/a2ui_surface_state.dart'
    show SurfaceInitial, SurfaceReady;
import 'package:meta/meta.dart';

/// Sealed hierarchy defining events dispatched to [A2uiSurfaceBloc].
///
/// Uses polymorphic protocol envelopes (`ProcessMessage`, `ProcessJsonMessage`,
/// `IngestStream`) to guarantee full future-compatibility with new A2UI message
/// types without fragile wire-format version lock-in.
@immutable
sealed class A2uiSurfaceEvent {
  /// Const base constructor for [A2uiSurfaceEvent].
  const A2uiSurfaceEvent();
}

/// Ingests an incoming asynchronous stream of A2UI messages, raw JSON strings,
/// or parsed JSON maps. Handled with `restartable()` concurrency protection to
/// automatically cancel in-flight streams upon user interruption or re-prompting.
final class IngestStream extends A2uiSurfaceEvent {
  /// Creates an [IngestStream] event.
  const IngestStream(this.stream);

  /// The asynchronous stream yielding A2UI chunks or messages.
  final Stream<dynamic> stream;
}

/// Ingests a single typed [A2uiMessage] (for example [CreateSurfaceMessage],
/// [UpdateComponentsMessage], [UpdateDataModelMessage], or [DeleteSurfaceMessage]).
final class ProcessMessage extends A2uiSurfaceEvent {
  /// Creates a [ProcessMessage] event.
  const ProcessMessage(this.message);

  /// The typed A2UI message instance.
  final A2uiMessage message;
}

/// Ingests a raw JSON envelope map representing an A2UI message.
final class ProcessJsonMessage extends A2uiSurfaceEvent {
  /// Creates a [ProcessJsonMessage] event.
  const ProcessJsonMessage(this.json);

  /// The raw JSON map to be parsed into an [A2uiMessage].
  final Map<String, dynamic> json;
}

/// Batch processes a list of [A2uiMessage]s atomically.
final class ProcessMessages extends A2uiSurfaceEvent {
  /// Creates a [ProcessMessages] event.
  const ProcessMessages(this.messages);

  /// The collection of A2UI messages to process.
  final List<A2uiMessage> messages;
}

/// Explicit event notifying the bloc that the current message stream has ended
/// and the surface should finalize and transition into [SurfaceReady].
final class StreamCompleted extends A2uiSurfaceEvent {
  /// Creates a [StreamCompleted] event.
  const StreamCompleted({this.surfaceId});

  /// The identifier of the finalized surface, if specified.
  final String? surfaceId;
}

/// Updates a form field value synchronously in the active surface's data model.
final class UpdateFormField extends A2uiSurfaceEvent {
  /// Creates an [UpdateFormField] event.
  const UpdateFormField({
    required this.path,
    required this.value,
    this.surfaceId,
  });

  /// The hierarchical JSON path (for example `/user/name` or `/booking/flightId`).
  final String path;

  /// The updated value to set at [path].
  final Object? value;

  /// The identifier of the target surface, if multiple surfaces exist.
  final String? surfaceId;
}

/// Submits an action from an active component (such as a submit button) on
/// the surface, packaging current form data into an [A2uiActionResponse].
final class SubmitAction extends A2uiSurfaceEvent {
  /// Creates a [SubmitAction] event.
  const SubmitAction({
    required this.actionName,
    required this.sourceComponentId,
    this.surfaceId,
    this.context = const {},
  });

  /// The name of the action to invoke.
  final String actionName;

  /// The identifier of the component triggering the submission.
  final String sourceComponentId;

  /// The identifier of the target surface.
  final String? surfaceId;

  /// Any additional contextual payload provided by the component.
  final Map<String, dynamic> context;
}

/// Resets the surface and message processor back to [SurfaceInitial].
final class ResetSurface extends A2uiSurfaceEvent {
  /// Creates a [ResetSurface] event.
  const ResetSurface({this.surfaceId});

  /// The optional identifier of a specific surface to reset, or null for all.
  final String? surfaceId;
}

/// Cancels an in-flight action submission, restoring the surface to [SurfaceReady]
/// while preserving entered form inputs.
///
/// If [error] is provided, it is added to [SurfaceReady.validationErrors] and
/// [SurfaceReady.isValid] is set to `false`.
///
/// ```dart
/// // Example: aborting submission due to timeout or network drop
/// surfaceBloc.add(
///   const CancelSubmission(
///     error: 'Submission timed out. Please try again.',
///   ),
/// );
/// ```
final class CancelSubmission extends A2uiSurfaceEvent {
  /// Creates a [CancelSubmission] event.
  const CancelSubmission({this.error, this.surfaceId});

  /// An optional error or cancellation message to display on the surface.
  final String? error;

  /// The identifier of the surface to recover, or null to target the active surface.
  final String? surfaceId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CancelSubmission &&
          error == other.error &&
          surfaceId == other.surfaceId;

  @override
  int get hashCode => Object.hash(error, surfaceId);

  @override
  String toString() => 'CancelSubmission(surfaceId: $surfaceId, error: $error)';
}

/// Completes an in-flight action submission, returning the surface to [SurfaceReady].
///
/// If [error] is provided, the action is treated as failed: [SurfaceReady.isValid]
/// becomes `false` and [error] is appended to [SurfaceReady.validationErrors].
/// If [error] is null, the action completed successfully without streaming new UI.
///
/// ```dart
/// // Example: agent tool completed without changing the UI
/// surfaceBloc.add(const CompleteAction());
/// ```
final class CompleteAction extends A2uiSurfaceEvent {
  /// Creates a [CompleteAction] event.
  const CompleteAction({this.error, this.surfaceId});

  /// An optional error message if the action execution failed.
  final String? error;

  /// The identifier of the surface to recover, or null to target the active surface.
  final String? surfaceId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CompleteAction &&
          error == other.error &&
          surfaceId == other.surfaceId;

  @override
  int get hashCode => Object.hash(error, surfaceId);

  @override
  String toString() => 'CompleteAction(surfaceId: $surfaceId, error: $error)';
}
