import 'package:bloc_signals/bloc_signals.dart';
import 'package:signals_core/signals_core.dart';
import '../models/todo.dart';

/// Cubit managing a collection of [Todo]s.
///
/// Demonstrates how [CubitSignal] pairs with reactive [computed] signals
/// to derive filtered views and stats synchronously without extra events or RxDart.
class TodosCubit extends CubitSignal<List<Todo>> {
  /// Creates a [TodosCubit] with optional [initialTodos].
  TodosCubit([List<Todo> initialTodos = const []])
      : super(initialState: initialTodos) {
    // Derived signal: Active filter
    filter = signal(TodoFilter.all);

    // Derived signal: Filtered list of todos based on current [filter] and state.
    filteredTodos = computed(() {
      final currentFilter = filter.value;
      final currentTodos = stateValue;

      return switch (currentFilter) {
        TodoFilter.all => currentTodos,
        TodoFilter.active =>
          currentTodos.where((todo) => !todo.completed).toList(),
        TodoFilter.completed =>
          currentTodos.where((todo) => todo.completed).toList(),
      };
    });

    // Derived signal: Number of uncompleted todos.
    uncompletedCount = computed(() {
      return stateValue.where((todo) => !todo.completed).length;
    });

    // Derived signal: Number of completed todos.
    completedCount = computed(() {
      return stateValue.where((todo) => todo.completed).length;
    });
  }

  /// Current active filter option signal.
  late final Signal<TodoFilter> filter;

  /// Computed signal yielding the filtered list of todos.
  late final ReadonlySignal<List<Todo>> filteredTodos;

  /// Computed signal yielding the count of uncompleted todos.
  late final ReadonlySignal<int> uncompletedCount;

  /// Computed signal yielding the count of completed todos.
  late final ReadonlySignal<int> completedCount;

  /// Adds a new todo with the given [description].
  void addTodo(String description) {
    if (description.trim().isEmpty) return;
    final newTodo = Todo(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      description: description.trim(),
    );
    emit([...stateValue, newTodo]);
  }

  /// Toggles the completion status of the todo with [id].
  void toggle(String id) {
    emit([
      for (final todo in stateValue)
        if (todo.id == id) todo.copyWith(completed: !todo.completed) else todo,
    ]);
  }

  /// Edits the description of the todo with [id].
  void edit({required String id, required String description}) {
    emit([
      for (final todo in stateValue)
        if (todo.id == id) todo.copyWith(description: description) else todo,
    ]);
  }

  /// Removes the todo with [id].
  void remove(String id) {
    emit(stateValue.where((todo) => todo.id != id).toList());
  }

  /// Changes the active display [TodoFilter].
  void setFilter(TodoFilter newFilter) {
    filter.value = newFilter;
  }

  /// Clears all completed todos.
  void clearCompleted() {
    emit(stateValue.where((todo) => !todo.completed).toList());
  }

  /// Toggles completion status for all todos.
  void toggleAll() {
    final allCompleted = stateValue.every((todo) => todo.completed);
    emit([
      for (final todo in stateValue) todo.copyWith(completed: !allCompleted),
    ]);
  }

  @override
  Future<void> close() async {
    filter.dispose();
    filteredTodos.dispose();
    uncompletedCount.dispose();
    completedCount.dispose();
    await super.close();
  }
}
