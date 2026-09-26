# Changelog

All notable changes to `bloc_signals_genui` will be documented in this file.

## Unreleased

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
