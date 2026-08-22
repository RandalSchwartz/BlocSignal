---
series: "BlocSignal Architecture & Practice"
title: "Beyond Flutter: Running BlocSignal State Machines in Pure Dart, Jaspr Web, and CLI Tools"
published: true
description: Discover how BlocSignal's zero-Flutter core package enables unified state management across CLI tools, Jaspr web apps, and Dart Frog server backends with native DevTools telemetry.
tags: flutter, dart, webdev, architecture
---

## Universal State Management for Every Dart Platform

For years, developers have associated state management almost exclusively with Flutter UI widgets. While core packages like `package:bloc` are technically pure Dart, running stream-based state machines in non-UI Dart environments often feels clunky. Handling asynchronous streams (`bloc.stream.listen`) in CLI tools, Jaspr web apps, or server backends requires managing manual subscriptions and dealing with microtask event queue delays.

Modern Dart is far more than a Flutter UI engine. Dart now powers:
- 🖥️ **CLI Tools & Automation Scripts**
- 🌐 **Web Applications via Jaspr** (the Dart web framework for SSR & static sites)
- ☁️ **Server-Side Backends via Serverpod or Dart Frog**
- 📦 **Shared Domain Libraries & Full-Stack Monorepos**

With [**`BlocSignal`**](https://github.com/RandalSchwartz/BlocSignal), running state machines across pure Dart targets becomes effortless. By replacing asynchronous stream pipelines with synchronous, reactive signals, `BlocSignal` brings **0ms synchronous state reads (`.stateValue`)**, **declarative `computed()` composition**, and **universal DevTools telemetry** to every Dart platform!

In this article, we’ll explore how `BlocSignal` unlocks universal state management across CLI tools, Jaspr web apps, server backends, and Flutter applications with zero code duplication.

---

## 🏗️ The Pure Dart Architecture (`package:bloc_signals`)

`BlocSignal` is designed around strict package separation:

```plaintext
┌─────────────────────────────────────────────────────────────┐
│               bloc_signals (100% Pure Dart)                 │
│  - BlocSignalBase, CubitSignal, BlocSignal                     │
│  - Signal<T>, ReadonlySignal<T>, computed()                   │
│  - Streamless Transformers (droppable, restartable, Mutex)  │
│  - DevTools & Observer Hooks (dart:developer)              │
└──────────────────────────────┬──────────────────────────────┘
                               │
       ┌───────────────────────┴───────────────────────┐
       ▼                                               ▼
bloc_signals_flutter                            bloc_signals_riverpod
(Widget bindings, SignalBuilder,                 (Bidirectional Riverpod
 BlocSignalProvider, context.select)              Interop Adapters)
```

1. **`package:bloc_signals` (Core)**: Has **zero dependencies on the Flutter SDK**. It compiles natively for Dart VM, Dart Web (`dart2js` / `dart2wasm`), and CLI executables.
2. **`package:bloc_signals_flutter` (Flutter Bindings)**: Adds optional Flutter UI wrappers (`SignalBuilder`, `BlocSignalProvider`, `context.select`) for Flutter applications.

Because the core engine lives in pure Dart, your business logic, event handlers, and signal graphs can be shared 100% untouched between your server, CLI, web, and mobile targets!

---

## 🛠️ Use Case 1: Terminal CLI Tools & Background Workers

Imagine building a CLI deployment tool or background task runner in Dart. You want predictable state transitions, logging observers, and event queuing without needing Flutter UI.

With `bloc_signals`, you build your state machine directly in pure Dart:

```dart
import 'dart:async';
import 'package:bloc_signals/bloc_signals.dart';

// 1. Define Events & State
sealed class DeployEvent {}
class StartDeploy extends DeployEvent {}
class StepCompleted extends DeployEvent { final String step; StepCompleted(this.step); }

class DeployState {
  final String status;
  final List<String> completedSteps;
  const DeployState({this.status = 'Idle', this.completedSteps = const []});
}

// 2. Pure Dart BLoC State Machine
class DeployBloc extends BlocSignal<DeployEvent, DeployState> {
  DeployBloc() : super(const DeployState()) {
    on<StartDeploy>((event, emit) async {
      emit(DeployState(status: 'Running', completedSteps: stateValue.completedSteps));
      
      await _runStep('Compiling Assets');
      emit(DeployState(status: 'Running', completedSteps: [...stateValue.completedSteps, 'Compiling Assets']));

      await _runStep('Uploading Bundle');
      emit(DeployState(status: 'Finished', completedSteps: [...stateValue.completedSteps, 'Uploading Bundle']));
    });
  }

  Future<void> _runStep(String name) async {
    await Future.delayed(const Duration(milliseconds: 500));
  }
}

// 3. Run in CLI main()
Future<void> main() async {
  // Attach observer for automatic console logging
  BlocSignalObserver.observer = StandardLogObserver();

  final deployer = DeployBloc();
  
  // Watch state synchronously via signal!
  deployer.state.subscribe((state) {
    print('--> CLI Status Update: ${state.status} (${state.completedSteps.length} steps complete)');
  });

  deployer.add(StartDeploy());
  await Future.delayed(const Duration(seconds: 2));
  await deployer.close();
}

class StandardLogObserver extends BlocSignalObserver {
  @override
  void onTransition(BlocSignalBase bloc, Transition transition) {
    print('[LOG] ${bloc.runtimeType}: ${transition.currentState.status} -> ${transition.nextState.status}');
  }
}
```

Running `dart run bin/deploy.dart` executes the BLoC state machine natively with full observer logging—zero Flutter engine required!

---

## 🌐 Use Case 2: Web Applications with Jaspr (Dart Web Framework)

[**Jaspr**](https://jaspr.site/) is the modern Dart web framework that enables server-side rendering (SSR), static site generation (SSG), and web hydration in pure Dart.

Because Jaspr components render HTML DOM elements instead of Flutter Canvas widgets, traditional `flutter_bloc` widgets cannot be used.

With `BlocSignal`, because `bloc.state` is natively a `ReadonlySignal<S>`, it integrates seamlessly into Jaspr components!

```dart
import 'package:jaspr/jaspr.dart';
import 'package:bloc_signals/bloc_signals.dart';

// Shared BLoC used across Web, Server, and Mobile!
class CounterBloc extends CubitSignal<int> {
  CounterBloc() : super(0);
  void increment() => emit(stateValue + 1);
}

// Jaspr Web Component
class WebCounterView extends StatelessComponent {
  final CounterBloc counter;
  const WebCounterView({required this.counter, super.key});

  @override
  Iterable<Component> build(BuildContext context) sync* {
    // 1. Subscribe to state signal directly in Jaspr!
    yield div([
      h1([text('Count: ${counter.stateValue}')]),
      button(
        onClick: () => counter.increment(),
        [text('Increment')],
      ),
    ]);
  }
}
```

Your BLoC state machines compile directly to lightweight WebAssembly (`dart2wasm`) or JavaScript (`dart2js`) without bringing down the heavy Flutter Web engine canvas!

---

## ☁️ Use Case 3: Full-Stack Backends (Serverpod)

When building backend services in **Serverpod** (or Dart Frog / Shelf), managing complex server session caches, multi-step transaction pipelines, or real-time streaming state containers requires reliable state machines.

`BlocSignal` brings enterprise BLoC state containers and synchronous state inspections directly to Serverpod endpoints:

```dart
import 'package:serverpod/serverpod.dart';
import 'package:bloc_signals/bloc_signals.dart';

class UserSessionEndpoint extends Endpoint {
  final sessionState = SessionManagerCubit();

  Future<bool> validateUserSession(Session session, String userId) async {
    // ⚡️ Synchronous, zero-latency state read on the server!
    if (sessionState.stateValue.activeUserIds.contains(userId)) {
      return true;
    }

    // Trigger state transition logic
    sessionState.registerActiveUser(userId);
    return true;
  }
}
```

Because `.stateValue` reads synchronously, your server endpoints inspect state instantly without awaiting microtask event loop ticks, guaranteeing high-throughput request handling.

---

## 📡 Universal Observability via `dart:developer`

One of the biggest pain points of building non-UI Dart applications is a lack of developer tools and telemetry.

`BlocSignal` includes `DevToolsBlocSignalObserver`, which posts state transition events directly through `dart:developer`’s SDK protocol (`developer.postEvent`).

```dart
void main() {
  // Enables VM Service DevTools telemetry for ANY Dart process!
  BlocSignalObserver.observer = DevToolsBlocSignalObserver();
  
  final bloc = MyBusinessBloc();
  // State transitions, errors, and lifecycle events are automatically 
  // streamed to Dart DevTools timeline & VM Service inspect panels!
}
```

Whether your app runs in the terminal, on a Dart Frog server, in a Jaspr web browser, or inside a Flutter iOS/Android app, **the exact same DevTools inspector and event timeline works everywhere**!

---

## 📊 Feature Matrix: Classic Stream BLoC vs. Universal `BlocSignal`

| Feature / Capability | Classic Stream BLoC (`package:bloc`) | Universal `BlocSignal` |
| :--- | :--- | :--- |
| **State Primitive** | Asynchronous Stream (`bloc.stream`) | Synchronous `ReadonlySignal<S>` (`bloc.state`) |
| **State Read Latency** | Asynchronous Microtask Queue | **Synchronous 0ms Read (`.stateValue`)** |
| **Derived Composition** | Stream Transformers / RxDart | **Declarative `computed()` Signals** |
| **Jaspr Web & HTML DOM** | Manual stream subscriptions in components | **Native Signal DOM Bindings** |
| **Serverpod Endpoints** | Async stream listeners / future ticks | **Synchronous 0ms `.stateValue` Reads** |
| **DevTools Telemetry** | Basic print logs / observers | **Universal `dart:developer` VM Service Events** |
| **De-duplication** | Manual `distinct()` / Equatable | **Automatic `==` Signal De-duplication** |

---

## 🎯 Conclusion

State management shouldn't be trapped inside UI widget trees or restricted by asynchronous stream event loops.

By grounding BLoC state containers on pure Dart signals, **`BlocSignal`** empowers you to write your business logic once and deploy it seamlessly across full-stack Dart applications:

- 🖥️ **CLI Tools**: Clean event observers and terminal state machines.
- 🌐 **Jaspr Web**: Native HTML DOM rendering with WASM compilation.
- ☁️ **Serverpod Backends**: Synchronous 0ms state reads for high-throughput APIs.
- 📱 **Flutter Mobile/Desktop**: Rich UI widget bindings with zero boilerplate.

### 🔗 Explore the Ecosystem
- 📦 **`bloc_signals` on pub.dev**: [pub.dev/packages/bloc_signals](https://pub.dev/packages/bloc_signals)
- 🌐 **Jaspr Web Framework**: [jaspr.site](https://jaspr.site)
- 🐙 **GitHub Repository**: [github.com/RandalSchwartz/BlocSignal](https://github.com/RandalSchwartz/BlocSignal)
