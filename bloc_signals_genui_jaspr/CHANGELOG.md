# Changelog

## Unreleased

- **Feat (genui_jaspr)**: Bridge `function_call_evaluated` operational telemetry for `NodeAction`-bound `functionCall`, `call`, and `@call` buttons in `A2uiComponentContext.triggerAction` (#514).
- **Fix (genui_jaspr)**: Add bounded numeric helpers (`asNonNegativeDouble`, `asBoundedDouble`, `asBoundedInt`), validate SVG icon paths, enforce `TextField` `maxlength`, scope `ChoicePicker` radio names by surface/dataPath/sibling, propagate `siblingDisambiguator` through `A2uiSurfaceView`, isolate `A2uiModal` render budgets via `buildIsolatedChild`, and catch `NodeAction` `Future` `Exception` rejections in `triggerAction` (#478).

## 2.1.0

- **Feat (genui_jaspr)**: Re-export shared hardened `A2uiImageUrlPolicy` from `bloc_signals_genui` and enforce it in `buildA2uiImage`, `registerStandardComponents`, and `A2uiJasprCatalog.standard` via `{A2uiImageUrlPolicy imagePolicy = const A2uiImageUrlPolicy()}` (#463).
- **Fix (genui_jaspr)**: Clamp `buildA2uiSlider` `min`/`max` bounds to `[-1e12, 1e12]` with finite-span fallback `[0.0, 100.0]` and cap `steps` to `[1, 1000]` via `parseSliderRange` (#472).
- **Dependencies**: Bump `bloc_signals_genui` to `^2.1.0`.

## 2.0.2

- **Fix (genui_jaspr)**: Guard `asDouble` and `asInt` in `safe_prop_parser.dart` against non-finite numeric and string inputs (`NaN`, `Infinity`, `-Infinity`), falling back to `defaultValue` (#424).
- **Fix (genui_jaspr)**: Allowlist Button variant before interpolating into DOM CSS classes (#425).
- **Dependencies**: Bump `bloc_signals_genui` dependency constraint to `^2.0.2`.

## 2.0.1

- **Fix (genui_jaspr)**: Enforce per-render tree depth (`maxDepth`, defaulting to `A2uiSurfaceView.defaultMaxDepth` = `32`) and total node budget (`nodeBudget`, defaulting to `A2uiSurfaceView.defaultNodeBudget` = `1000`) in `A2uiSurfaceView`, rendering localized fallback components when exceeded (#415).
- **Dependencies**: Bump `bloc_signals_genui` dependency constraint to `^2.0.1`.

## 2.0.0

- **BREAKING (genui_jaspr)**: Upgrade `a2ui_core` to `^0.7.0` and `bloc_signals_genui` to `^2.0.0` (#434).
- **Feat (genui_jaspr)**: Expand `A2uiJasprCatalog.standard()` to all 16 `BasicCatalog` components (`List`, `Tabs`, `Modal`, `Icon`, `Image`, `CheckBox`, `ChoicePicker`, `Slider`, `DateTimeInput`) and add A2UI 1.0 conformance (`NodeAction` via `triggerAction`, `weight` `flex-grow` via `buildWeightedChildren`, `accessibility` ARIA/hidden envelope, `metadata`, `Slider.steps`, `ChoicePicker.filterable`, `ValidationResult` `asBool`) (#436).
- **Dependencies**: Bump `a2ui_core` dependency constraint to `^0.7.0` (#434).
- **Dependencies**: Bump `bloc_signals_genui` dependency constraint to `^2.0.0`.

## 1.0.0

- **Feat (genui)**: Add Jaspr web bindings, declarative surface views, and HTML DOM catalog adapters for A2UI (`bloc_signals_genui_jaspr`) (#259).
