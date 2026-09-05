import 'dart:async';
import 'package:bloc_signals_test/bloc_signals_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iceberg_pattern_example/application/task_board_cubit.dart';
import 'package:iceberg_pattern_example/data/task_repository.dart';
import 'package:iceberg_pattern_example/domain/task.dart';

bool _tasksEqual(Task a, Task b) {
  if (a.id != b.id || a.title != b.title || a.isCompleted != b.isCompleted) {
    return false;
  }
  if (a.tags.length != b.tags.length) return false;
  for (var i = 0; i < a.tags.length; i++) {
    if (a.tags[i] != b.tags[i]) return false;
  }
  return true;
}

Matcher equalsTaskBoardState(TaskBoardState expected) {
  return predicate<TaskBoardState>((actual) {
    if (actual.activeFilterTag != expected.activeFilterTag) return false;
    if (actual.isDeletingTaskId != expected.isDeletingTaskId) return false;
    if (actual.hasSyncError != expected.hasSyncError) return false;
    if (actual.tasks.length != expected.tasks.length) return false;
    for (var i = 0; i < actual.tasks.length; i++) {
      if (!_tasksEqual(actual.tasks[i], expected.tasks[i])) return false;
    }
    return true;
  }, 'matches $expected');
}

void main() {
  group('The Iceberg Pattern Architecture Test Suite', () {
    late StreamController<List<Task>> cloudController;
    late TaskRepository repository;

    setUp(() {
      cloudController = StreamController<List<Task>>.broadcast();
      repository = TaskRepository(
        cloudSnapshotStream: cloudController.stream,
        updateCloudTask: (_, __) async {},
        deleteCloudTask: (_) async {},
      );
    });

    tearDown(() {
      repository.dispose();
      cloudController.close();
    });

    test('SyncRollbackException toString returns formatted message', () {
      final ex = SyncRollbackException('Network timeout');
      expect(ex.toString(), equals('SyncRollbackException: Network timeout'));
    });

    // 1. Initial Stream Sync Test
    blocSignalTest<TaskBoardCubit, TaskBoardState>(
      'emits updated task list synchronously upon cloud stream emission',
      build: () {
        repository = TaskRepository(
          cloudSnapshotStream: cloudController.stream,
          updateCloudTask: (_, __) async {},
          deleteCloudTask: (_) async {},
        );
        return TaskBoardCubit(repository: repository);
      },
      act: (_) {
        cloudController.add([
          (
            id: '1',
            title: 'Write Article',
            isCompleted: false,
            tags: ['work'],
          ),
        ]);
      },
      wait: const Duration(milliseconds: 10),
      expect: () => [
        equalsTaskBoardState((
          tasks: [
            (
              id: '1',
              title: 'Write Article',
              isCompleted: false,
              tags: ['work'],
            ),
          ],
          activeFilterTag: null,
          isDeletingTaskId: null,
          hasSyncError: false,
        )),
      ],
    );

    // 2. The 0ms Optimistic Test (emits before cloud completes)
    blocSignalTest<TaskBoardCubit, TaskBoardState>(
      'emits optimistic completed status in 0ms before cloud write finishes',
      build: () {
        final completer = Completer<void>();
        repository = TaskRepository(
          cloudSnapshotStream: cloudController.stream,
          updateCloudTask: (_, __) => completer.future, // Hanging future
          deleteCloudTask: (_) async {},
          initialTasks: [
            (
              id: '1',
              title: 'Test Task',
              isCompleted: false,
              tags: const <String>[],
            ),
          ],
        );
        return TaskBoardCubit(repository: repository);
      },
      act: (cubit) => cubit.toggleTask('1', false),
      expect: () => [
        equalsTaskBoardState((
          tasks: [
            (
              id: '1',
              title: 'Test Task',
              isCompleted: true,
              tags: const <String>[],
            ),
          ],
          activeFilterTag: null,
          isDeletingTaskId: null,
          hasSyncError: false,
        )),
      ],
    );

    // 3. Happy-path reconciliation: optimistic patch cleared on cloud confirmation
    blocSignalTest<TaskBoardCubit, TaskBoardState>(
      'reconciles optimistic patch and maintains completed status on cloud success',
      build: () {
        repository = TaskRepository(
          cloudSnapshotStream: cloudController.stream,
          updateCloudTask: (id, status) async {
            // Simulate cloud write then push updated snapshot
            cloudController.add([
              (
                id: '1',
                title: 'Test Task',
                isCompleted: status,
                tags: const <String>[],
              ),
            ]);
          },
          deleteCloudTask: (_) async {},
          initialTasks: [
            (
              id: '1',
              title: 'Test Task',
              isCompleted: false,
              tags: const <String>[],
            ),
          ],
        );
        return TaskBoardCubit(repository: repository);
      },
      act: (cubit) => cubit.toggleTask('1', false),
      wait: const Duration(milliseconds: 15),
      expect: () => [
        // Optimistic toggle
        equalsTaskBoardState((
          tasks: [
            (
              id: '1',
              title: 'Test Task',
              isCompleted: true,
              tags: const <String>[],
            ),
          ],
          activeFilterTag: null,
          isDeletingTaskId: null,
          hasSyncError: false,
        )),
      ],
    );

    // 4. In-flight guard: ignores rapid duplicate toggle on same task ID
    blocSignalTest<TaskBoardCubit, TaskBoardState>(
      'ignores concurrent duplicate toggle on same task ID while in flight',
      build: () {
        final completer = Completer<void>();
        repository = TaskRepository(
          cloudSnapshotStream: cloudController.stream,
          updateCloudTask: (_, __) => completer.future,
          deleteCloudTask: (_) async {},
          initialTasks: [
            (
              id: '1',
              title: 'Test Task',
              isCompleted: false,
              tags: const <String>[],
            ),
          ],
        );
        return TaskBoardCubit(repository: repository);
      },
      act: (cubit) {
        cubit.toggleTask('1', false);
        // Duplicate call while first is in flight
        cubit.toggleTask('1', false);
      },
      expect: () => [
        // Exactly one emission for the single accepted toggle
        equalsTaskBoardState((
          tasks: [
            (
              id: '1',
              title: 'Test Task',
              isCompleted: true,
              tags: const <String>[],
            ),
          ],
          activeFilterTag: null,
          isDeletingTaskId: null,
          hasSyncError: false,
        )),
      ],
    );

    // 5. The Pessimistic Delete Test (spinner shown during write, cleared on done)
    blocSignalTest<TaskBoardCubit, TaskBoardState>(
      'tracks isDeletingTaskId during write and clears it on completion',
      build: () {
        repository = TaskRepository(
          cloudSnapshotStream: cloudController.stream,
          updateCloudTask: (_, __) async {},
          deleteCloudTask: (_) async =>
              await Future<void>.delayed(const Duration(milliseconds: 15)),
        );
        return TaskBoardCubit(repository: repository);
      },
      act: (cubit) => cubit.deleteTask('1'),
      wait: const Duration(milliseconds: 30),
      expect: () => [
        // Frame 1: Spinner active
        equalsTaskBoardState((
          tasks: const <Task>[],
          activeFilterTag: null,
          isDeletingTaskId: '1',
          hasSyncError: false,
        )),
        // Frame 2: Write done, spinner cleared
        equalsTaskBoardState((
          tasks: const <Task>[],
          activeFilterTag: null,
          isDeletingTaskId: null,
          hasSyncError: false,
        )),
      ],
    );

    // 6. The Pessimistic Delete Failure Test (routes to onError and clears spinner)
    blocSignalTest<TaskBoardCubit, TaskBoardState>(
      'routes deleteTask failure to onError and clears spinner in finally',
      build: () {
        repository = TaskRepository(
          cloudSnapshotStream: cloudController.stream,
          updateCloudTask: (_, __) async {},
          deleteCloudTask: (_) async =>
              throw Exception('Server rejected delete'),
        );
        return TaskBoardCubit(repository: repository);
      },
      act: (cubit) => cubit.deleteTask('1'),
      wait: const Duration(milliseconds: 15),
      expect: () => [
        // Frame 1: Spinner active
        equalsTaskBoardState((
          tasks: const <Task>[],
          activeFilterTag: null,
          isDeletingTaskId: '1',
          hasSyncError: false,
        )),
        // Frame 2: Exception thrown, spinner cleared in finally
        equalsTaskBoardState((
          tasks: const <Task>[],
          activeFilterTag: null,
          isDeletingTaskId: null,
          hasSyncError: false,
        )),
      ],
      errors: () => [
        isA<Exception>(),
      ],
    );

    // 7. The Rollback & Error Test (reverts state and routes to onError)
    blocSignalTest<TaskBoardCubit, TaskBoardState>(
      'silently rolls back state and triggers onError on cloud rejection',
      build: () {
        repository = TaskRepository(
          cloudSnapshotStream: cloudController.stream,
          updateCloudTask: (_, __) async =>
              throw Exception('Cloud network timeout'),
          deleteCloudTask: (_) async {},
          initialTasks: [
            (
              id: '1',
              title: 'Test Task',
              isCompleted: false,
              tags: const <String>[],
            ),
          ],
        );
        return TaskBoardCubit(repository: repository);
      },
      act: (cubit) => cubit.toggleTask('1', false),
      wait: const Duration(milliseconds: 15),
      expect: () => [
        // 1. Optimistic toggle
        equalsTaskBoardState((
          tasks: [
            (
              id: '1',
              title: 'Test Task',
              isCompleted: true,
              tags: const <String>[],
            ),
          ],
          activeFilterTag: null,
          isDeletingTaskId: null,
          hasSyncError: false,
        )),
        // 2. Silent rollback to server truth + hasSyncError: true
        equalsTaskBoardState((
          tasks: [
            (
              id: '1',
              title: 'Test Task',
              isCompleted: false,
              tags: const <String>[],
            ),
          ],
          activeFilterTag: null,
          isDeletingTaskId: null,
          hasSyncError: true,
        )),
      ],
      errors: () => [
        isA<SyncRollbackException>(),
      ],
    );

    // 8. Active tag filtering test
    blocSignalTest<TaskBoardCubit, TaskBoardState>(
      'filters tasks correctly when activeFilterTag is set',
      build: () {
        repository = TaskRepository(
          cloudSnapshotStream: cloudController.stream,
          updateCloudTask: (_, __) async {},
          deleteCloudTask: (_) async {},
          initialTasks: [
            (id: '1', title: 'Task 1', isCompleted: false, tags: ['work']),
            (id: '2', title: 'Task 2', isCompleted: false, tags: ['personal']),
          ],
        );
        return TaskBoardCubit(repository: repository);
      },
      act: (cubit) {
        cubit.setFilterTag('work');
      },
      expect: () => [
        equalsTaskBoardState((
          tasks: [
            (id: '1', title: 'Task 1', isCompleted: false, tags: ['work']),
          ],
          activeFilterTag: 'work',
          isDeletingTaskId: null,
          hasSyncError: false,
        )),
      ],
    );
  });
}
