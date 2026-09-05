import 'dart:async';
import 'package:signals_core/signals_core.dart';
import '../domain/task.dart';

/// Exception thrown when an optimistic mutation fails and state is rolled back.
class SyncRollbackException implements Exception {
  SyncRollbackException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'SyncRollbackException: $message';
}

/// The Submerged Engine: Quarantines raw asynchronous cloud streams into a
/// synchronous, cached reactive graph and handles optimistic reconciliation.
class TaskRepository {
  TaskRepository({
    required Stream<List<Task>> cloudSnapshotStream,
    required Future<void> Function(String id, bool isCompleted) updateCloudTask,
    required Future<void> Function(String id) deleteCloudTask,
    List<Task> initialTasks = const [],
  })  : _updateCloudTask = updateCloudTask,
        _deleteCloudTask = deleteCloudTask {
    _initEngine(cloudSnapshotStream, initialTasks);
  }

  final Future<void> Function(String id, bool isCompleted) _updateCloudTask;
  final Future<void> Function(String id) _deleteCloudTask;

  // In-flight guard against rapid re-entrant toggles
  final _inFlightToggles = <String>{};

  // Private Reactive Graph
  late final StreamSignal<List<Task>> _cloudStreamSignal;
  final _optimisticPatches = signal<Map<String, bool>>({});
  final _hasSyncError = signal(false);
  late final Computed<List<Task>> _computedTasks;

  void _initEngine(
    Stream<List<Task>> cloudSnapshotStream,
    List<Task> initialTasks,
  ) {
    _cloudStreamSignal = streamSignal(
      () => cloudSnapshotStream,
      options: AsyncSignalOptions<List<Task>>(initialValue: initialTasks),
    );

    _computedTasks = computed(() {
      final baseTasks = _cloudStreamSignal.value.value ?? const [];
      final overrides = _optimisticPatches.value;
      if (overrides.isEmpty) return baseTasks;

      return baseTasks.map((task) {
        final override = overrides[task.id];
        return override != null
            ? (
                id: task.id,
                title: task.title,
                isCompleted: override,
                tags: task.tags,
              )
            : task;
      }).toList();
    });
  }

  // Public Readonly Boundary
  ReadonlySignal<List<Task>> get tasks => _computedTasks;
  ReadonlySignal<bool> get hasSyncError => _hasSyncError;

  /// OPTIMISTIC MUTATION: Updates state across all screens in 0ms, synchronizes with cloud in background.
  Future<void> toggleTask(String id, bool currentStatus) async {
    if (_inFlightToggles.contains(id)) return;
    _inFlightToggles.add(id);

    final newStatus = !currentStatus;
    _optimisticPatches.value = {..._optimisticPatches.value, id: newStatus};

    try {
      await _updateCloudTask(id, newStatus);
      // Reconcile atomically using batch(): clear override and clear sync error
      batch(() {
        _hasSyncError.value = false;
        final updated = Map<String, bool>.from(_optimisticPatches.value)
          ..remove(id);
        _optimisticPatches.value = updated;
      });
    } catch (error, stackTrace) {
      // Rollback atomically using batch(): silently revert override and set sync error
      batch(() {
        final updated = Map<String, bool>.from(_optimisticPatches.value)
          ..remove(id);
        _optimisticPatches.value = updated;
        _hasSyncError.value = true;
      });
      Error.throwWithStackTrace(
        SyncRollbackException('Failed to update task $id. Reverted.', error),
        stackTrace,
      );
    } finally {
      _inFlightToggles.remove(id);
    }
  }

  /// PESSIMISTIC MUTATION: Awaits server confirmation before resolving.
  Future<void> deleteTask(String id) async {
    await _deleteCloudTask(id);
  }

  void dispose() {
    _inFlightToggles.clear();
    _cloudStreamSignal.dispose();
    _optimisticPatches.dispose();
    _hasSyncError.dispose();
    _computedTasks.dispose();
  }
}
