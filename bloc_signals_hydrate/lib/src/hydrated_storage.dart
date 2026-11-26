import 'dart:async';
import 'dart:convert';

import 'package:meta/meta.dart';

/// Returns a deep copy of an already-decoded JSON [value] so callers cannot
/// mutate cached [Map] or [List] instances in place.
@internal
dynamic cloneHydratedJsonValue(dynamic value) {
  if (value is Map) {
    return <String, dynamic>{
      for (final entry in value.entries)
        entry.key.toString(): cloneHydratedJsonValue(entry.value),
    };
  }
  if (value is List) {
    return <dynamic>[
      for (final item in value) cloneHydratedJsonValue(item),
    ];
  }
  return value;
}

/// Default key prefix used by namespaced [HydratedStorage] adapters such as
/// `SecureHydratedStorage` and `SharedPreferencesHydratedStorage`.
///
/// Namespacing prevents storage adapters from pre-loading or clearing
/// unrelated host-application keys. Pass `prefix: ''` explicitly if you need
/// to target legacy unprefixed keys directly.
const String kDefaultHydratedStoragePrefix = 'bloc_signals_hydrate_';

/// An interface for synchronous encryption and integrity verification of
/// persisted state payloads in [HydratedStorage].
///
/// Because [HydratedStorage.read] is synchronous for constructor-time
/// hydration, both [encrypt] and [decrypt] must execute synchronously.
///
/// Example:
/// ```dart
/// class PrefixCipher implements HydratedCipher {
///   const PrefixCipher();
///
///   @override
///   dynamic encrypt(dynamic data) => {'v': 1, 'data': data};
///
///   @override
///   dynamic decrypt(dynamic data) => (data as Map)['data'];
/// }
/// ```
abstract interface class HydratedCipher {
  /// Encrypts or wraps a serialized [data] payload before writing to storage.
  dynamic encrypt(dynamic data);

  /// Decrypts or verifies a stored [data] payload read from storage.
  ///
  /// Implementations should throw an [Exception] (such as [FormatException])
  /// if the payload has been tampered with or cannot be decrypted.
  dynamic decrypt(dynamic data);
}

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

  /// The global default [HydratedStorage] instance used across hydrated blocs.
  static HydratedStorage? storage;

  /// Returns whether a global default [HydratedStorage] instance is currently
  /// set.
  static bool get isInitialized => storage != null;

  /// Resets global default storage to uninitialized state (useful for test
  /// tearDown).
  static void reset() {
    storage = null;
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
  dynamic read(String key) => cloneHydratedJsonValue(_storage[key]);

  @override
  void write(String key, dynamic value) {
    _storage[key] = jsonDecode(jsonEncode(value));
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
