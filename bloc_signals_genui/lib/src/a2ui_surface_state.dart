import 'package:a2ui_core/a2ui_core.dart';
import 'package:bloc_signals_genui/src/a2ui_surface_bloc.dart'
    show A2uiSurfaceBloc;
import 'package:bloc_signals_genui/src/deep_collection_equality.dart';
import 'package:meta/meta.dart';

/// Sealed hierarchy defining the client-side presentation lifecycle of an
/// A2UI surface managed by [A2uiSurfaceBloc].
@immutable
sealed class A2uiSurfaceState {
  /// Const base constructor for [A2uiSurfaceState].
  const A2uiSurfaceState();

  /// The surface identifier associated with this state snapshot, if any.
  String? get surfaceId;
}

/// Initial resting state before any A2UI stream or surface message has been received.
final class SurfaceInitial extends A2uiSurfaceState {
  /// Creates a [SurfaceInitial] state.
  const SurfaceInitial();

  @override
  String? get surfaceId => null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SurfaceInitial;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'SurfaceInitial()';
}

/// State emitted while A2UI declarative JSON chunks or message envelopes are
/// actively arriving across the wire or stream buffer.
final class SurfaceStreaming extends A2uiSurfaceState {
  /// Creates a [SurfaceStreaming] state.
  const SurfaceStreaming({
    this.surfaceId,
    this.messageCount = 0,
    this.progress,
  });

  /// The identifier of the active surface being streamed, if known.
  @override
  final String? surfaceId;

  /// The cumulative count of A2UI messages processed so far during this stream.
  final int messageCount;

  /// An optional progress indicator normalized between 0.0 and 1.0.
  final double? progress;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SurfaceStreaming &&
          surfaceId == other.surfaceId &&
          messageCount == other.messageCount &&
          progress == other.progress;

  @override
  int get hashCode => Object.hash(surfaceId, messageCount, progress);

  @override
  String toString() =>
      'SurfaceStreaming(surfaceId: $surfaceId, count: $messageCount, progress: $progress)';
}

/// State emitted when the surface is fully hydrated with populated components,
/// validated against the component catalog, and ready for user viewing and form
/// interaction.
///
/// A component-less surface remains in [SurfaceStreaming] until its component
/// tree is populated, eliminating UI flicker between message and stream paths.
final class SurfaceReady extends A2uiSurfaceState {
  /// Creates a [SurfaceReady] state.
  const SurfaceReady({
    required this.surfaceId,
    required this.surface,
    this.availableSurfaceIds = const [],
    this.formValues = const {},
    this.isValid = true,
    this.validationErrors = const [],
    this.version = 0,
  });

  /// The unique identifier of this active surface.
  @override
  final String surfaceId;

  /// The underlying [SurfaceModel] instance from `a2ui_core`.
  final SurfaceModel<ComponentApi> surface;

  /// All surface identifiers currently discovered and available in the message processor.
  final List<String> availableSurfaceIds;

  /// Synchronously captured key-value form field inputs.
  final Map<String, dynamic> formValues;

  /// Whether all current form values pass local catalog validation.
  final bool isValid;

  /// Any active validation error messages associated with form inputs.
  final List<String> validationErrors;

  /// Monotonically increasing revision counter to signal component updates
  /// even when the underlying mutable [surface] object reference is unchanged.
  final int version;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SurfaceReady &&
          surfaceId == other.surfaceId &&
          identical(surface, other.surface) &&
          isValid == other.isValid &&
          version == other.version &&
          deepEquals(availableSurfaceIds, other.availableSurfaceIds) &&
          deepEquals(formValues, other.formValues) &&
          deepEquals(validationErrors, other.validationErrors);

  @override
  int get hashCode => Object.hash(
        surfaceId,
        surface,
        isValid,
        version,
        deepHashCode(formValues),
        deepHashCode(availableSurfaceIds),
        deepHashCode(validationErrors),
      );

  @override
  String toString() =>
      'SurfaceReady(surfaceId: $surfaceId, isValid: $isValid, errors: ${validationErrors.length}, surfaces: ${availableSurfaceIds.length})';
}

/// State emitted when the user triggers a submission or action on the surface,
/// transitioning the UI into a waiting state while packaging the tool result.
final class SurfaceSubmitting extends A2uiSurfaceState {
  /// Creates a [SurfaceSubmitting] state.
  const SurfaceSubmitting({
    required this.surfaceId,
    required this.actionName,
    required this.sourceComponentId,
    this.payload = const {},
  });

  /// The identifier of the surface where the action was submitted.
  @override
  final String surfaceId;

  /// The name of the action submitted.
  final String actionName;

  /// The identifier of the component triggering the submission.
  final String sourceComponentId;

  /// The submitted form and context payload.
  final Map<String, dynamic> payload;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SurfaceSubmitting &&
          surfaceId == other.surfaceId &&
          actionName == other.actionName &&
          sourceComponentId == other.sourceComponentId &&
          deepEquals(payload, other.payload);

  @override
  int get hashCode => Object.hash(
        surfaceId,
        actionName,
        sourceComponentId,
        deepHashCode(payload),
      );

  @override
  String toString() =>
      'SurfaceSubmitting(surfaceId: $surfaceId, action: $actionName)';
}

/// State emitted when an unrecoverable schema validation error, AST parse
/// error, or network stream failure occurs.
final class SurfaceError extends A2uiSurfaceState {
  /// Creates a [SurfaceError] state.
  const SurfaceError({
    required this.error,
    this.stackTrace,
    this.surfaceId,
  });

  /// The underlying error or exception object.
  final Object error;

  /// The stack trace associated with the failure, if available.
  final StackTrace? stackTrace;

  /// The identifier of the surface where the error occurred, if known.
  @override
  final String? surfaceId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SurfaceError &&
          error == other.error &&
          surfaceId == other.surfaceId;

  @override
  int get hashCode => Object.hash(error, surfaceId);

  @override
  String toString() => 'SurfaceError(surfaceId: $surfaceId, error: $error)';
}
