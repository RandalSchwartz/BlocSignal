import 'dart:async';

/// An abstract interface for state persistence backends used by
/// `HydratedBlocSignal` and `HydratedCubitSignal`.
abstract class HydratedStorage {
  /// The global default [HydratedStorage] instance used across hydrated blocs.
  static HydratedStorage? storage;

  /// Reads value associated with [key] from storage.
  dynamic read(String key);

  /// Writes [value] associated with [key] to storage.
  FutureOr<void> write(String key, dynamic value);

  /// Deletes value associated with [key] from storage.
  FutureOr<void> delete(String key);

  /// Clears all keys and values from storage.
  FutureOr<void> clear();
}

/// An in-memory implementation of [HydratedStorage] useful for testing,
/// temporary sessions, and default zero-dependency storage.
class MemoryHydratedStorage implements HydratedStorage {
  final Map<String, dynamic> _storage = {};

  @override
  dynamic read(String key) => _storage[key];

  @override
  void write(String key, dynamic value) {
    _storage[key] = value;
  }

  @override
  void delete(String key) {
    _storage.remove(key);
  }

  @override
  void clear() {
    _storage.clear();
  }
}
