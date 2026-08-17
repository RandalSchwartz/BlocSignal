import 'dart:async';
import 'dart:convert';

import 'package:bloc_signals_hydrate/src/hydrated_storage.dart';

/// A [HydratedStorage] backend implementation that persists state using
/// secure key-value storage (such as `FlutterSecureStorage`).
///
/// Pre-loads all stored key-value pairs into an in-memory cache during [build]
/// so that subsequent read requests are returned **synchronously on frame 1**
/// without UI flickers.
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
  SecureHydratedStorage._(this._secureStorage, Map<String, String> initialCache)
      : _cache = Map<String, dynamic>.from(
          initialCache.map((key, value) {
            try {
              return MapEntry(key, jsonDecode(value));
            } on Object {
              return MapEntry(key, value);
            }
          }),
        );

  final dynamic _secureStorage;
  final Map<String, dynamic> _cache;

  /// Asynchronously pre-loads stored keys from [secureStorage] into memory,
  /// returning a fully initialized [SecureHydratedStorage] ready for
  /// synchronous frame 1 state hydration.
  static Future<SecureHydratedStorage> build(dynamic secureStorage) async {
    // Duck-typing support for flutter_secure_storage FlutterSecureStorage.
    // ignore: avoid_dynamic_calls
    final dynamic rawAll = await secureStorage.readAll();
    final all = Map<String, String>.from(
      (rawAll as Map).map((k, v) => MapEntry(k.toString(), v.toString())),
    );
    return SecureHydratedStorage._(secureStorage, all);
  }

  @override
  dynamic read(String key) => _cache[key];

  @override
  FutureOr<void> write(String key, dynamic value) async {
    _cache[key] = value;
    final encoded = jsonEncode(value);
    // Duck-typing support for flutter_secure_storage write.
    // ignore: avoid_dynamic_calls
    await _secureStorage.write(key: key, value: encoded);
  }

  @override
  FutureOr<void> delete(String key) async {
    _cache.remove(key);
    // Duck-typing support for flutter_secure_storage delete.
    // ignore: avoid_dynamic_calls
    await _secureStorage.delete(key: key);
  }

  @override
  FutureOr<void> clear() async {
    _cache.clear();
    // Duck-typing support for flutter_secure_storage deleteAll.
    // ignore: avoid_dynamic_calls
    await _secureStorage.deleteAll();
  }
}
