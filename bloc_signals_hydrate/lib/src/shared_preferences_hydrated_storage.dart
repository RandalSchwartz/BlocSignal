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
  /// Creates a [SharedPreferencesHydratedStorage] adapter wrapping [prefs].
  const SharedPreferencesHydratedStorage(this._prefs);

  final dynamic _prefs;

  @override
  dynamic read(String key) {
    try {
      final dynamic value = _prefs.getString(key);
      if (value == null || value is! String) return null;
      try {
        return jsonDecode(value);
      } on Object {
        return value;
      }
    } on Object {
      return null;
    }
  }

  @override
  FutureOr<void> write(String key, dynamic value) async {
    final String encoded = jsonEncode(value);
    await _prefs.setString(key, encoded);
  }

  @override
  FutureOr<void> delete(String key) async {
    await _prefs.remove(key);
  }

  @override
  FutureOr<void> clear() async {
    await _prefs.clear();
  }
}
