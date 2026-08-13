# GitHub Search Example (`BlocSignal`)

A GitHub repository search application demonstrating streamless debouncing and asynchronous request cancellation with `restartable()` in `BlocSignal`.

## ✨ Features

- **Streamless Request Cancellation (`restartable()`)**: Automatically cancels in-flight search requests when the user types a new character, ensuring stale responses are dropped without Rx Streams or RxDart.
- **Sealed State Hierarchy**: Clean state transitions (`SearchEmpty`, `SearchLoading`, `SearchSuccess`, `SearchError`) rendered via Dart 3 pattern matching.
- **Simulated API Repository**: Includes mock repository data with realistic network latency and rate-limit error simulation.

## 🔗 Upstream Reference

- Inspired by the classic [flutter_github_search](https://bloclibrary.dev/tutorials/flutter-github-search/) tutorial from `felangel/bloc`.

## 🚀 Running the Example

```bash
cd examples/github_search
flutter run
```

## 🧪 Running Tests

```bash
cd examples/github_search
flutter test
```
