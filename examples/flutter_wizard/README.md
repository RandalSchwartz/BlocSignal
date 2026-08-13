# Flutter Wizard Example (`BlocSignal`)

A multi-step registration wizard application demonstrating state accumulation and reactive step validation using `computed()` signals in `BlocSignal`.

## ✨ Features

- **Multi-Step State Aggregation**: Gathers user account information and personal profile details across linear Stepper navigation steps.
- **Computed Step Validation**: Derives `isStep1Valid`, `isStep2Valid`, and `canSubmit` dynamically with `computed()` signals without storing redundant validation booleans.
- **Stepper Integration**: Synchronously reflects step completion icons (`StepState.complete`) and step transitions (`onStepContinue`, `onStepCancel`).
- **Confirmation & Reset**: Summary review page with instant form restart capabilities.

## 🔗 Upstream Reference

- Inspired by the [flutter_wizard](https://bloclibrary.dev/tutorials/flutter-wizard/) tutorial from `felangel/bloc`.

## 🚀 Running the Example

```bash
cd examples/flutter_wizard
flutter run
```

## 🧪 Running Tests

```bash
cd examples/flutter_wizard
flutter test
```
