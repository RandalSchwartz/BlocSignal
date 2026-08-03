Resolves #114

### Summary of Changes
- Added built-in `SharedPreferencesHydratedStorage` adapter in `lib/src/shared_preferences_hydrated_storage.dart` exported via dedicated sub-library `import 'package:bloc_signals_hydrate/shared_preferences.dart';`.
- Added built-in `SecureHydratedStorage` adapter in `lib/src/secure_hydrated_storage.dart` with `SecureHydratedStorage.build(secureStorage)` pre-loading for synchronous frame 1 hydration, exported via `import 'package:bloc_signals_hydrate/secure_storage.dart';`.
- Retained 100% pure Dart package compatibility for `bloc_signals_hydrate` (`pubspec.yaml` contains no Flutter dependencies).
- Added comprehensive unit tests in `test/shared_preferences_hydrated_storage_test.dart` and `test/secure_hydrated_storage_test.dart`.
- Updated `examples/persist_shared_preferences` and package README documentation.

### Self-Critical Review
## 1. Intent
- **Requirement**: Provide zero-boilerplate, pre-built storage adapters for `SharedPreferences` and `FlutterSecureStorage` as part of `package:bloc_signals_hydrate`.
- **Fulfillment**: Implemented `SharedPreferencesHydratedStorage` and `SecureHydratedStorage` as pure Dart adapters behind dedicated sub-library entrypoints.

## 2. Verification
- All 21 unit tests in `bloc_signals_hydrate` and widget tests in `examples/persist_shared_preferences` pass cleanly (`dart test`, `flutter test`).

## 3. Architecture
- **Pure Dart & Tree-Shaking Isolation**: Adapters use dynamic duck-typing for storage instances (`SharedPreferences` and `FlutterSecureStorage`), keeping `pubspec.yaml` free of Flutter dependencies.
- Sub-library exports (`lib/shared_preferences.dart`, `lib/secure_storage.dart`) allow full compiler tree-shaking for projects that do not use these specific storage backends.

## 4. Blast Radius
- Purely additive sub-library exports in `package:bloc_signals_hydrate`. Zero breaking changes.

## 5. Reviewer Defense
- **Q: Why separate sub-library entrypoints?**
  - **A**: Isolating them to `package:bloc_signals_hydrate/shared_preferences.dart` and `package:bloc_signals_hydrate/secure_storage.dart` ensures strict modularity and enables Dart tree-shaking so applications only compile the storage adapters they explicitly import.
