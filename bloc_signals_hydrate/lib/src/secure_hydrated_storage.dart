import 'dart:async';
import 'dart:convert';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_hydrate/src/hydrated_storage.dart';

/// A [HydratedStorage] backend implementation that persists state using
/// secure key-value storage (such as `FlutterSecureStorage`).
///
/// Pre-loads all stored key-value pairs into an in-memory cache during [build]
/// so that subsequent read requests are returned **synchronously on frame 1**
/// without UI flickers. Asynchronous [write], [delete], and [clear] operations
/// are serialized through an internal [Mutex] so in-memory cache updates never
/// interleave out of order with underlying secure storage I/O.
///
/// Example:
/// ```dart
/// import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';
/// import 'package:bloc_signals_hydrate/secure_storage.dart';
/// import 'package:flutter_secure_storage/flutter_secure_storage.dart';
///
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   final secureStorage = const FlutterSecureStorage();
///   HydratedStorage.storage =
///       await SecureHydratedStorage.build(secureStorage);
///
///   runApp(const MyApp());
/// }
/// ```
class SecureHydratedStorage implements HydratedStorage {
  SecureHydratedStorage._(
    this._secureStorage,
    Map<String, dynamic> initialCache, {
    this.prefix = kDefaultHydratedStoragePrefix,
  }) : _cache = initialCache;

  final dynamic _secureStorage;
  final Map<String, dynamic> _cache;
  final Mutex _mutex = Mutex();

  /// The prefix applied to all keys stored in secure storage.
  ///
  /// Defaults to [kDefaultHydratedStoragePrefix] (`'bloc_signals_hydrate_'`)
  /// so [build] and [clear] only touch keys managed by `bloc_signals_hydrate`
  /// instead of reading or deleting unrelated host-application keychain
  /// entries. Pass `prefix: ''` explicitly to opt in to legacy unprefixed keys.
  final String prefix;

  String _prefixedKey(String key) => '$prefix$key';

  /// Asynchronously pre-loads stored keys matching [prefix] from
  /// [secureStorage] into memory, returning a fully initialized
  /// [SecureHydratedStorage] ready for synchronous frame 1 state hydration.
  ///
  /// Defaults [prefix] to [kDefaultHydratedStoragePrefix] so foreign keychain
  /// entries are ignored. Pass `prefix: ''` explicitly if you must read legacy
  /// unprefixed keys.
  static Future<SecureHydratedStorage> build(
    dynamic secureStorage, {
    String prefix = kDefaultHydratedStoragePrefix,
  }) async {
    // Duck-typing support for flutter_secure_storage FlutterSecureStorage.
    // ignore: avoid_dynamic_calls
    final dynamic rawAll = await secureStorage.readAll();
    final all = Map<String, String>.from(
      (rawAll as Map).map((k, v) => MapEntry(k.toString(), v.toString())),
    );
    final cache = <String, dynamic>{};
    for (final entry in all.entries) {
      if (prefix.isEmpty || entry.key.startsWith(prefix)) {
        final rawKey = prefix.isNotEmpty && entry.key.startsWith(prefix)
            ? entry.key.substring(prefix.length)
            : entry.key;
        try {
          cache[rawKey] = jsonDecode(entry.value);
        } on FormatException {
          cache[rawKey] = entry.value;
        }
      }
    }
    return SecureHydratedStorage._(secureStorage, cache, prefix: prefix);
  }

  @override
  dynamic read(String key) => _cache[key];

  @override
  FutureOr<void> write(String key, dynamic value) => _mutex.protect(() async {
        final encoded = jsonEncode(value);
        // Duck-typing support for flutter_secure_storage write.
        // ignore: avoid_dynamic_calls
        await _secureStorage.write(key: _prefixedKey(key), value: encoded);
        _cache[key] = value;
      });

  @override
  FutureOr<void> delete(String key) => _mutex.protect(() async {
        // Duck-typing support for flutter_secure_storage delete.
        // ignore: avoid_dynamic_calls
        await _secureStorage.delete(key: _prefixedKey(key));
        _cache.remove(key);
      });

  @override
  FutureOr<void> clear() => _mutex.protect(() async {
        final keys = _cache.keys.toList();
        for (final key in keys) {
          // Duck-typing support for flutter_secure_storage delete.
          // ignore: avoid_dynamic_calls
          await _secureStorage.delete(key: _prefixedKey(key));
          _cache.remove(key);
        }
      });
}
