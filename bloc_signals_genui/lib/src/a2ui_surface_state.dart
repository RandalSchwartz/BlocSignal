import 'package:a2ui_core/a2ui_core.dart';
import 'package:bloc_signals_genui/src/a2ui_surface_bloc.dart'
    show A2uiSurfaceBloc;
import 'package:meta/meta.dart';

/// Sealed hierarchy defining the client-side presentation lifecycle of an
/// A2UI surface managed by [A2uiSurfaceBloc].
@immutable
sealed class A2uiSurfaceState {
  /// Const base constructor for [A2uiSurfaceState].
  const A2uiSurfaceState();
}

/// Initial resting state before any A2UI stream or surface message has been received.
final class SurfaceInitial extends A2uiSurfaceState {
  /// Creates a [SurfaceInitial] state.
  const SurfaceInitial();

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

/// State emitted when the surface is fully hydrated, validated against the
/// component catalog, and ready for user viewing and form interaction.
final class SurfaceReady extends A2uiSurfaceState {
  /// Creates a [SurfaceReady] state.
  const SurfaceReady({
    required this.surfaceId,
    required this.surface,
    this.formValues = const {},
    this.isValid = true,
    this.validationErrors = const [],
    this.version = 0,
  });

  /// The unique identifier of this active surface.
  final String surfaceId;

  /// The underlying [SurfaceModel] instance from `a2ui_core`.
  final SurfaceModel<ComponentApi> surface;

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
          _mapsEqual(formValues, other.formValues) &&
          _listsEqual(validationErrors, other.validationErrors);

  static bool _mapsEqual(Map<dynamic, dynamic> a, Map<dynamic, dynamic> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      final valA = a[key];
      final valB = b[key];
      if (valA is Map && valB is Map) {
        if (!_mapsEqual(valA, valB)) return false;
      } else if (valA is List && valB is List) {
        if (!_listsEqual(valA, valB)) return false;
      } else if (valA != valB) {
        return false;
      }
    }
    return true;
  }

  static bool _listsEqual(List<dynamic> a, List<dynamic> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(surfaceId, surface, isValid, version, formValues.length);

  @override
  String toString() =>
      'SurfaceReady(surfaceId: $surfaceId, isValid: $isValid, errors: ${validationErrors.length})';
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
          sourceComponentId == other.sourceComponentId;

  @override
  int get hashCode => Object.hash(surfaceId, actionName, sourceComponentId);

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
