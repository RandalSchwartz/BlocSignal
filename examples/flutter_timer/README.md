# Flutter Timer Example (`BlocSignal`)

A reactive countdown timer application demonstrating periodic ticker stream ingestion, pause/resume state machines, and fine-grained `context.select` widget rebuilds.

## ✨ Features

- **Countdown State Machine**: Sealed states (`TimerInitial`, `TimerRunInProgress`, `TimerRunPause`, `TimerRunComplete`) representing distinct lifecycle phases.
- **Resource Lifecycle Management**: Automatically manages and cancels periodic `StreamSubscription` ticker subscriptions inside `close()`.
- **Granular Rebuilds via `context.select`**: `TimerText` listens only to `stateValue.duration`, preventing unnecessary rebuilds of action buttons or surrounding scaffolds.
- **Reactive Dynamic Background**: Dynamic animated background reflecting active timer status with `context.select`.

## 🔗 Upstream Reference

- Inspired by the classic [flutter_timer](https://bloclibrary.dev/tutorials/flutter-timer/) tutorial from `felangel/bloc`.

## 🚀 Running the Example

```bash
cd examples/flutter_timer
flutter run
```

## 🧪 Running Tests

```bash
cd examples/flutter_timer
flutter test
```
