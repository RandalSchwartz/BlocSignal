# Colorband Dynamic Signals Example (`CubitSignal`)

A dynamic reactive color derivation application demonstrating granular state selection and synchronous color transformations with `CubitSignal`.

## ✨ Features

- **Dynamic Reactive Computations**: Calculates hex codes and complementary color contrasts dynamically from RGB channel values.
- **Granular Rebuild Isolation**: Uses `BlocSignalSelector` on individual RGB slider widgets so moving one slider does not rebuild untouched sliders.
- **Synchronous De-duplication**: Drops identical color updates synchronously to ensure maximum frame rate and smooth 60/120fps slider dragging.
- **Live Visual Preview**: Animated color banner reacting instantly to channel modifications.

## 🚀 Running the Example

```bash
cd examples/flutter_colorband
flutter run
```

## 🧪 Running Tests

```bash
cd examples/flutter_colorband
flutter test
```
