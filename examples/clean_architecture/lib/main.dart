/// # Clean Architecture Example — Presentation / Domain / Data Layering with BlocSignal
///
/// This example demonstrates how [BlocSignal] fits into clean, enterprise-grade multi-tier architecture:
/// - **Presentation Layer**: UI Views (`WeatherPage`) and [WeatherBloc] state containers.
/// - **Domain Layer**: Entity (`Weather`) and Repository Contract (`WeatherRepository`).
/// - **Data Layer**: Data Source (`RemoteWeatherDataSource`) implementing repository contracts.
///
/// By decoupling the repository contract from [WeatherBloc], business logic can be tested
/// in isolation without UI dependencies or live HTTP backends.
library;

import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';

// =============================================================================
// 1. Domain Layer (Entity & Repository Contract)
// =============================================================================

/// Weather domain entity.
///
/// Note: This state class could also use `package:equatable` (extending `Equatable` with `props`) for concise equality.
@immutable
class Weather {
  const Weather({
    required this.cityName,
    required this.temperatureCelsius,
    required this.condition,
  });

  final String cityName;
  final double temperatureCelsius;
  final String condition;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Weather &&
          runtimeType == other.runtimeType &&
          cityName == other.cityName &&
          temperatureCelsius == other.temperatureCelsius &&
          condition == other.condition;

  @override
  int get hashCode => Object.hash(cityName, temperatureCelsius, condition);
}

/// Abstract contract for weather data access.
abstract interface class WeatherRepository {
  Future<Weather> getWeather(String city);
}

// =============================================================================
// 2. Data Layer (Data Source Implementation)
// =============================================================================

/// Concrete repository fetching simulated weather data.
class MockWeatherRepository implements WeatherRepository {
  @override
  Future<Weather> getWeather(String city) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final normalized = city.trim().toLowerCase();

    if (normalized == 'tokyo') {
      return const Weather(
          cityName: 'Tokyo', temperatureCelsius: 18.5, condition: 'Sunny ☀️');
    } else if (normalized == 'london') {
      return const Weather(
          cityName: 'London', temperatureCelsius: 12.0, condition: 'Rainy 🌧️');
    } else {
      return Weather(
          cityName: city,
          temperatureCelsius: 22.0,
          condition: 'Partly Cloudy ⛅');
    }
  }
}

// =============================================================================
// 3. Presentation Layer (BlocSignal & Events)
// =============================================================================

sealed class WeatherEvent {
  const WeatherEvent();
}

final class WeatherRequested extends WeatherEvent {
  const WeatherRequested(this.city);
  final String city;
}

@immutable
sealed class WeatherState {
  const WeatherState();
}

final class WeatherInitial extends WeatherState {
  const WeatherInitial();
}

final class WeatherLoading extends WeatherState {
  const WeatherLoading();
}

final class WeatherSuccess extends WeatherState {
  const WeatherSuccess(this.weather);
  final Weather weather;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeatherSuccess &&
          runtimeType == other.runtimeType &&
          weather == other.weather;

  @override
  int get hashCode => weather.hashCode;
}

final class WeatherFailure extends WeatherState {
  const WeatherFailure(this.message);
  final String message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeatherFailure &&
          runtimeType == other.runtimeType &&
          message == other.message;

  @override
  int get hashCode => message.hashCode;
}

/// Manages weather fetching logic via dependency-injected [WeatherRepository].
class WeatherBloc extends BlocSignal<WeatherEvent, WeatherState> {
  WeatherBloc({required WeatherRepository repository})
      : _repository = repository,
        super(initialState: const WeatherInitial()) {
    on<WeatherRequested>((event, emit) async {
      emit(const WeatherLoading());
      try {
        final weather = await _repository.getWeather(event.city);
        emit(WeatherSuccess(weather));
      } catch (e) {
        emit(WeatherFailure(e.toString()));
      }
    }, transformer: restartable());
  }

  final WeatherRepository _repository;
}

// =============================================================================
// 4. Application Entrypoint & UI Layout
// =============================================================================

void main() {
  runApp(CleanArchitectureApp(repository: MockWeatherRepository()));
}

/// Root application widget.
class CleanArchitectureApp extends StatelessWidget {
  const CleanArchitectureApp({super.key, required this.repository});

  final WeatherRepository repository;

  @override
  Widget build(BuildContext context) {
    return BlocSignalProvider<WeatherBloc>(
      lazy: false,
      create: (context) => WeatherBloc(repository: repository),
      child: MaterialApp(
        title: 'BlocSignal Clean Architecture',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.cyan),
          useMaterial3: true,
        ),
        home: const WeatherPage(),
      ),
    );
  }
}

/// Main weather page widget.
class WeatherPage extends StatefulWidget {
  const WeatherPage({super.key});

  @override
  State<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage> {
  final _cityController = TextEditingController(text: 'Tokyo');

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clean Architecture Weather')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cityController,
                    decoration: const InputDecoration(
                      labelText: 'Enter City',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    context
                        .read<WeatherBloc>()
                        .add(WeatherRequested(_cityController.text));
                  },
                  child: const Text('Search'),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Expanded(
              child: Center(
                child: BlocSignalBuilder<WeatherBloc, WeatherState>(
                  builder: (context, state) {
                    return switch (state) {
                      WeatherInitial() =>
                        const Text('Search for a city to view weather.'),
                      WeatherLoading() => const CircularProgressIndicator(),
                      WeatherFailure(:final message) => Text('Error: $message',
                          style: const TextStyle(color: Colors.red)),
                      WeatherSuccess(:final weather) => Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              weather.cityName,
                              style: Theme.of(context).textTheme.headlineLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${weather.temperatureCelsius.toStringAsFixed(1)} °C',
                              style: Theme.of(context).textTheme.displaySmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              weather.condition,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                    };
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
