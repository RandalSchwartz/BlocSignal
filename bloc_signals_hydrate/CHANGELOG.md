## 0.1.4

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
