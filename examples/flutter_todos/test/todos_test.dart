import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_todos_example/main.dart';

void main() {
  group('TodosBlocSignal', () {
    late TodosBlocSignal todosBloc;

    setUp(() {
      todosBloc = TodosBlocSignal(
        initialTodos: const [
          Todo(id: '1', title: 'Task 1', isCompleted: false),
          Todo(id: '2', title: 'Task 2', isCompleted: true),
        ],
      );
    });

    tearDown(() async {
      await todosBloc.close();
    });

    test('initial state and computed signals work', () {
      expect(todosBloc.stateValue.todos.length, equals(2));
      expect(todosBloc.activeCount.value, equals(1));
      expect(todosBloc.completedCount.value, equals(1));
      expect(todosBloc.filteredTodos.value.length, equals(2));
    });

    test('TodoAdded adds new todo', () {
      todosBloc.add(const TodoAdded(title: 'Task 3'));
      expect(todosBloc.stateValue.todos.length, equals(3));
      expect(todosBloc.activeCount.value, equals(2));
    });

    test('TodoToggled toggles completion state', () {
      todosBloc.add(const TodoToggled(id: '1'));
      expect(
          todosBloc.stateValue.todos.firstWhere((t) => t.id == '1').isCompleted,
          isTrue);
      expect(todosBloc.activeCount.value, equals(0));
    });

    test('TodosFilterChanged updates filteredTodos', () {
      todosBloc
          .add(const TodosFilterChanged(filter: TodosFilter.completedOnly));
      expect(todosBloc.filteredTodos.value.length, equals(1));
      expect(todosBloc.filteredTodos.value.first.id, equals('2'));
    });

    test('CompletedCleared removes completed items', () {
      todosBloc.add(const CompletedCleared());
      expect(todosBloc.stateValue.todos.length, equals(1));
      expect(todosBloc.stateValue.todos.first.id, equals('1'));
    });
  });

  group('TodosApp Widget Test', () {
    testWidgets('renders list and toggles todos', (widgetTester) async {
      await widgetTester.pumpWidget(const TodosApp());

      expect(
          find.text('Explore BlocSignal reactive primitives'), findsOneWidget);
      expect(find.text('Build clean Flutter examples'), findsOneWidget);

      // Tap Stats tab
      await widgetTester.tap(find.byIcon(Icons.show_chart));
      await widgetTester.pump();

      expect(find.text('Active Todos: 2'), findsOneWidget);
      expect(find.text('Completed Todos: 1'), findsOneWidget);
    });
  });
}
