## 0.1.7

- Add assertion-backed `MemoryHydratedStorage` fallback to `HydratedStorage.storage` in testing and debug mode, printing a clear diagnostic warning when accessed prior to explicit initialization.
- Add `HydratedStorage.isInitialized` getter and `HydratedStorage.reset()` helper.
- Preserve 100% production tree-shaking for release builds by enclosing fallback inside an assertion block.

## 0.1.6


- Add built-in `SharedPreferencesHydratedStorage` adapter available via `import 'package:bloc_signals_hydrate/shared_preferences.dart';`.
- Add built-in `SecureHydratedStorage` adapter (`FlutterSecureStorage` / Keychain / KeyStore / Web Crypto) with async pre-loading (`SecureHydratedStorage.build`) for zero-flicker synchronous frame 1 state hydration available via `import 'package:bloc_signals_hydrate/secure_storage.dart';`.
- Maintain 100% pure Dart package compatibility with zero Flutter SDK dependencies in core `pubspec.yaml`.

## 0.2.0


- Add built-in `SharedPreferencesHydratedStorage` adapter available via `import 'package:bloc_signals_hydrate/shared_preferences.dart';`.
- Add built-in `SecureHydratedStorage` adapter (`FlutterSecureStorage` / Keychain / KeyStore / Web Crypto) with async pre-loading (`SecureHydratedStorage.build`) for zero-flicker synchronous frame 1 state hydration available via `import 'package:bloc_signals_hydrate/secure_storage.dart';`.
- Maintain 100% pure Dart package compatibility with zero Flutter SDK dependencies in core `pubspec.yaml`.

## 0.1.5


- Provide default `fromJson` and `toJson` implementations in `HydratedMixin` so primitive state containers (`int`, `double`, `String`, `bool`, `Map`) require zero method overrides.
- Add smart collection type-casting to `HydratedMixin.fromJson` to automatically cast raw `jsonDecode` outputs (`List<dynamic>`, `Map<dynamic, dynamic>`) to typed collections (`List<T>`, `Map<K, V>`) without requiring manual `fromJson` overrides.
- Add runnable `@example` code blocks across `HydratedStorage`, `MemoryHydratedStorage`, `HydratedMixin`, `HydratedCubitSignal`, and `HydratedBlocSignal`.
- Update `bloc_signals` dependency to `^0.2.8`.

## 0.1.3

- Add `HydratedCubitSignal` vs `PersistentSignal` (`signals.dart`) architectural comparison guide and interop documentation to README.

## 0.1.2

- Add comprehensive ecosystem package cross-linking table and motto to README.
- Add quick inlined hydration code examples.
- Update `bloc_signals` dependency to `^0.2.6`.

## 0.1.1

- Added explicit constructor documentation comments for `HydratedStorage` and `MemoryHydratedStorage`.
- Added standalone executable `example/example.dart` demonstrating persistence workflows.
- Achieved 160/160 pub points on pub.dev.

## 0.1.0

- Initial release of `bloc_signals_hydrate`.
- Added `HydratedStorage` interface and zero-dependency `MemoryHydratedStorage`.
- Added `HydratedMixin`, `HydratedCubitSignal`, and `HydratedBlocSignal`.
- Supported `dynamic` / `Object?` JSON serialization (`int`, `String`, `List`, `Map`, `bool`) without map wrapping.
- Supported synchronous initial constructor hydration.
- Added `clear()` method for key deletion and state resets.
