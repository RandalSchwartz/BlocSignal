# Clean Architecture Example (`BlocSignal`)

A decoupled, layered application demonstrating how `BlocSignal` fits cleanly into multi-tier enterprise architecture.

## 🏛️ Architecture Layers

- **Presentation Layer**: UI widgets (`WeatherPage`) consuming `WeatherBloc` via `BlocSignalBuilder` and `BlocSignalProvider`.
- **Domain Layer**: Core domain entity (`Weather`) and abstract repository interface contract (`WeatherRepository`).
- **Data Layer**: Concrete data source implementations (`MockWeatherRepository`) fulfilling the repository contract.

## ✨ Features

- **Decoupled Business Logic**: The `WeatherBloc` depends strictly on the abstract `WeatherRepository` contract, enabling effortless mock injection and isolated unit testing.
- **Restartable Async Search**: Uses the `restartable()` event concurrency transformer to cancel superseded search requests on rapid input.
- **Pattern Matching UI**: Exhaustive Dart 3 `switch` expression handling of sealed states (`WeatherInitial`, `WeatherLoading`, `WeatherSuccess`, `WeatherFailure`).

## 🚀 Running the Example

```bash
cd examples/clean_architecture
flutter run
```

## 🧪 Running Tests

```bash
cd examples/clean_architecture
flutter test
```
