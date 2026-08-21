import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';

/// Weather conditions.
enum WeatherCondition { clear, rainy, cloudy, snowy, unknown }

/// Temperature units.
enum TemperatureUnits { celsius, fahrenheit }

extension TemperatureUnitsX on TemperatureUnits {
  bool get isCelsius => this == TemperatureUnits.celsius;
  bool get isFahrenheit => this == TemperatureUnits.fahrenheit;
}

/// Weather Data Model.
@immutable
class Weather {
  const Weather({
    required this.city,
    required this.condition,
    required this.temperatureCelsius,
  });

  final String city;
  final WeatherCondition condition;
  final double temperatureCelsius;

  double getTemperature(TemperatureUnits units) {
    if (units == TemperatureUnits.fahrenheit) {
      return (temperatureCelsius * 9 / 5) + 32;
    }
    return temperatureCelsius;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Weather &&
          runtimeType == other.runtimeType &&
          city == other.city &&
          condition == other.condition &&
          temperatureCelsius == other.temperatureCelsius;

  @override
  int get hashCode =>
      city.hashCode ^ condition.hashCode ^ temperatureCelsius.hashCode;
}

/// Weather Client Repository.
class WeatherRepository {
  const WeatherRepository();

  Future<Weather> fetchWeather(String city) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final normalized = city.trim().toLowerCase();
    if (normalized == 'london') {
      return const Weather(
          city: 'London',
          condition: WeatherCondition.rainy,
          temperatureCelsius: 14.0);
    } else if (normalized == 'chicago') {
      return const Weather(
          city: 'Chicago',
          condition: WeatherCondition.snowy,
          temperatureCelsius: -2.0);
    } else if (normalized == 'tokyo') {
      return const Weather(
          city: 'Tokyo',
          condition: WeatherCondition.cloudy,
          temperatureCelsius: 18.5);
    } else if (normalized == 'error') {
      throw Exception('City not found');
    }
    return Weather(
      city: city.trim(),
      condition: WeatherCondition.clear,
      temperatureCelsius: 25.0,
    );
  }
}

/// Sealed Weather State.
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
  const WeatherSuccess({
    required this.weather,
    this.units = TemperatureUnits.celsius,
  });

  final Weather weather;
  final TemperatureUnits units;

  WeatherSuccess copyWith({
    Weather? weather,
    TemperatureUnits? units,
  }) {
    return WeatherSuccess(
      weather: weather ?? this.weather,
      units: units ?? this.units,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeatherSuccess &&
          runtimeType == other.runtimeType &&
          weather == other.weather &&
          units == other.units;

  @override
  int get hashCode => weather.hashCode ^ units.hashCode;
}

final class WeatherFailure extends WeatherState {
  const WeatherFailure(this.error);
  final String error;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeatherFailure &&
          runtimeType == other.runtimeType &&
          error == other.error;

  @override
  int get hashCode => error.hashCode;
}

/// Sealed Weather Events.
sealed class WeatherEvent {
  const WeatherEvent();
}

final class WeatherRequested extends WeatherEvent {
  const WeatherRequested(this.city);
  final String city;
}

final class UnitsToggled extends WeatherEvent {
  const UnitsToggled();
}

/// Instructive Example: [WeatherBlocSignal]
///
/// Manages weather fetching, temperature unit conversion, and condition reporting.
///
/// **Educational Key Takeaways**:
/// - Shows how `BlocSignalConsumer` coordinates UI rebuilds with side-effects (e.g. updating app theme).
/// - Synchronous emissions allow unit tests to verify weather retrieval without stream delay.
class WeatherBlocSignal extends BlocSignal<WeatherEvent, WeatherState> {
  WeatherBlocSignal({WeatherRepository repository = const WeatherRepository()})
      : _repository = repository,
        super(initialState: const WeatherInitial()) {
    on<WeatherRequested>(_onRequested);
    on<UnitsToggled>(_onUnitsToggled);
  }

  final WeatherRepository _repository;

  Future<void> _onRequested(
      WeatherRequested event, void Function(WeatherState) emit) async {
    if (event.city.trim().isEmpty) return;
    emit(const WeatherLoading());
    try {
      final weather = await _repository.fetchWeather(event.city);
      emit(WeatherSuccess(weather: weather));
    } catch (e) {
      emit(WeatherFailure(e.toString()));
    }
  }

  void _onUnitsToggled(UnitsToggled event, void Function(WeatherState) emit) {
    if (stateValue is WeatherSuccess) {
      final s = stateValue as WeatherSuccess;
      final newUnits = s.units == TemperatureUnits.celsius
          ? TemperatureUnits.fahrenheit
          : TemperatureUnits.celsius;
      emit(s.copyWith(units: newUnits));
    }
  }
}

/// Instructive Example: [ThemeCubitSignal]
///
/// Manages dynamic application theme color based on active [WeatherCondition].
class ThemeCubitSignal extends CubitSignal<Color> {
  ThemeCubitSignal() : super(initialState: Colors.blue);

  void updateTheme(WeatherCondition? condition) {
    final color = switch (condition) {
      WeatherCondition.clear => Colors.orange,
      WeatherCondition.rainy => Colors.indigo,
      WeatherCondition.cloudy => Colors.blueGrey,
      WeatherCondition.snowy => Colors.lightBlue,
      _ => Colors.blue,
    };
    emit(color);
  }
}

void main() {
  runApp(const WeatherApp());
}

class WeatherApp extends StatelessWidget {
  const WeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSignalProvider<ThemeCubitSignal>(
      create: (_) => ThemeCubitSignal(),
      child: BlocSignalProvider<WeatherBlocSignal>(
        create: (_) => WeatherBlocSignal(),
        child: const WeatherAppView(),
      ),
    );
  }
}

