import 'package:a2ui_core/a2ui_core.dart';

/// Safely converts a dynamic [value] to a [double], falling back to
/// [defaultValue] if the value is null, unparseable, or an incompatible type.
double asDouble(dynamic value, [double defaultValue = 0.0]) {
  if (value is num) return value.toDouble();
  if (value is String) {
    return double.tryParse(value) ?? defaultValue;
  }
  return defaultValue;
}

/// Safely converts a dynamic [value] to an [int], falling back to
/// [defaultValue] if the value is null, unparseable, or an incompatible type.
int asInt(dynamic value, [int defaultValue = 0]) {
  if (value is num) return value.toInt();
  if (value is String) {
    return int.tryParse(value) ?? defaultValue;
  }
  return defaultValue;
}

/// Safely converts a dynamic [value] to a [String], falling back to
/// [defaultValue] if the value is null.
String asString(dynamic value, [String defaultValue = '']) {
  if (value == null) return defaultValue;
  return value.toString();
}

/// Safely extracts a child component ID from diverse payload formats (for
/// example [ChildNode], `Map` with an `'id'` key, or direct string).
String? extractChildId(dynamic rawChild) {
  if (rawChild == null) return null;
  if (rawChild is ChildNode) return rawChild.id;
  if (rawChild is Map) {
    final id = rawChild['id'];
    if (id != null) return id.toString();
    return null;
  }
  return rawChild.toString();
}

/// Safely extracts a list of child component IDs from an iterable
/// [rawChildren].
List<String> extractChildIds(dynamic rawChildren) {
  if (rawChildren is! Iterable) return const [];
  final childIds = <String>[];
  for (final child in rawChildren) {
    final id = extractChildId(child);
    if (id != null && id.isNotEmpty) {
      childIds.add(id);
    }
  }
  return childIds;
}
