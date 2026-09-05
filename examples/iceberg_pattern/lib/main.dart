import 'dart:async';
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import 'application/task_board_cubit.dart';
import 'data/task_repository.dart';
import 'domain/task.dart';
import 'presentation/task_board_screen.dart';

void main() {
  final mockStreamController = StreamController<List<Task>>.broadcast();

  final initialTasks = <Task>[
    (
      id: '1',
      title: 'Draft Iceberg Pattern architecture article',
      isCompleted: true,
      tags: ['work', 'writing'],
    ),
    (
      id: '2',
      title: 'Review PR feedback on BlocSignal ecosystem',
      isCompleted: false,
      tags: ['work'],
    ),
    (
      id: '3',
      title: 'Grocery shopping & farmers market',
      isCompleted: false,
      tags: ['personal'],
    ),
  ];

  final repository = TaskRepository(
    cloudSnapshotStream: mockStreamController.stream,
    initialTasks: initialTasks,
    updateCloudTask: (id, isCompleted) async {
      // Simulate remote cloud write latency
      await Future<void>.delayed(const Duration(milliseconds: 600));
    },
    deleteCloudTask: (id) async {
      // Simulate server deletion latency
      await Future<void>.delayed(const Duration(milliseconds: 800));
    },
  );

  runApp(
    IcebergPatternApp(
      repository: repository,
    ),
  );
}

/// Root widget for the Iceberg Pattern example application.
class IcebergPatternApp extends StatelessWidget {
  const IcebergPatternApp({
    required this.repository,
    super.key,
  });

  final TaskRepository repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The Iceberg Pattern Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: BlocSignalProvider<TaskBoardCubit>(
        create: (context) => TaskBoardCubit(repository: repository),
        child: const TaskBoardScreen(),
      ),
    );
  }
}
