import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_timer_example/main.dart';

void main() {
  group('TimerBlocSignal', () {
    late TimerBlocSignal timerBloc;

    setUp(() {
      timerBloc = TimerBlocSignal();
    });

    tearDown(() async {
      await timerBloc.close();
    });

    test('initial state is TimerInitial(60)', () {
      expect(timerBloc.stateValue, isA<TimerInitial>());
      expect(timerBloc.stateValue.duration, equals(60));
    });

    test('TimerStarted emits TimerRunInProgress', () {
      timerBloc.add(const TimerStarted(duration: 10));
      expect(timerBloc.stateValue, isA<TimerRunInProgress>());
      expect(timerBloc.stateValue.duration, equals(10));
    });

    test('TimerPaused emits TimerRunPause when in progress', () {
      timerBloc.add(const TimerStarted(duration: 10));
      timerBloc.add(const TimerPaused());
      expect(timerBloc.stateValue, isA<TimerRunPause>());
      expect(timerBloc.stateValue.duration, equals(10));
    });

    test('TimerResumed emits TimerRunInProgress when paused', () {
      timerBloc.add(const TimerStarted(duration: 10));
      timerBloc.add(const TimerPaused());
      timerBloc.add(const TimerResumed());
      expect(timerBloc.stateValue, isA<TimerRunInProgress>());
    });

    test('TimerReset resets back to TimerInitial(60)', () {
      timerBloc.add(const TimerStarted(duration: 10));
      timerBloc.add(const TimerReset());
      expect(timerBloc.stateValue, isA<TimerInitial>());
      expect(timerBloc.stateValue.duration, equals(60));
    });
  });

  group('TimerApp Widget Test', () {
    testWidgets('renders timer text and start button initially',
        (widgetTester) async {
      await widgetTester.pumpWidget(const TimerApp());
      expect(find.text('01:00'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);

      await widgetTester.tap(find.byIcon(Icons.play_arrow));
      await widgetTester.pump();

      expect(find.byIcon(Icons.pause), findsOneWidget);
      expect(find.byIcon(Icons.replay), findsOneWidget);
    });
  });
}
