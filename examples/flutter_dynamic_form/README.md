# Flutter Dynamic Form Example (`BlocSignal`)

A cascading dynamic dropdown form example demonstrating reactive field dependencies and option derivation with `computed()` signals.

## ✨ Features

- **Cascading Field Derivations**: Brand selection dynamically determines available models, and model selection dynamically populates vehicle trims using `computed()` signals.
- **Dynamic Form Validation**: Automatically derives `isFormComplete` reactively without storing duplicate boolean flags in state.
- **Synchronous Cascade Propagation**: Dropdown option lists refresh synchronously on the same frame when parent choices change.
- **Form Reset**: One-touch reset to clear all nested selections atomically.

## 🔗 Upstream Reference

- Inspired by the [flutter_dynamic_form](https://bloclibrary.dev/tutorials/flutter-dynamic-form/) example from `felangel/bloc`.

## 🚀 Running the Example

```bash
cd examples/flutter_dynamic_form
flutter run
```

## 🧪 Running Tests

```bash
cd examples/flutter_dynamic_form
flutter test
```
