# Flutter Weather Example (`BlocSignal`)

A complete weather forecast application demonstrating REST API repository integration, dynamic theming, and temperature unit conversions with `BlocSignal`.

## ✨ Features

- **Multi-Bloc Coordination**: Uses `WeatherBlocSignal` to fetch weather data and `ThemeCubitSignal` to dynamically shift app themes based on meteorological conditions (`clear`, `rainy`, `cloudy`, `snowy`).
- **BlocSignalConsumer Side-Effects**: Listens to weather transitions via `BlocSignalConsumer` to trigger theme updates without coupling blocs directly together.
- **Unit Conversion**: Toggles seamlessly between Celsius (°C) and Fahrenheit (°F).
- **Asynchronous Search Flow**: Modal city search page dispatching weather queries to repository clients.

## 🔗 Upstream Reference

- Inspired by the [flutter_weather](https://bloclibrary.dev/tutorials/flutter-weather/) tutorial from `felangel/bloc`.

## 🚀 Running the Example

```bash
cd examples/flutter_weather
flutter run
```

## 🧪 Running Tests

```bash
cd examples/flutter_weather
flutter test
```
