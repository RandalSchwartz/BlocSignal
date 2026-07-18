---
name: signals
description: Best practices for Rody Davis's signals package version 7 with SignalModel.
---
# Signals v7 Best Practices

Use the following guidelines when working with the `signals` package in Dart or Flutter (especially v7+):

## 1. Core Principles
- **Unidirectional Data Flow**: Keep mutable signals private (prefixed with `_`). Expose them as public `ReadonlySignal<T>` views.
- **Synchronous Execution**: State changes propagate immediately and synchronously. Do not use `await` or `expectLater` for basic signal transitions.
- **Lifecycle Management**: Always manage the lifecycle of effects to avoid memory leaks. Use `SignalModel` and `createModel()` to bind effects to a scope.

## 2. SignalModel Pattern
In version 7, rather than using loose effects that require manual disposal, wrap state/logic within `createModel()`:

```dart
import 'package:signals/signals.dart';

class Controller {
  final _count = signal(0);
  ReadonlySignal<int> get count => _count;

  void increment() => _count.value++;
}

void main() {
  final model = createModel((constructor) {
    final controller = Controller();
    
    // Any effect created via the constructor context is bound to the model's lifecycle
    constructor.effect(() {
      print('Count changed: ${controller.count.value}');
    });
    
    return controller;
  });

  final controller = model.instance;
  controller.increment();

  // Cleanly disposes the controller and all bound effects
  model.dispose();
}
```

## 3. Implicit SignalModel encapsulation in base classes
When wrapping a business logic component (like a BLoC or Controller), initialize a `SignalModel` internally and dispose of it when the component is closed:

```dart
abstract class ManagedComponent {
  late final SignalModel<void> _lifecycleModel;

  ManagedComponent() {
    _lifecycleModel = createModel((constructor) {
      // Define internal effects bound to the constructor here
      constructor.effect(() {
        onStateChanged();
      });
    });
  }

  void onStateChanged();

  void close() {
    _lifecycleModel.dispose();
  }
}
```
