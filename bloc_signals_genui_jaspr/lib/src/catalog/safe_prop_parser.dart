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
///
/// ```dart
/// final doubleVal = asDouble('3.14', 0.0);
/// print(doubleVal); // 3.14
/// ```
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
///
/// ```dart
/// final intVal = asInt('42', 0);
/// print(intVal); // 42
/// ```
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
///
/// ```dart
/// final strVal = asString(42, '');
/// print(strVal); // 42
/// ```
String asString(dynamic value, [String defaultValue = '']) {
  final unwrapped = unwrapBinding(value);
  if (unwrapped == null) return defaultValue;
  return unwrapped.toString();
}

/// Safely converts a dynamic [value] to a [bool], falling back to
/// [defaultValue] if the value is null or not a recognizable boolean.
///
/// Automatically unwraps [ResolvedBinding] and [WritableBinding] instances.
///
/// ```dart
/// final enabled = asBool(const ResolvedBinding<Object?>(true));
/// print(enabled); // true
/// ```
bool asBool(dynamic value, {bool defaultValue = false}) {
  final unwrapped = unwrapBinding(value);
  if (unwrapped is bool) return unwrapped;
  if (unwrapped is String) {
    final normalized = unwrapped.trim().toLowerCase();
    if (normalized == 'true') return true;
    if (normalized == 'false') return false;
  }
  return defaultValue;
}

/// Safely extracts a child component ID from diverse payload formats (for
/// example [ComponentNode], [ChildNode], `Map` with an `'id'` key,
/// [ResolvedBinding], or direct string).
///
/// ```dart
/// final id = extractChildId({'id': 'txt_1'});
/// print(id); // txt_1
/// ```
String? extractChildId(dynamic rawChild) {
  final unwrapped = unwrapBinding(rawChild);
  if (unwrapped == null) return null;
  if (unwrapped is ComponentNode) return unwrapped.instanceId;
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
///
/// ```dart
/// final ids = extractChildIds(['item_1', {'id': 'item_2'}]);
/// print(ids); // [item_1, item_2]
/// ```
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
