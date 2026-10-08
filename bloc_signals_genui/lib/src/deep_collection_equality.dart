/// Recursive structural equality and content-derived hash code helpers for
/// dynamic A2UI JSON and form payload structures.
library;

import 'package:meta/meta.dart';

/// Recursively compares two values [a] and [b] for deep structural equality.
///
/// Handles nested [Map], [List], [Set], and general [Iterable] instances
/// regardless of generic type reification (for example comparing
/// `Map<String, dynamic>` against `Map<dynamic, dynamic>`), while guarding
/// against self-referential collection cycles.
bool deepEquals(Object? a, Object? b) => _deepEquals(a, b, <_Pair>{});

bool _deepEquals(Object? a, Object? b, Set<_Pair> visited) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;

  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    final pair = _Pair(a, b);
    if (!visited.add(pair)) return true;
    for (final entry in a.entries) {
      final key = entry.key;
      if (!b.containsKey(key)) return false;
      if (!_deepEquals(entry.value, b[key], visited)) return false;
    }
    return true;
  }

  if (a is List && b is List) {
    if (a.length != b.length) return false;
    final pair = _Pair(a, b);
    if (!visited.add(pair)) return true;
    for (var i = 0; i < a.length; i++) {
      if (!_deepEquals(a[i], b[i], visited)) return false;
    }
    return true;
  }

  if (a is Set && b is Set) {
    if (a.length != b.length) return false;
    final pair = _Pair(a, b);
    if (!visited.add(pair)) return true;
    for (final elementA in a) {
      if (b.contains(elementA)) continue;
      var matched = false;
      for (final elementB in b) {
        if (_deepEquals(elementA, elementB, Set<_Pair>.from(visited))) {
          matched = true;
          break;
        }
      }
      if (!matched) return false;
    }
    return true;
  }

  if (a is Iterable && b is Iterable && a is! Set && b is! Set) {
    final pair = _Pair(a, b);
    if (!visited.add(pair)) return true;
    final iterA = a.iterator;
    final iterB = b.iterator;
    while (iterA.moveNext()) {
      if (!iterB.moveNext()) return false;
      if (!_deepEquals(iterA.current, iterB.current, visited)) return false;
    }
    return !iterB.moveNext();
  }

  return a == b;
}

/// Computes a recursive, content-derived hash code for [value] that is
/// consistent with [deepEquals].
///
/// Order-independent collections ([Map] and [Set]) combine element hashes
/// commutatively so key or element iteration order does not affect the result.
int deepHashCode(Object? value) => _deepHashCode(value, <int>{});

int _deepHashCode(Object? value, Set<int> activeAncestors) {
  if (value == null) return 0;

  if (value is Map) {
    final id = identityHashCode(value);
    if (!activeAncestors.add(id)) return 0;
    try {
      var hash = 0;
      for (final entry in value.entries) {
        final entryHash = Object.hash(
          _deepHashCode(entry.key, activeAncestors),
          _deepHashCode(entry.value, activeAncestors),
        );
        hash = (hash + entryHash) & 0x3fffffff;
      }
      return Object.hash(Map, value.length, hash);
    } finally {
      activeAncestors.remove(id);
    }
  }

  if (value is Set) {
    final id = identityHashCode(value);
    if (!activeAncestors.add(id)) return 0;
    try {
      var hash = 0;
      for (final element in value) {
        hash = (hash + _deepHashCode(element, activeAncestors)) & 0x3fffffff;
      }
      return Object.hash(Set, value.length, hash);
    } finally {
      activeAncestors.remove(id);
    }
  }

  if (value is Iterable) {
    final id = identityHashCode(value);
    if (!activeAncestors.add(id)) return 0;
    try {
      final elementHashes = <int>[];
      for (final element in value) {
        elementHashes.add(_deepHashCode(element, activeAncestors));
      }
      return Object.hash(List, Object.hashAll(elementHashes));
    } finally {
      activeAncestors.remove(id);
    }
  }

  return value.hashCode;
}

@immutable
final class _Pair {
  const _Pair(this.left, this.right);

  final Object left;
  final Object right;

  @override
  bool operator ==(Object other) =>
      other is _Pair &&
      identical(left, other.left) &&
      identical(right, other.right);

  @override
  int get hashCode =>
      Object.hash(identityHashCode(left), identityHashCode(right));
}
