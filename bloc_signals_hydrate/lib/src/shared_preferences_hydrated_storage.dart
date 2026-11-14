import 'dart:async';
import 'dart:convert';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_hydrate/src/hydrated_storage.dart';

/// A [HydratedStorage] backend implementation that persists state using
/// `SharedPreferences` (from `package:shared_preferences`).
///
/// Asynchronous [write], [delete], and [clear] operations are serialized per
/// storage instance via an internal [Mutex] while preserving the `const`
/// constructor.
///
/// **Security Warning**: `SharedPreferences` stores data in plaintext
/// (unencrypted XML/plist on mobile and `localStorage` on web). Do not use
/// [SharedPreferencesHydratedStorage] for sensitive state such as auth tokens,
/// credentials, or personally identifiable information; use
/// `SecureHydratedStorage` instead.
///
/// Example:
/// ```dart
/// import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';
/// import 'package:bloc_signals_hydrate/shared_preferences.dart';
/// import 'package:shared_preferences/shared_preferences.dart';
///
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   final prefs = await SharedPreferences.getInstance();
///   HydratedStorage.storage = SharedPreferencesHydratedStorage(prefs);
///
///   runApp(const MyApp());
/// }
/// ```
class SharedPreferencesHydratedStorage implements HydratedStorage {
  /// Creates a [SharedPreferencesHydratedStorage] adapter wrapping `prefs`.
  ///
  /// Defaults [prefix] to [kDefaultHydratedStoragePrefix]
  /// (`'bloc_signals_hydrate_'`) so [read], [write], [delete], and [clear]
  /// only touch keys managed by `bloc_signals_hydrate`. Pass `prefix: ''`
  /// explicitly to read and write legacy unprefixed keys directly.
  const SharedPreferencesHydratedStorage(
    this._prefs, {
    this.prefix = kDefaultHydratedStoragePrefix,
  });

  static final Expando<Mutex> _mutexes =
      Expando<Mutex>('SharedPreferencesHydratedStorage.mutex');

  Mutex get _mutex => _mutexes[this] ??= Mutex();

  final dynamic _prefs;

  /// The prefix applied to all keys stored in SharedPreferences.
  final String prefix;

  String _prefixedKey(String key) => '$prefix$key';

  /// Reads and JSON-decodes the stored value for [key].
  ///
  /// Throws a [FormatException] if the stored string is not valid JSON so
  /// `HydratedMixin.initHydratedState` can route the error to `onError` and
  /// fall back to `initialState`.
  @override
  dynamic read(String key) {
    // Duck-typing support for shared_preferences getString.
    // ignore: avoid_dynamic_calls
    final dynamic value = _prefs.getString(_prefixedKey(key));
    if (value == null || value is! String) return null;
    return jsonDecode(value);
  }

  @override
  FutureOr<void> write(String key, dynamic value) => _mutex.protect(() async {
        final encoded = jsonEncode(value);
        // Duck-typing support for shared_preferences setString.
        // ignore: avoid_dynamic_calls
        await _prefs.setString(_prefixedKey(key), encoded);
      });

  @override
  FutureOr<void> delete(String key) => _mutex.protect(() async {
        // Duck-typing support for shared_preferences remove.
        // ignore: avoid_dynamic_calls
        await _prefs.remove(_prefixedKey(key));
      });

  @override
  FutureOr<void> clear() => _mutex.protect(() async {
        // Duck-typing support for shared_preferences getKeys and remove.
        // ignore: avoid_dynamic_calls
        final dynamic rawKeys = _prefs.getKeys();
        if (rawKeys is Iterable) {
          final keys = rawKeys.map((dynamic e) => e.toString()).toList();
          for (final key in keys) {
            if (prefix.isEmpty || key.startsWith(prefix)) {
              // Duck-typing support for shared_preferences remove.
              // ignore: avoid_dynamic_calls
              await _prefs.remove(key);
            }
          }
        }
      });
}
