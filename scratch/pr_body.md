Resolves #116

### Summary of Changes
- Updated `HydratedStorage.storage` to lazily fall back to `MemoryHydratedStorage()` inside an assertion block when accessed while uninitialized in debug/testing mode.
- Printed a clear, actionable diagnostic warning in debug mode instructing developers to configure production storage in `main()`.
- Added `HydratedStorage.isInitialized` getter to inspect storage initialization state.
- Added `HydratedStorage.reset()` helper for test tearDowns.
- Preserved 100% production tree-shaking for release builds by keeping the fallback inside an `assert` block.
- Added comprehensive unit tests in `test/hydrated_storage_uninitialized_test.dart`.

### Self-Critical Review
## 1. Intent
- **Requirement**: Fall back to `MemoryHydratedStorage` or provide clear diagnostic when `HydratedStorage.storage` is uninitialized.
- **Fulfillment**: Implemented assertion-backed lazy fallback and diagnostic message in `HydratedStorage.storage` getter, plus `isInitialized` and `reset()`.

## 2. Verification
- All 25 unit tests in `bloc_signals_hydrate` pass green (`dart test`).

## 3. Architecture
- **Production Tree-Shaking**: Enclosed fallback inside `assert(() { ... return true; }())`. Stripped out completely during release compilation.

## 4. Blast Radius
- Zero breaking changes. Existing explicit storage configurations work identically.
