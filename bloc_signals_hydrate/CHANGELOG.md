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
