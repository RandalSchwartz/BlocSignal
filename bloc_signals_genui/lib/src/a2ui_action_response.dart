import 'package:meta/meta.dart';

/// Structured representation of a client action response dispatched from an
/// A2UI surface component back to the agent or LLM tool executor.
@immutable
class A2uiActionResponse {
  /// Creates an [A2uiActionResponse].
  const A2uiActionResponse({
    required this.actionName,
    required this.surfaceId,
    required this.sourceComponentId,
    required this.timestamp,
    this.formData = const {},
    this.context = const {},
  });

  /// The name or identifier of the action invoked by the user.
  final String actionName;

  /// The identifier of the surface where the action originated.
  final String surfaceId;

  /// The identifier of the component (for example a button) that triggered the action.
  final String sourceComponentId;

  /// The timestamp when the action was triggered.
  final DateTime timestamp;

  /// The validated form data captured from the surface at the time of submission.
  final Map<String, dynamic> formData;

  /// Any additional contextual payload associated with the action.
  final Map<String, dynamic> context;

  /// Serializes this action response into a standard tool execution result map
  /// formatted for agent conversation histories.
  Map<String, dynamic> toToolResult() => {
        'actionName': actionName,
        'surfaceId': surfaceId,
        'sourceComponentId': sourceComponentId,
        'timestamp': timestamp.toIso8601String(),
        'formData': formData,
        'context': context,
      };

  /// Retrieves a form value by its key or structured path (for example `'/passenger/name'`,
  /// `'passenger.name'`, or `'input_passenger_name'`).
  ///
  /// Searches flat keys first, then recursively traverses nested maps by path segments.
  T? getFormValue<T>(String path) {
    if (formData.containsKey(path)) {
      final val = formData[path];
      if (val is T) return val;
      return null;
    }

    final normalized = path.startsWith('/') ? path.substring(1) : path;
    if (formData.containsKey(normalized)) {
      final val = formData[normalized];
      if (val is T) return val;
      return null;
    }

    final delimiter = normalized.contains('/') ? '/' : '.';
    final segments =
        normalized.split(delimiter).where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return null;

    dynamic current = formData;
    for (final seg in segments) {
      if (current is Map && current.containsKey(seg)) {
        current = current[seg];
      } else {
        return null;
      }
    }

    if (current is T) return current;
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is A2uiActionResponse &&
          runtimeType == other.runtimeType &&
          actionName == other.actionName &&
          surfaceId == other.surfaceId &&
          sourceComponentId == other.sourceComponentId &&
          timestamp == other.timestamp &&
          _mapsEqual(formData, other.formData) &&
          _mapsEqual(context, other.context);

  @override
  int get hashCode => Object.hash(
        actionName,
        surfaceId,
        sourceComponentId,
        timestamp,
        formData.length,
        context.length,
      );

  static bool _mapsEqual(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      final valA = a[key];
      final valB = b[key];
      if (valA is Map<String, dynamic> && valB is Map<String, dynamic>) {
        if (!_mapsEqual(valA, valB)) return false;
      } else if (valA != valB) {
        return false;
      }
    }
    return true;
  }

  @override
  String toString() =>
      'A2uiActionResponse(action: $actionName, surface: $surfaceId, component: $sourceComponentId)';
}
