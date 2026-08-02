import 'package:bloc_concurrency_visualizer_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SequentialVisualizerBloc', () {
    test('executes tasks sequentially in order', () async {
      final bloc = SequentialVisualizerBloc();
      bloc.add(const TaskEvent(id: 1, durationMs: 100));
      bloc.add(const TaskEvent(id: 2, durationMs: 100));

      expect(bloc.stateValue.activeTasks, contains(1));
      await Future.delayed(const Duration(milliseconds: 250));
      expect(bloc.stateValue.completedTaskIds, equals([1, 2]));
      await bloc.close();
    });
  });

  group('DroppableVisualizerBloc', () {
    test('drops secondary task while first task is active', () async {
      final bloc = DroppableVisualizerBloc();
      bloc.add(const TaskEvent(id: 1, durationMs: 200));
      bloc.add(const TaskEvent(id: 2, durationMs: 200));

      await Future.delayed(const Duration(milliseconds: 250));
      expect(bloc.stateValue.completedTaskIds, equals([1]));
      await bloc.close();
    });
  });

  group('RestartableVisualizerBloc', () {
    test('restarts task on new event', () async {
      final bloc = RestartableVisualizerBloc();
      bloc.add(const TaskEvent(id: 1, durationMs: 200));
      await Future.delayed(const Duration(milliseconds: 50));
      bloc.add(const TaskEvent(id: 2, durationMs: 100));

      await Future.delayed(const Duration(milliseconds: 200));
      expect(bloc.stateValue.completedTaskIds, equals([2]));
      await bloc.close();
    });
  });

  group('ConcurrencyVisualizerApp Widget Test', () {
    testWidgets('renders tab bar and headers', (widgetTester) async {
      await widgetTester.pumpWidget(const ConcurrencyVisualizerApp());
      expect(find.text('Streamless Event Concurrency'), findsOneWidget);
      expect(find.text('Sequential'), findsOneWidget);
    });
  });
}
