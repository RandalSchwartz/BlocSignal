# Flutter BLoC with Stream Example (`BlocSignal`)

A bidirectional stream interoperability example demonstrating how `BlocSignal` can ingest external Dart `Stream` events and export state updates back to streams using `.toStream()`.

## ✨ Features

- **Stream Ingestion**: Wraps external `Stream` sources into a clean `CubitSignal` container.
- **Stream Export (`.toStream()`)**: Demonstrates the `.toStream()` extension on `BlocSignalBase`, allowing legacy stream-based widgets or services to listen to signal changes.
- **Safe Resource Teardown**: Ensures `StreamSubscription` instances are properly canceled inside the container's `close()` lifecycle.
- **Side-by-Side Comparison**: Compares direct reactive rendering via `BlocSignalBuilder` with external `StreamSubscription` consumption.

## 🚀 Running the Example

```bash
cd examples/flutter_bloc_with_stream
flutter run
```

## 🧪 Running Tests

```bash
cd examples/flutter_bloc_with_stream
flutter test
```
