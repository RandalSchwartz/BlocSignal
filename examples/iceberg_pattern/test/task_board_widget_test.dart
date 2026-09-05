import 'dart:async';
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iceberg_pattern_example/application/task_board_cubit.dart';
import 'package:iceberg_pattern_example/data/task_repository.dart';
import 'package:iceberg_pattern_example/domain/task.dart';
import 'package:iceberg_pattern_example/presentation/task_board_screen.dart';

void main() {
  group('TaskBoardScreen Widget Tests', () {
    late StreamController<List<Task>> cloudController;
    late TaskRepository repository;

    setUp(() {
      cloudController = StreamController<List<Task>>.broadcast();
    });

    tearDown(() {
      repository.dispose();
      cloudController.close();
    });

    Widget buildTestHarness(TaskBoardCubit cubit) {
      return MaterialApp(
        home: BlocSignalProvider<TaskBoardCubit>.value(
          value: cubit,
          child: TaskBoardScreen(),
        ),
      );
    }

    testWidgets('renders task list, handles filter chips, and checkbox tap',
        (tester) async {
      final updateCompleter = Completer<void>();
      repository = TaskRepository(
        cloudSnapshotStream: cloudController.stream,
        updateCloudTask: (_, __) => updateCompleter.future,
        deleteCloudTask: (_) async {},
        initialTasks: [
          (id: '1', title: 'Work Task', isCompleted: false, tags: ['work']),
          (
            id: '2',
            title: 'Personal Task',
            isCompleted: true,
            tags: ['personal']
          ),
        ],
      );
      final cubit = TaskBoardCubit(repository: repository);

      await tester.pumpWidget(buildTestHarness(cubit));
      await tester.pump();

      expect(find.text('Tasks (The Iceberg Pattern)'), findsOneWidget);
      expect(find.text('Work Task'), findsOneWidget);
      expect(find.text('Personal Task'), findsOneWidget);
      expect(
        find.text('Offline / Sync Error — Showing Cached Tasks'),
        findsNothing,
      );

      // Tap the Checkbox on the first task directly
      final checkboxFinder = find.byType(Checkbox).first;
      await tester.tap(checkboxFinder);
      await tester.pump();

      // State is optimistically toggled in 0ms!
      expect(cubit.stateValue.tasks.first.isCompleted, isTrue);

      // Filter by 'Work'
      await tester.tap(find.text('Work'));
      await tester.pump();

      expect(find.text('Work Task'), findsOneWidget);
      expect(find.text('Personal Task'), findsNothing);

      // Filter by 'Personal'
      await tester.tap(find.text('Personal'));
      await tester.pump();

      expect(find.text('Work Task'), findsNothing);
      expect(find.text('Personal Task'), findsOneWidget);

      // Reset to 'All'
      await tester.tap(find.text('All'));
      await tester.pump();

      expect(find.text('Work Task'), findsOneWidget);
      expect(find.text('Personal Task'), findsOneWidget);

      updateCompleter.complete();
      await cubit.close();
    });

    testWidgets('tap delete button shows spinner while in flight',
        (tester) async {
      final deleteCompleter = Completer<void>();
      repository = TaskRepository(
        cloudSnapshotStream: cloudController.stream,
        updateCloudTask: (_, __) async {},
        deleteCloudTask: (_) => deleteCompleter.future,
        initialTasks: [
          (
            id: '1',
            title: 'Task to Delete',
            isCompleted: false,
            tags: const []
          ),
        ],
      );
      final cubit = TaskBoardCubit(repository: repository);

      await tester.pumpWidget(buildTestHarness(cubit));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);

      // Tap delete button
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump();

      // Deletion spinner is active!
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete cloud delete
      deleteCompleter.complete();
      await tester.pump(const Duration(milliseconds: 10));

      expect(find.byType(CircularProgressIndicator), findsNothing);

      await cubit.close();
    });

    testWidgets(
        'displays offline banner and snackbar when hasSyncError is true',
        (tester) async {
      repository = TaskRepository(
        cloudSnapshotStream: cloudController.stream,
        updateCloudTask: (_, __) async => throw Exception('Network down'),
        deleteCloudTask: (_) async {},
        initialTasks: [
          (id: '1', title: 'Sample Task', isCompleted: false, tags: const []),
        ],
      );
      final cubit = TaskBoardCubit(repository: repository);

      await tester.pumpWidget(buildTestHarness(cubit));
      await tester.pump();

      expect(
        find.text('Offline / Sync Error — Showing Cached Tasks'),
        findsNothing,
      );

      // Trigger optimistic toggle that fails
      cubit.toggleTask('1', false);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(
        find.text('Offline / Sync Error — Showing Cached Tasks'),
        findsOneWidget,
      );
      expect(
        find.text('Sync failed: Reverted to server truth.'),
        findsOneWidget,
      );

      await cubit.close();
    });
  });
}
