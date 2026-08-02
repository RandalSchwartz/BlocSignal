import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// Single Todo entity.
@immutable
class Todo {
  const Todo({
    required this.id,
    required this.title,
    this.description = '',
    this.isCompleted = false,
  });

  final String id;
  final String title;
  final String description;
  final bool isCompleted;

  Todo copyWith({
    String? id,
    String? title,
    String? description,
    bool? isCompleted,
  }) {
    return Todo(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Todo &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          description == other.description &&
          isCompleted == other.isCompleted;

  @override
  int get hashCode =>
      id.hashCode ^ title.hashCode ^ description.hashCode ^ isCompleted.hashCode;
}

/// Filter criteria for list view.
enum TodosFilter { all, activeOnly, completedOnly }

/// Composite state of the Todos container.
@immutable
class TodosState {
  const TodosState({
    this.todos = const [],
    this.filter = TodosFilter.all,
  });

  final List<Todo> todos;
  final TodosFilter filter;

  TodosState copyWith({
    List<Todo>? todos,
    TodosFilter? filter,
  }) {
    return TodosState(
      todos: todos ?? this.todos,
      filter: filter ?? this.filter,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TodosState &&
          runtimeType == other.runtimeType &&
          filter == other.filter &&
          _listEquals(todos, other.todos);

  @override
  int get hashCode => filter.hashCode ^ todos.length.hashCode;

  static bool _listEquals(List<Todo> a, List<Todo> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Sealed class representing all Todo events.
sealed class TodosEvent {
  const TodosEvent();
}

final class TodoAdded extends TodosEvent {
  const TodoAdded({required this.title, this.description = ''});
  final String title;
  final String description;
}

final class TodoToggled extends TodosEvent {
  const TodoToggled({required this.id});
  final String id;
}

final class TodoDeleted extends TodosEvent {
  const TodoDeleted({required this.id});
  final String id;
}

final class TodosFilterChanged extends TodosEvent {
  const TodosFilterChanged({required this.filter});
  final TodosFilter filter;
}

final class CompletedCleared extends TodosEvent {
  const CompletedCleared();
}

final class AllToggled extends TodosEvent {
  const AllToggled();
}

/// Instructive Example: [TodosBlocSignal]
///
/// Demonstrates using `computed()` signals inside a BLoC container for zero-plumbing,
/// reactive state derivations.
///
/// **Educational Comparison vs Classic BLoC**:
/// In classic `package:bloc`, deriving filtered lists or counts often requires listening
/// to state streams or writing complex Rx stream combiners.
/// In `BlocSignal`, we simply declare `late final ReadonlySignal<List<Todo>> filteredTodos = computed(...)`.
/// Whenever `stateValue` emits, `filteredTodos`, `activeCount`, and `completedCount` recalculate
/// lazily and notify UI builders automatically.
class TodosBlocSignal extends BlocSignal<TodosEvent, TodosState> {
  TodosBlocSignal({List<Todo> initialTodos = const []})
      : super(initialState: TodosState(todos: initialTodos)) {
    on<TodoAdded>(_onAdded);
    on<TodoToggled>(_onToggled);
    on<TodoDeleted>(_onDeleted);
    on<TodosFilterChanged>(_onFilterChanged);
    on<CompletedCleared>(_onCompletedCleared);
    on<AllToggled>(_onAllToggled);
  }

  /// Reactive computed signal deriving filtered todo items based on active [TodosFilter].
  late final ReadonlySignal<List<Todo>> filteredTodos = computed(() {
    final s = stateValue;
    return switch (s.filter) {
      TodosFilter.all => s.todos,
      TodosFilter.activeOnly => s.todos.where((t) => !t.isCompleted).toList(),
      TodosFilter.completedOnly => s.todos.where((t) => t.isCompleted).toList(),
    };
  });

  /// Reactive computed signal deriving active uncompleted todo count.
  late final ReadonlySignal<int> activeCount = computed(() {
    return stateValue.todos.where((t) => !t.isCompleted).length;
  });

  /// Reactive computed signal deriving completed todo count.
  late final ReadonlySignal<int> completedCount = computed(() {
    return stateValue.todos.where((t) => t.isCompleted).length;
  });

  void _onAdded(TodoAdded event, void Function(TodosState) emit) {
    final newTodo = Todo(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: event.title,
      description: event.description,
    );
    emit(stateValue.copyWith(todos: [...stateValue.todos, newTodo]));
  }

  void _onToggled(TodoToggled event, void Function(TodosState) emit) {
    final updated = stateValue.todos.map((t) {
      return t.id == event.id ? t.copyWith(isCompleted: !t.isCompleted) : t;
    }).toList();
    emit(stateValue.copyWith(todos: updated));
  }

  void _onDeleted(TodoDeleted event, void Function(TodosState) emit) {
    final updated = stateValue.todos.where((t) => t.id != event.id).toList();
    emit(stateValue.copyWith(todos: updated));
  }

  void _onFilterChanged(TodosFilterChanged event, void Function(TodosState) emit) {
    emit(stateValue.copyWith(filter: event.filter));
  }

  void _onCompletedCleared(CompletedCleared event, void Function(TodosState) emit) {
    final active = stateValue.todos.where((t) => !t.isCompleted).toList();
    emit(stateValue.copyWith(todos: active));
  }

  void _onAllToggled(AllToggled event, void Function(TodosState) emit) {
    final allComplete = stateValue.todos.every((t) => t.isCompleted);
    final updated = stateValue.todos
        .map((t) => t.copyWith(isCompleted: !allComplete))
        .toList();
    emit(stateValue.copyWith(todos: updated));
  }
}

void main() {
  runApp(const TodosApp());
}

class TodosApp extends StatelessWidget {
  const TodosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BlocSignal Todos',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: BlocSignalProvider<TodosBlocSignal>(
        create: (_) => TodosBlocSignal(
          initialTodos: const [
            Todo(
                id: '1',
                title: 'Explore BlocSignal reactive primitives',
                isCompleted: true),
            Todo(
                id: '2',
                title: 'Build clean Flutter examples',
                isCompleted: false),
            Todo(
                id: '3',
                title: 'Write 100% test coverage',
                isCompleted: false),
          ],
        ),
        child: const TodosHomePage(),
      ),
    );
  }
}

class TodosHomePage extends StatefulWidget {
  const TodosHomePage({super.key});

  @override
  State<TodosHomePage> createState() => _TodosHomePageState();
}

class _TodosHomePageState extends State<TodosHomePage> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<TodosBlocSignal>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('BlocSignal Todos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.select_all),
            tooltip: 'Toggle All',
            onPressed: () => bloc.add(const AllToggled()),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear Completed',
            onPressed: () => bloc.add(const CompletedCleared()),
          ),
        ],
      ),
      body: _tabIndex == 0 ? const TodosListView() : const TodosStatsView(),
      floatingActionButton: _tabIndex == 0
          ? FloatingActionButton(
              onPressed: () => _showAddTodoDialog(context),
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (index) => setState(() => _tabIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Todos'),
          BottomNavigationBarItem(
              icon: Icon(Icons.show_chart), label: 'Stats'),
        ],
      ),
    );
  }

  void _showAddTodoDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add Todo'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Enter title...'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  context
                      .read<TodosBlocSignal>()
                      .add(TodoAdded(title: controller.text.trim()));
                }
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}

