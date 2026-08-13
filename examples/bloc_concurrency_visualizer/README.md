# Streamless Event Concurrency Visualizer (`BlocSignal`)

An interactive Flutter application visualizing streamless event concurrency transformers in `BlocSignal`.

## ✨ Features

- **Streamless Event Concurrency**: Demonstrates `sequential()`, `droppable()`, and `restartable()` event transformers built with zero Rx Streams overhead.
- **Interactive Burst Dispatcher**: Dispatches rapid asynchronous event bursts to observe queueing, throttling, and cancellation behaviors in real time.
- **Pure Mutex Synchronization**: Highlights how FIFO ordering and non-blocking locks coordinate concurrency natively in Dart.
- **Live State Diagnostics**: Real-time progress indicators showing active tasks and completed execution logs.

## 🔗 Upstream Comparison

- Parallels the concurrency modes in `package:bloc_concurrency`, but executed without stream controllers or microtask queue delays.

## 🚀 Running the Example

```bash
cd examples/bloc_concurrency_visualizer
flutter run
```

## 🧪 Running Tests

```bash
cd examples/bloc_concurrency_visualizer
flutter test
```
