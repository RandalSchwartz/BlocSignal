# Changelog

All notable changes to `bloc_signals_genui` will be documented in this file.

## Unreleased

- **Fix (genui)**: Add `maxResponseHistory` parameter (defaulting to 100) to `A2uiSurfaceBloc` to bound `_responseHistory` with FIFO eviction (#332).
- **Fix (genui)**: Replaced shallow map/list equality and collection-length hash codes on `A2uiActionResponse`, `SurfaceReady`, and `SurfaceSubmitting` with recursive `deepEquals` and `deepHashCode` helpers (`deep_collection_equality.dart`), and added a bounded 100-entry validation regular expression cache in `A2uiSurfaceBloc._validateForm` that caches malformed patterns as `null` on `FormatException` (#321).
- Decoupled active surface navigation coordinates from per-surface content revisions and added bounded surface lifecycle management (#292):
  - Promoted `A2uiSurfaceBloc.activeSurfaceId` to a reactive `ReadonlySignal<String?>` alongside `String? get activeSurfaceIdValue` for 0ms synchronous access.
  - Replaced global `_surfaceVersion` counter with per-surface `_surfaceVersions` (`Map<String, int>`), ensuring `SelectSurface` switches and sibling surface mutations never artificially increment unrelated surface versions.
  - Added `CloseSurface({required String surfaceId})` event and wire-level `DeleteSurfaceMessage` metadata cleanup to evict surfaces, prune action response history, and promote the most-recently-accessed surviving surface.
  - Added optional `maxSurfaces` parameter to `A2uiSurfaceBloc(maxSurfaces: k)` enforcing bounded Least-Recently-Used (LRU) eviction of non-active surfaces.
- Added multi-surface navigation, discovery, and targeted rendering support (#283):
  - Added `SelectSurface({required String surfaceId})` event to switch active surface and trigger immediate state transitions.
  - Added `availableSurfaceIds` getter on `A2uiSurfaceBloc` and `SurfaceReady` returning an unmodifiable list of registered surfaces.
  - Added `getSurfaceReady(String surfaceId)` on `A2uiSurfaceBloc` to query state for any existing surface without mutating the active surface.
  - Added defensive validation routing missing surface errors to `onError()` and emitting `SurfaceError`.
- Added action submission recovery and completion lifecycle events (#284):
  - Added `CancelSubmission({String? error, String? surfaceId})` event to safely abort in-flight submissions and return state to `SurfaceReady`.
  - Added `CompleteAction({String? error, String? surfaceId})` event to conclude successful or erroneous action processing.
  - Form state, inputs, and components are preserved across submission cancellation and completion.
  - Automatically appends error messages to `validationErrors` and marks `isValid: false` when an error is provided.

## 0.1.2

- Remediated runtime error handling and validation findings (#269):
  - Fixed error observability by notifying `onError()` and rethrowing fatal `Error` instances.
  - Added form validation contract enforcement (`_validateForm()`) before dispatching `A2uiActionResponse`.
  - Added polymorphic `surfaceId` on `A2uiSurfaceState` hierarchy and included `payload` in `SurfaceSubmitting.==`.
  - Replaced unbuffered action responses broadcast stream with race-free buffered replay stream.
  - Added `StandardCatalog` declaring `Card` and `Divider` schemas, and dynamic child/action normalization.
  - Selectively re-exported curated `a2ui_core` public types in `bloc_signals_genui.dart`.

## 0.1.1

- Added `A2uiActionResponse.getFormValue<T>(String path)` for ergonomic retrieval of form data supporting flat keys, leading-slash paths, and nested dot-notation access.

## 0.1.0

- Initial release of `bloc_signals_genui`.
- Pure-Dart `A2uiSurfaceBloc` state container bridging Google's A2UI protocol with `BlocSignal`.
- Sealed presentation state machine: `SurfaceInitial`, `SurfaceStreaming`, `SurfaceReady`, `SurfaceSubmitting`, `SurfaceError`.
- Polymorphic event envelopes: `IngestStream`, `ProcessMessage`, `ProcessJsonMessage`, `ProcessMessages`, `UpdateFormField`, `SubmitAction`, `ResetSurface`.
- Built-in `restartable()` concurrency protection for streaming chunk ingestion.
- Zero-latency synchronous form mutations on `DataModel`.
- Formatted `A2uiActionResponse` agent tool calling callbacks.
