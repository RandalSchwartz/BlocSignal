# BlocSignal Flutter Example App

An example Flutter application demonstrating modern state management using **`bloc_signals`**, **`bloc_signals_flutter`**, and **`kaisel`** routing.

## 🚀 Overview

This example demonstrates best practices for building reactive Flutter applications with `BlocSignal`:

1. **Constructor-Scoped `on<E>` Event Handlers**:
   - Registering type-safe event handlers using `on<Event>((event, emit) => ...)` inside constructor scopes.
   - Orchestrating synchronous and asynchronous handler executions cleanly without manual `onEvent` switch statements.

2. **Synchronous Reactive Propagation**:
   - State emissions via `emit()` propagate synchronously to widget subtrees in the exact same frame.
   - Built-in state de-duplication using `==` equality prevents unnecessary UI rebuilds.

3. **Type-Safe Routing with Kaisel**:
   - Sealed class route hierarchies (`AppRoute`) paired with `MaterialApp.router`.

4. **Dependency Injection & UI Scoping**:
   - `BlocSignalProvider` for managing BLoC lifecycles and automatic disposal.
   - `BlocSignalBuilder` for reactive UI rebuilds.
   - `context.read<T>()` for context-scoped BLoC lookups without rebuild dependencies.

## 📱 Features

- **Authentication Flow (`LoginBloc`)**:
  - Validates credentials and handles async authentication latency.
  - Implements `UsernameChanged`, `PasswordChanged`, `SubmitLogin`, and `Logout` event handlers.
- **Countdown Timer (`TimerBloc`)**:
  - Demonstrates stream subscription coordination inside BLoC event handlers.
  - Implements `TimerStarted`, `TimerPaused`, `TimerResumed`, `TimerReset`, and `_TimerTicked` event handlers.

## 🧪 Running Tests & App

- **Run Tests**:
  ```bash
  flutter test
  ```
- **Analyze Code**:
  ```bash
  flutter analyze
  ```
- **Run App**:
  ```bash
  flutter run
  ```
