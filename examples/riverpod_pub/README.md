# Riverpod Pub Search Port Example (`BlocSignal`)

A direct architectural port of the official Riverpod Pub.dev search example demonstrating how family providers and cancellation tokens map to `BlocSignal` with the `restartable()` transformer.

## ✨ Features

- **Riverpod-to-BlocSignal Migration**: Replaces Riverpod's `FutureProvider.autoDispose.family` with `PubSearchBloc` for search result fetching and request handling.
- **Streamless Debouncing & Cancellation (`restartable()`)**: Automatically aborts previous in-flight HTTP requests when the search term changes, ensuring fast typing never displays outdated responses.
- **Package Details & Metric Badges**: Displays package names, descriptions, publishers, and popularity metrics in clean cards.
- **Synchronous State Propagation**: Immediate error, loading, and success transitions with zero microtask delay.

## 🔗 Upstream Reference

- Ported directly from Remi Rousselet's [Riverpod Pub Search Example](https://github.com/rrousselGit/riverpod/tree/master/examples/pub).

## 🚀 Running the Example

```bash
cd examples/riverpod_pub
flutter run
```

## 🧪 Running Tests

```bash
cd examples/riverpod_pub
flutter test
```
