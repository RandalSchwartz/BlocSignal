import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_todos_example/cubits/todos_cubit.dart';
import 'package:riverpod_todos_example/models/todo.dart';

void main() {
  group('TodosCubit (Riverpod Port)', () {
    late TodosCubit cubit;

    setUp(() {
      cubit = TodosCubit(const [
        Todo(id: '1', description: 'First todo', completed: false),
        Todo(id: '2', description: 'Second todo', completed: true),
      ]);
    });

    tearDown(() async {
      await cubit.close();
    });

    test('initial state sets up computed signals correctly', () {
      expect(cubit.stateValue.length, equals(2));
      expect(cubit.uncompletedCount.value, equals(1));
      expect(cubit.completedCount.value, equals(1));
      expect(cubit.filteredTodos.value.length, equals(2));
    });

    test('addTodo adds new item', () {
      cubit.addTodo('Third todo');
      expect(cubit.stateValue.length, equals(3));
      expect(cubit.uncompletedCount.value, equals(2));
    });

    test('toggle switches completion status and updates computed counts', () {
      cubit.toggle('1'); // Completed: true
      expect(cubit.stateValue.firstWhere((t) => t.id == '1').completed, isTrue);
      expect(cubit.uncompletedCount.value, equals(0));
      expect(cubit.completedCount.value, equals(2));
    });

    test('edit updates description', () {
      cubit.edit(id: '1', description: 'Updated todo');
      expect(
        cubit.stateValue.firstWhere((t) => t.id == '1').description,
        equals('Updated todo'),
      );
    });

    test('remove deletes item from list', () {
      cubit.remove('1');
      expect(cubit.stateValue.length, equals(1));
      expect(cubit.stateValue.any((t) => t.id == '1'), isFalse);
    });

    test('setFilter updates filteredTodos computed signal', () {
      cubit.setFilter(TodoFilter.active);
      expect(cubit.filteredTodos.value.length, equals(1));
      expect(cubit.filteredTodos.value.first.id, equals('1'));

      cubit.setFilter(TodoFilter.completed);
      expect(cubit.filteredTodos.value.length, equals(1));
      expect(cubit.filteredTodos.value.first.id, equals('2'));
    });

    test('clearCompleted removes completed items', () {
      cubit.clearCompleted();
      expect(cubit.stateValue.length, equals(1));
      expect(cubit.completedCount.value, equals(0));
    });

    test('toggleAll toggles all items', () {
      cubit.toggleAll(); // Since not all are completed, completes all
      expect(cubit.completedCount.value, equals(2));

      cubit.toggleAll(); // All are completed, so uncompletes all
      expect(cubit.completedCount.value, equals(0));
    });
  });
}
