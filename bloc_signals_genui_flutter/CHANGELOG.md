# Changelog

All notable changes to `bloc_signals_genui_flutter` will be documented in this file.

## Unreleased

- Added action submission recovery and error presentation (#284):
  - Added `cancelSubmission({String? error})` and `completeAction({String? error})` convenience methods on `A2uiComponentContext`.
  - Dismissed `ModalBarrier` overlay automatically upon submission cancellation or completion.
  - Added `validationErrorsBuilder` property to `A2uiSurfaceView` with a default Material error banner when validation errors are present.
- Added declarative composition methods to `A2uiFlutterCatalog` (#285):
  - `copyWith(Map<String, A2uiComponentWidgetBuilder> builders)` for extending or overriding component builders with isolated copies.
  - `copyWithout(Iterable<String> typesToRemove)` for pruning unwanted or restricted component types.
  - `registerAll(Map<String, A2uiComponentWidgetBuilder> builders)` for bulk builder registration.
  - `registeredTypes` getter exposing all currently registered component type names.

## 0.1.1

- Remediated defensive parsing and error boundaries (#269):
  - Added `safe_prop_parser.dart` (`asDouble`, `asInt`, `asString`, `extractChildId`, `extractChildIds`) for robust handling of dynamic LLM JSON properties.
  - Wrapped `A2uiSurfaceView` component rendering in safe error boundary fallback widgets.
  - Upgraded widget models (`A2uiButton`, `A2uiCard`, `A2uiColumn`, `A2uiRow`, `A2uiTextField`, `A2uiDivider`) to tolerate stringified numeric inputs and object-shaped child IDs.

## 0.1.0

- Initial release of `bloc_signals_genui_flutter`.
- Flutter catalog widgets for standard A2UI primitives (`A2uiButton`, `A2uiCard`, `A2uiColumn`, `A2uiDivider`, `A2uiRow`, `A2uiText`, `A2uiTextField`).
- Declarative `A2uiSurfaceView` widget with animated component transitions.
- Synchronous two-way data binding and form state propagation.
