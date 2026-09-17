import 'dart:async';
import 'dart:convert';

import 'package:bloc_signals_hydrate/src/hydrated_storage.dart';

/// A [HydratedStorage] backend implementation that persists state using
/// `SharedPreferences` (from `package:shared_preferences`).
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
  const SharedPreferencesHydratedStorage(
    this._prefs, {
    this.prefix = '',
  });

  final dynamic _prefs;

  /// The prefix applied to all keys stored in SharedPreferences.
  final String prefix;

  String _prefixedKey(String key) => '$prefix$key';

  @override
  dynamic read(String key) {
    // Duck-typing support for shared_preferences getString.
    // ignore: avoid_dynamic_calls
    final dynamic value = _prefs.getString(_prefixedKey(key));
    if (value == null || value is! String) return null;
    return jsonDecode(value);
  }

  @override
  FutureOr<void> write(String key, dynamic value) async {
    final encoded = jsonEncode(value);
    // Duck-typing support for shared_preferences setString.
    // ignore: avoid_dynamic_calls
    await _prefs.setString(_prefixedKey(key), encoded);
  }

  @override
  FutureOr<void> delete(String key) async {
    // Duck-typing support for shared_preferences remove.
    // ignore: avoid_dynamic_calls
    await _prefs.remove(_prefixedKey(key));
  }

  @override
  FutureOr<void> clear() async {
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
  }
}
