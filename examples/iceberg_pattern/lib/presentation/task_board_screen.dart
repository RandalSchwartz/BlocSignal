import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import 'package:iceberg_pattern_example/application/task_board_cubit.dart';

/// Presentation Layer: Pure synchronous projection (UI = ƒ(State))
/// with zero stream subscriptions, non-blocking sync error banner,
/// and snackbar alerts via standard BlocSignalListener.
class TaskBoardScreen extends StatelessWidget {
  /// Creates a [TaskBoardScreen].
  const TaskBoardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSignalListener<TaskBoardCubit, TaskBoardState>(
      listenWhen: (previous, current) =>
          !previous.hasSyncError && current.hasSyncError,
      listener: (context, state) {
        if (state.hasSyncError) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sync failed: Reverted to server truth.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      },
      child: BlocSignalBuilder<TaskBoardCubit, TaskBoardState>(
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Tasks (The Iceberg Pattern)'),
              bottom: state.hasSyncError
                  ? const PreferredSize(
                      preferredSize: Size.fromHeight(28),
                      child: ColoredBox(
                        color: Colors.amber,
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              'Offline / Sync Error — Showing Cached Tasks',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  : null,
            ),
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('All'),
                        selected: state.activeFilterTag == null,
                        onSelected: (_) =>
                            context.read<TaskBoardCubit>().setFilterTag(null),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Work'),
                        selected: state.activeFilterTag == 'work',
                        onSelected: (_) =>
                            context.read<TaskBoardCubit>().setFilterTag('work'),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Personal'),
                        selected: state.activeFilterTag == 'personal',
                        onSelected: (_) => context
                            .read<TaskBoardCubit>()
                            .setFilterTag('personal'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: state.tasks.isEmpty
                      ? const Center(child: Text('No tasks found'))
                      : ListView.builder(
                          itemCount: state.tasks.length,
                          itemBuilder: (context, index) {
                            final task = state.tasks[index];
                            final isDeleting =
                                state.isDeletingTaskId == task.id;

                            return ListTile(
                              leading: Checkbox(
                                value: task.isCompleted,
                                onChanged: isDeleting
                                    ? null
                                    : (_) => context
                                        .read<TaskBoardCubit>()
                                        .toggleTask(
                                          task.id,
                                          task.isCompleted,
                                        ),
                              ),
                              title: Text(
                                task.title,
                                style: TextStyle(
                                  decoration: task.isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              subtitle: task.tags.isEmpty
                                  ? null
                                  : Text(task.tags.join(', ')),
                              trailing: isDeleting
                                  ? const SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () => context
                                          .read<TaskBoardCubit>()
                                          .deleteTask(task.id),
                                    ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
