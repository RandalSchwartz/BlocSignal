# Infinite Scroll Mixin Example (`BlocSignal`)

A modern Flutter infinite scroll application demonstrating how to turn Flutter's `ScrollController` into a self-contained reactive state machine using `CubitSignalMixin` and `BlocSignalMixin`.

## ✨ Features

- **Self-Paging Controller (`CubitSignalMixin` + `BlocSignalMixin`)**: `PaginatedPostsController` extends Flutter's standard `ScrollController` while implementing `BlocSignalBase`. It listens directly to its own scroll geometry and dispatches pagination events.
- **100% `StatelessWidget` UI**: Eliminates all `StatefulWidget`, `initState`, and `dispose` lifecycle boilerplate. The controller plugs directly into `ListView.builder(controller: controller)` and `BlocSignalBuilder`.
- **Streamless Concurrency (`droppable()`)**: Uses the `droppable()` event transformer to synchronously drop duplicate scroll fling events without microtask lag or Rx streams.
- **Debounced Search (`restartable()`)**: Instantly cancels in-flight pagination requests and restarts query feeds using `restartable()`.
- **Automatic Lifecycle Management**: Seamlessly bound to `BlocSignalProvider` with safe double-dispose guards across both `close()` and `dispose()`.

## 🏗️ Architecture Comparison

| Metric | Classic Straight BLoC (`examples/infinite_scroll`) | Self-Paging Mixin (`examples/infinite_scroll_mixin`) |
| :--- | :--- | :--- |
| **Inheritance** | `PostsBloc extends BlocSignal<Event, State>` | `PaginatedPostsController extends ScrollController with CubitSignalMixin, BlocSignalMixin` |
| **UI Widget Type** | `StatefulWidget` | `StatelessWidget` |
| **Scroll Binding** | Manual `_controller.addListener(_onScroll)` in `initState` | Self-listening inside controller constructor |
| **Teardown** | Manual `_controller.removeListener` & `dispose()` in `State.dispose` | Automatic via `BlocSignalProvider` / `close()` |
| **Domain Separation** | Strict (BLoC has zero Flutter dependencies) | Unified (Controller is both UI scroll controller and state machine) |

## 🚀 Running the Example

```bash
cd examples/infinite_scroll_mixin
flutter run
```

## 🧪 Running Tests

```bash
cd examples/infinite_scroll_mixin
flutter test
```
