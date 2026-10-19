import 'package:a2ui_core/a2ui_core.dart';

/// Unwraps a [ResolvedBinding] or [WritableBinding] wrapper to its underlying
/// dynamic value, or returns [value] unchanged if it is not wrapped.
///
/// ```dart
/// final raw = unwrapBinding(const ResolvedBinding<Object?>('hello'));
/// print(raw); // hello
/// ```
dynamic unwrapBinding(dynamic value) {
  var current = value;
  while (current is ResolvedBinding) {
    current = current.value;
  }
  return current;
}

/// Safely converts a dynamic [value] to a [double], falling back to
/// [defaultValue] if the value is null, unparseable, or an incompatible type.
///
/// Automatically unwraps [ResolvedBinding] and [WritableBinding] instances.
double asDouble(dynamic value, [double defaultValue = 0.0]) {
  final unwrapped = unwrapBinding(value);
  if (unwrapped is num) return unwrapped.toDouble();
  if (unwrapped is String) {
    return double.tryParse(unwrapped) ?? defaultValue;
  }
  return defaultValue;
}

/// Safely converts a dynamic [value] to an [int], falling back to
/// [defaultValue] if the value is null, unparseable, or an incompatible type.
///
/// Automatically unwraps [ResolvedBinding] and [WritableBinding] instances.
int asInt(dynamic value, [int defaultValue = 0]) {
  final unwrapped = unwrapBinding(value);
  if (unwrapped is num) return unwrapped.toInt();
  if (unwrapped is String) {
    return int.tryParse(unwrapped) ?? defaultValue;
  }
  return defaultValue;
}

/// Safely converts a dynamic [value] to a [String], falling back to
/// [defaultValue] if the value is null.
///
/// Automatically unwraps [ResolvedBinding] and [WritableBinding] instances.
String asString(dynamic value, [String defaultValue = '']) {
  final unwrapped = unwrapBinding(value);
  if (unwrapped == null) return defaultValue;
  return unwrapped.toString();
}

/// Safely extracts a child component ID from diverse payload formats (for
/// example [ChildNode], `Map` with an `'id'` key, [ResolvedBinding], or direct
/// string).
String? extractChildId(dynamic rawChild) {
  final unwrapped = unwrapBinding(rawChild);
  if (unwrapped == null) return null;
  if (unwrapped is ChildNode) return unwrapped.id;
  if (unwrapped is Map) {
    final id = unwrapBinding(unwrapped['id']);
    if (id != null) return id.toString();
    return null;
  }
  return unwrapped.toString();
}

/// Safely extracts a list of child component IDs from an iterable
/// [rawChildren] or [ResolvedBinding] wrapping an iterable.
List<String> extractChildIds(dynamic rawChildren) {
  final unwrapped = unwrapBinding(rawChildren);
  if (unwrapped is! Iterable) return const [];
  final childIds = <String>[];
  for (final child in unwrapped) {
    final id = extractChildId(child);
    if (id != null && id.isNotEmpty) {
      childIds.add(id);
    }
  }
  return childIds;
}
