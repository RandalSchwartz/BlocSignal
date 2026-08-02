import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_weather_example/main.dart';

void main() {
  group('WeatherBlocSignal', () {
    late WeatherBlocSignal weatherBloc;

    setUp(() {
      weatherBloc = WeatherBlocSignal();
    });

    tearDown(() async {
      await weatherBloc.close();
    });

    test('initial state is WeatherInitial', () {
      expect(weatherBloc.stateValue, isA<WeatherInitial>());
    });

    test('WeatherRequested fetches weather for London', () async {
      weatherBloc.add(const WeatherRequested('London'));
      await Future.delayed(const Duration(milliseconds: 400));

      expect(weatherBloc.stateValue, isA<WeatherSuccess>());
      final s = weatherBloc.stateValue as WeatherSuccess;
      expect(s.weather.city, equals('London'));
      expect(s.weather.condition, equals(WeatherCondition.rainy));
    });

    test('UnitsToggled toggles Celsius to Fahrenheit', () async {
      weatherBloc.add(const WeatherRequested('London'));
      await Future.delayed(const Duration(milliseconds: 400));

      weatherBloc.add(const UnitsToggled());
      final s = weatherBloc.stateValue as WeatherSuccess;
      expect(s.units, equals(TemperatureUnits.fahrenheit));
    });
  });

  group('ThemeCubitSignal', () {
    test('updates theme color based on weather condition', () {
      final themeCubit = ThemeCubitSignal();
      themeCubit.updateTheme(WeatherCondition.clear);
      expect(themeCubit.stateValue, equals(Colors.orange));

      themeCubit.updateTheme(WeatherCondition.rainy);
      expect(themeCubit.stateValue, equals(Colors.indigo));
    });
  });

  group('WeatherApp Widget Test', () {
    testWidgets('renders initial prompt', (widgetTester) async {
      await widgetTester.pumpWidget(const WeatherApp());
      expect(find.text('Please search for a city.'), findsOneWidget);
    });
  });
}