/// Educational Widget: [TodosListView]
///
/// Demonstrates reading `bloc.filteredTodos.value` inside [BlocSignalBuilder].
class TodosListView extends StatelessWidget {
  const TodosListView({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<TodosBlocSignal>();
    return Column(
      children: [
        const FilterSegmentedControl(),
        Expanded(
          child: BlocSignalBuilder<TodosBlocSignal, TodosState>(
            builder: (context, state) {
              final todos = bloc.filteredTodos.value;
              if (todos.isEmpty) {
                return const Center(child: Text('No todos found.'));
              }
              return ListView.builder(
                itemCount: todos.length,
                itemBuilder: (context, index) {
                  final item = todos[index];
                  return ListTile(
                    leading: Checkbox(
                      value: item.isCompleted,
                      onChanged: (_) => bloc.add(TodoToggled(id: item.id)),
                    ),
                    title: Text(
                      item.title,
                      style: TextStyle(
                        decoration: item.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () => bloc.add(TodoDeleted(id: item.id)),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Educational Widget: [FilterSegmentedControl]
///
/// Uses `context.watch<TodosBlocSignal>().stateValue.filter` to drive SegmentedButton UI.
class FilterSegmentedControl extends StatelessWidget {
  const FilterSegmentedControl({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.watch<TodosBlocSignal>();
    final currentFilter = bloc.stateValue.filter;
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SegmentedButton<TodosFilter>(
        segments: const [
          ButtonSegment(value: TodosFilter.all, label: Text('All')),
          ButtonSegment(value: TodosFilter.activeOnly, label: Text('Active')),
          ButtonSegment(
              value: TodosFilter.completedOnly, label: Text('Completed')),
        ],
        selected: {currentFilter},
        onSelectionChanged: (selection) {
          bloc.add(TodosFilterChanged(filter: selection.first));
        },
      ),
    );
  }
}

/// Educational Widget: [TodosStatsView]
///
/// Reads `bloc.activeCount.value` and `bloc.completedCount.value` derived reactively via [computed].
class TodosStatsView extends StatelessWidget {
  const TodosStatsView({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<TodosBlocSignal>();
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          BlocSignalBuilder<TodosBlocSignal, TodosState>(
            builder: (context, state) {
              return Text(
                'Active Todos: ${bloc.activeCount.value}',
                style: Theme.of(context).textTheme.headlineMedium,
              );
            },
          ),
          const SizedBox(height: 16),
          BlocSignalBuilder<TodosBlocSignal, TodosState>(
            builder: (context, state) {
              return Text(
                'Completed Todos: ${bloc.completedCount.value}',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.teal,
                    ),
              );
            },
          ),
        ],
      ),
    );
  }
}
