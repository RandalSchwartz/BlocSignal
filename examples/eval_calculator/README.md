# Eval Calculator Example (`BlocSignal`)

An event-driven calculator state machine built with Flutter and `BlocSignal`.

## ✨ Features

- **Deterministic State Machine**: Employs sealed `CalculatorEvent` classes (`DigitPressed`, `OperatorPressed`, `EqualsPressed`, `ClearPressed`) to manage arithmetic edge cases.
- **Synchronous Arithmetic Evaluation**: State transitions propagate immediately with zero microtask lag.
- **Granular Rebuilds**: Uses `BlocSignalSelector` to rebuild only the display screen when the calculated display value changes.
- **Division by Zero Safety**: Explicit error boundaries handling invalid operations gracefully.

## 🚀 Running the Example

```bash
cd examples/eval_calculator
flutter run
```

## 🧪 Running Tests

```bash
cd examples/eval_calculator
flutter test
```
