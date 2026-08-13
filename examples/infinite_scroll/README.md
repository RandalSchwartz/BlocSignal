# Infinite Scroll Example (`BlocSignal`)

A high-performance paginated infinite scroll list demonstrating streamless event concurrency transformers (`droppable()` and `restartable()`) in `BlocSignal`.

## ✨ Features

- **Throttled Pagination (`droppable()`)**: Uses the `droppable()` event concurrency transformer to ignore redundant fetch triggers when the user rapidly scrolls past the threshold, preventing duplicate page requests.
- **Debounced Search Filtering (`restartable()`)**: Incorporates a search query filter using `restartable()` to instantly restart the feed on user input.
- **Zero Rx Streams**: Implements complete event throttling and cancellation using lightweight, streamless Dart primitives.
- **Scroll Controller Listener**: Listens to `ScrollController` offsets and dispatches `PostsFetched` when within 200px of the bottom.

## 🔗 Upstream Reference

- Inspired by the [flutter_infinite_list](https://bloclibrary.dev/tutorials/flutter-infinite-list/) tutorial from `felangel/bloc`.

## 🚀 Running the Example

```bash
cd examples/infinite_scroll
flutter run
```

## 🧪 Running Tests

```bash
cd examples/infinite_scroll
flutter test
```
