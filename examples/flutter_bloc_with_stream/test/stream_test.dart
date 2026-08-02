import 'package:bloc_signals/bloc_signals.dart';
import 'package:flutter_bloc_with_stream_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SensorCubitSignal', () {
    late SensorCubitSignal cubit;

    setUp(() {
      cubit = SensorCubitSignal();
    });

    tearDown(() async {
      await cubit.close();
    });

    test('initial reading value is 0.0', () {
      expect(cubit.stateValue.value, equals(0.0));
    });

    test('stream updates sensor values over time', () async {
      await Future.delayed(const Duration(milliseconds: 600));
      expect(cubit.stateValue.value, greaterThan(0.0));
    });

    test('cubit.toStream emits stream values', () async {
      final stream = cubit.toStream();
      expect(stream, isA<Stream<SensorReading>>());
    });
  });

  group('StreamInteropApp Widget Test', () {
    testWidgets('renders cards and stream interop titles',
        (widgetTester) async {
      await widgetTester.pumpWidget(const StreamInteropApp());
      expect(find.text('Stream Interop Example'), findsOneWidget);
      expect(find.text('Reactive Signal View (Watch)'), findsOneWidget);
    });
  });
}
