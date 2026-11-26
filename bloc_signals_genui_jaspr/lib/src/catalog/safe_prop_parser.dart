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
  if (unwrapped is num) {
    return unwrapped.isFinite ? unwrapped.toDouble() : defaultValue;
  }
  if (unwrapped is String) {
    final parsed = double.tryParse(unwrapped);
    return parsed != null && parsed.isFinite ? parsed : defaultValue;
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
  if (unwrapped is num) {
    return unwrapped.isFinite ? unwrapped.toInt() : defaultValue;
  }
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
  if (unwrapped == null) return defaultValue;
  if (unwrapped is bool) return unwrapped;
  if (unwrapped is ValidationResult) return unwrapped.valid;
  if (unwrapped is Map && unwrapped['valid'] is bool) {
    return unwrapped['valid']! as bool;
  }
  if (unwrapped is String) {
    final normalized = unwrapped.trim().toLowerCase();
    if (normalized == 'true') return true;
    if (normalized == 'false') return false;
    return defaultValue;
  }
  if (unwrapped is num) {
    return unwrapped != 0 && !unwrapped.isNaN;
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

/// Maximum finite magnitude permitted for slider `min` and `max` bounds.
///
/// ```dart
/// print(kMaxSliderBound); // 1000000000000.0
/// ```
const double kMaxSliderBound = 1000000000000;

/// Maximum number of discrete steps (`divisions`) permitted on a slider.
///
/// ```dart
/// print(kMaxSliderDivisions); // 1000
/// ```
const int kMaxSliderDivisions = 1000;

/// Parses and clamps slider `min`, `max`, `value`, and `steps`/`divisions`
/// properties into finite, paint-safe bounds.
///
/// Bounds `min` and `max` to `[-1e12, 1e12]`, falls back to `[0.0, 100.0]` when
/// `(max - min)` is non-finite or `max <= min`, clamps `value` to `[min, max]`,
/// and caps `divisions` to `[1, 1000]`.
///
/// ```dart
/// final range = parseSliderRange(const {'min': 0, 'max': 10, 'steps': 5});
/// print(range.divisions); // 5
/// ```
({double min, double max, double value, int? divisions}) parseSliderRange(
  Map<String, dynamic> props,
) {
  final rawMin =
      asDouble(props['min']).clamp(-kMaxSliderBound, kMaxSliderBound);
  final rawMax =
      asDouble(props['max'], 100).clamp(-kMaxSliderBound, kMaxSliderBound);
  final hasValidRange = rawMin.isFinite &&
      rawMax.isFinite &&
      rawMax > rawMin &&
      (rawMax - rawMin).isFinite;
  final min = hasValidRange ? rawMin : 0.0;
  final max = hasValidRange ? rawMax : 100.0;
  final currentValue = asDouble(props['value'], min).clamp(min, max);

  final rawSteps = props['steps'] ?? props['divisions'];
  final parsedSteps = rawSteps != null ? asInt(rawSteps) : 0;
  final divisions =
      parsedSteps >= 1 ? parsedSteps.clamp(1, kMaxSliderDivisions) : null;

  return (min: min, max: max, value: currentValue, divisions: divisions);
}

/// Safely converts a dynamic [value] to a non-negative finite [double],
/// clamping negative values to `0.0` and falling back to [defaultValue]
/// (clamped to `>= 0.0`) when [value] is null, non-finite, or unparseable.
///
/// ```dart
/// final size = asNonNegativeDouble(-4, 1.0);
/// print(size); // 0.0
/// ```
double asNonNegativeDouble(dynamic value, [double defaultValue = 0.0]) {
  final safeDefault =
      defaultValue.isFinite && defaultValue >= 0 ? defaultValue : 0.0;
  final parsed = asDouble(value, safeDefault);
  if (!parsed.isFinite || parsed < 0) return 0;
  return parsed;
}

/// Safely converts a dynamic [value] to a finite [double] clamped to
/// `[min, max]`.
///
/// ```dart
/// final clamped = asBoundedDouble(999, min: 1, max: 256, defaultValue: 24);
/// print(clamped); // 256.0
/// ```
double asBoundedDouble(
  dynamic value, {
  required double min,
  required double max,
  required double defaultValue,
}) {
  final safeDefault = defaultValue.clamp(min, max);
  final parsed = asDouble(value, safeDefault);
  if (!parsed.isFinite) return safeDefault;
  return parsed.clamp(min, max);
}

/// Safely converts a dynamic [value] to an [int] clamped to `[min, max]`.
///
/// ```dart
/// final limit = asBoundedInt(50000, min: 1, max: 10000, defaultValue: 100);
/// print(limit); // 10000
/// ```
int asBoundedInt(
  dynamic value, {
  required int min,
  required int max,
  required int defaultValue,
}) {
  final safeDefault = defaultValue.clamp(min, max);
  final parsed = asInt(value, safeDefault);
  return parsed.clamp(min, max);
}
