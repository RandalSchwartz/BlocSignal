import 'dart:async';

/// An abstract interface for state persistence backends used by
/// `HydratedBlocSignal` and `HydratedCubitSignal`.
///
/// Example:
/// ```dart
/// void main() {
///   HydratedStorage.storage = MemoryHydratedStorage();
///   runApp(const MyApp());
/// }
/// ```
abstract class HydratedStorage {
  /// Abstract const constructor for [HydratedStorage] subclasses.
  const HydratedStorage();

  static HydratedStorage? _storage;

  /// The global default [HydratedStorage] instance used across hydrated blocs.
  ///
  /// In debug mode (when assertions are enabled), if accessed while
  /// uninitialized, this getter lazily falls back to a [MemoryHydratedStorage]
  /// instance and prints a diagnostic warning so unit tests and prototypes work
  /// without boilerplate setup.
  static HydratedStorage? get storage {
    if (_storage == null) {
      assert(
        () {
          _storage = MemoryHydratedStorage();
          // Print debug fallback notice.
          // ignore: avoid_print
          print(
            '[bloc_signals_hydrate] HydratedStorage.storage was accessed '
            'before initialization.\n'
            'Falling back to MemoryHydratedStorage for testing/debugging.\n'
            'Make sure to set HydratedStorage.storage in main() before running '
            'in production.',
          );
          return true;
        }(),
        'HydratedStorage fallback assertion',
      );
    }
    return _storage;
  }

  /// Sets the global default storage backend.
  static set storage(HydratedStorage? value) {
    _storage = value;
  }

  /// Returns whether a global default [HydratedStorage] instance is currently
  /// set.
  static bool get isInitialized => _storage != null;

  /// Resets global default storage to uninitialized state (useful for test
  /// tearDown).
  static void reset() {
    _storage = null;
  }

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
///
/// Example:
/// ```dart
/// final storage = MemoryHydratedStorage();
/// HydratedStorage.storage = storage;
/// ```
class MemoryHydratedStorage implements HydratedStorage {
  /// Creates an in-memory [MemoryHydratedStorage] instance.
  MemoryHydratedStorage();
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