class WeatherAppView extends StatelessWidget {
  const WeatherAppView({super.key});

  @override
  Widget build(BuildContext context) {
    final themeColor = context.select<ThemeCubitSignal, Color>(
      (cubit) => cubit.stateValue,
    );
    return MaterialApp(
      title: 'BlocSignal Weather',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: themeColor),
        useMaterial3: true,
      ),
      home: const WeatherPage(),
    );
  }
}

class WeatherPage extends StatelessWidget {
  const WeatherPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BlocSignal Weather'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              context.read<WeatherBlocSignal>().add(const UnitsToggled());
            },
          ),
        ],
      ),
      body: Center(
        child: BlocSignalConsumer<WeatherBlocSignal, WeatherState>(
          listener: (context, state) {
            if (state is WeatherSuccess) {
              context
                  .read<ThemeCubitSignal>()
                  .updateTheme(state.weather.condition);
            }
          },
          builder: (context, state) {
            return switch (state) {
              WeatherInitial() => const Text('Please search for a city.'),
              WeatherLoading() => const CircularProgressIndicator(),
              WeatherSuccess(:final weather, :final units) => Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      weather.city,
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${weather.getTemperature(units).toStringAsFixed(1)}°${units.isCelsius ? 'C' : 'F'}',
                      style: Theme.of(context).textTheme.displayLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Condition: ${weather.condition.name.toUpperCase()}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              WeatherFailure(:final error) => Text(
                  'Error: $error',
                  style: const TextStyle(color: Colors.red),
                ),
            };
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.search),
        onPressed: () async {
          final city = await Navigator.of(context).push<String>(
            MaterialPageRoute(builder: (_) => const SearchPage()),
          );
          if (city != null && context.mounted) {
            context.read<WeatherBlocSignal>().add(WeatherRequested(city));
          }
        },
      ),
    );
  }
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _textController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('City Search')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'City',
                  hintText: 'e.g. London, Chicago, Tokyo',
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                Navigator.of(context).pop(_textController.text);
              },
            ),
          ],
        ),
      ),
    );
  }
}
