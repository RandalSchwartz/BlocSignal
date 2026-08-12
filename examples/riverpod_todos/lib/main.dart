import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'cubits/todos_cubit.dart';
import 'models/todo.dart';
import 'widgets/todo_item_tile.dart';

void main() {
  runApp(const RiverpodTodosApp());
}

/// Root widget for the Riverpod Todos comparison application.
class RiverpodTodosApp extends StatelessWidget {
  /// Creates a [RiverpodTodosApp].
  const RiverpodTodosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Riverpod Todos (BlocSignal Port)',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: BlocSignalProvider<TodosCubit>(
        create: (_) => TodosCubit(const [
          Todo(id: '1', description: 'Learn BlocSignal', completed: true),
          Todo(
              id: '2', description: 'Port Riverpod examples', completed: false),
          Todo(id: '3', description: 'Enjoy zero codegen & fast updates'),
        ]),
        child: const TodosScreen(),
      ),
    );
  }
}

/// Primary screen displaying the todo list, input bar, filter tabs, and stats.
class TodosScreen extends StatefulWidget {
  /// Creates a [TodosScreen].
  const TodosScreen({super.key});

  @override
  State<TodosScreen> createState() => _TodosScreenState();
}

class _TodosScreenState extends State<TodosScreen> {
  late final TextEditingController _newTodoController;

  @override
  void initState() {
    super.initState();
    _newTodoController = TextEditingController();
  }

  @override
  void dispose() {
    _newTodoController.dispose();
    super.dispose();
  }

  void _addTodo() {
    final text = _newTodoController.text;
    if (text.trim().isNotEmpty) {
      context.read<TodosCubit>().addTodo(text);
      _newTodoController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TodosCubit>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Todos (Riverpod Port)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.select_all),
            tooltip: 'Toggle All',
            onPressed: () => cubit.toggleAll(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Input field for new todos
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newTodoController,
                    decoration: const InputDecoration(
                      labelText: 'What needs to be done?',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addTodo(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.add),
                  onPressed: _addTodo,
                ),
              ],
            ),
          ),

          // Filter tabs & counts
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Uncompleted count
                SignalBuilder(builder: (context) {
                  final count = cubit.uncompletedCount.value;
                  return Text(
                    '$count item${count == 1 ? '' : 's'} left',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  );
                }),
                const Spacer(),
                // Filter buttons
                SignalBuilder(builder: (context) {
                  final activeFilter = cubit.filter.value;
                  return SegmentedButton<TodoFilter>(
                    segments: const [
                      ButtonSegment(value: TodoFilter.all, label: Text('All')),
                      ButtonSegment(
                          value: TodoFilter.active, label: Text('Active')),
                      ButtonSegment(
                          value: TodoFilter.completed,
                          label: Text('Completed')),
                    ],
                    selected: {activeFilter},
                    onSelectionChanged: (selected) {
                      cubit.setFilter(selected.first);
                    },
                  );
                }),
              ],
            ),
          ),
          const Divider(),

          // Filtered list of todo items using computed signal
          Expanded(
            child: SignalBuilder(builder: (context) {
              final todos = cubit.filteredTodos.value;
              if (todos.isEmpty) {
                return const Center(
                  child: Text(
                    'No todos found',
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }
              return ListView.builder(
                itemCount: todos.length,
                itemBuilder: (context, index) {
                  final todo = todos[index];
                  return TodoItemTile(
                    key: ValueKey(todo.id),
                    todo: todo,
                  );
                },
              );
            }),
          ),
        ],
      ),
      bottomNavigationBar: SignalBuilder(builder: (context) {
        final completed = cubit.completedCount.value;
        if (completed == 0) return const SizedBox.shrink();
        return Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.all(8),
          child: Row(

            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.clear_all),
                label: Text('Clear completed ($completed)'),
                onPressed: () => cubit.clearCompleted(),
              ),
            ],
          ),
        );
      }),
    );
  }
}
