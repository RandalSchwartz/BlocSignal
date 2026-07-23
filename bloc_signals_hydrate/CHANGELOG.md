## 0.1.0

- Initial release of `bloc_signals_hydrate`.
- Added `HydratedStorage` interface and zero-dependency `MemoryHydratedStorage`.
- Added `HydratedMixin`, `HydratedCubitSignal`, and `HydratedBlocSignal`.
- Supported `dynamic` / `Object?` JSON serialization (`int`, `String`, `List`, `Map`, `bool`) without map wrapping.
- Supported synchronous initial constructor hydration.
- Added `clear()` method for key deletion and state resets.
