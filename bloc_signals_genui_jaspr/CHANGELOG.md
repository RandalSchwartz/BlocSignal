# Changelog

## 2.0.0

- **BREAKING (genui_jaspr)**: Upgrade `a2ui_core` to `^0.7.0` and `bloc_signals_genui` to `^2.0.0` (#434).
- **Feat (genui_jaspr)**: Expand `A2uiJasprCatalog.standard()` to all 16 `BasicCatalog` components (`List`, `Tabs`, `Modal`, `Icon`, `Image`, `CheckBox`, `ChoicePicker`, `Slider`, `DateTimeInput`) and add A2UI 1.0 conformance (`NodeAction` via `triggerAction`, `weight` `flex-grow` via `buildWeightedChildren`, `accessibility` ARIA/hidden envelope, `metadata`, `Slider.steps`, `ChoicePicker.filterable`, `ValidationResult` `asBool`) (#436).
- **Dependencies**: Bump `a2ui_core` dependency constraint to `^0.7.0` (#434).
- **Dependencies**: Bump `bloc_signals_genui` dependency constraint to `^2.0.0`.

## 1.0.0

- **Feat (genui)**: Add Jaspr web bindings, declarative surface views, and HTML DOM catalog adapters for A2UI (`bloc_signals_genui_jaspr`) (#259).
