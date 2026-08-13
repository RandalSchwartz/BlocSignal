# Flutter Form Validation Example (`BlocSignal`)

A real-time synchronous form validation example showcasing primary vs. derived state separation with `computed()` signals in `BlocSignal`.

## ✨ Features

- **Primary vs. Derived State Architecture**: `FormValidationState` stores only the primary inputs (`email`, `password`, `isSubmitting`, `isSuccess`), while validation errors (`emailError`, `passwordError`) and form validity (`isValid`) are derived lazily via `computed()` signals.
- **Synchronous Input Validation**: Validates user typing in the exact same frame with 0ms microtask lag and zero input jitter.
- **Automatic Memoization**: Validation rules evaluate only when their respective inputs change, avoiding redundant regular expression executions.
- **Asynchronous Submission**: Handles submission progress spinners and success indicators cleanly.

## 🔗 Upstream Reference

- Inspired by the [flutter_form_validation](https://bloclibrary.dev/tutorials/flutter-form-validation/) example from `felangel/bloc`.

## 🚀 Running the Example

```bash
cd examples/flutter_form_validation
flutter run
```

## 🧪 Running Tests

```bash
cd examples/flutter_form_validation
flutter test
```
