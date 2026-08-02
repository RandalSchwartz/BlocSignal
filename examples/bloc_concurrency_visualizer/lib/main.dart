import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';

/// Event representing a task execution request.
final class TaskEvent {
  const TaskEvent({required this.id, required this.durationMs});
  final int id;
  final int durationMs;
}

/// State recording active and completed task logs.
@immutable
class VisualizerState {
  const VisualizerState({
    this.activeTasks = const [],
    this.completedTaskIds = const [],
    this.droppedTaskIds = const [],
  });

  final List<int> activeTasks;
  final List<int> completedTaskIds;
  final List<int> droppedTaskIds;

  VisualizerState copyWith({
    List<int>? activeTasks,
    List<int>? completedTaskIds,
    List<int>? droppedTaskIds,
  }) {
    return VisualizerState(
      activeTasks: activeTasks ?? this.activeTasks,
      completedTaskIds: completedTaskIds ?? this.completedTaskIds,
      droppedTaskIds: droppedTaskIds ?? this.droppedTaskIds,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VisualizerState &&
          runtimeType == other.runtimeType &&
          _listEquals(activeTasks, other.activeTasks) &&
          _listEquals(completedTaskIds, other.completedTaskIds) &&
          _listEquals(droppedTaskIds, other.droppedTaskIds);

  @override
  int get hashCode =>
      activeTasks.length.hashCode ^
      completedTaskIds.length.hashCode ^
      droppedTaskIds.length.hashCode;

  static bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Base Visualizer Bloc.
abstract class BaseVisualizerBloc
    extends BlocSignal<TaskEvent, VisualizerState> {
  BaseVisualizerBloc() : super(initialState: const VisualizerState());

  void clearLogs() => emit(const VisualizerState());
}

/// 1. Sequential Visualizer Bloc
class SequentialVisualizerBloc extends BaseVisualizerBloc {
  SequentialVisualizerBloc() {
    on<TaskEvent>(
      _handleTask,
      transformer: sequential(),
    );
  }

  Future<void> _handleTask(
      TaskEvent event, void Function(VisualizerState) emit) async {
    emit(stateValue.copyWith(
      activeTasks: [...stateValue.activeTasks, event.id],
    ));
    await Future.delayed(Duration(milliseconds: event.durationMs));
    final updatedActive =
        stateValue.activeTasks.where((id) => id != event.id).toList();
    emit(stateValue.copyWith(
      activeTasks: updatedActive,
      completedTaskIds: [...stateValue.completedTaskIds, event.id],
    ));
  }
}

/// 2. Droppable Visualizer Bloc
class DroppableVisualizerBloc extends BaseVisualizerBloc {
  DroppableVisualizerBloc() {
    on<TaskEvent>(
      _handleTask,
      transformer: droppable(),
    );
  }

  Future<void> _handleTask(
      TaskEvent event, void Function(VisualizerState) emit) async {
    emit(stateValue.copyWith(
      activeTasks: [...stateValue.activeTasks, event.id],
    ));
    await Future.delayed(Duration(milliseconds: event.durationMs));
    final updatedActive =
        stateValue.activeTasks.where((id) => id != event.id).toList();
    emit(stateValue.copyWith(
      activeTasks: updatedActive,
      completedTaskIds: [...stateValue.completedTaskIds, event.id],
    ));
  }
}

/// 3. Restartable Visualizer Bloc
class RestartableVisualizerBloc extends BaseVisualizerBloc {
  RestartableVisualizerBloc() {
    on<TaskEvent>(
      _handleTask,
      transformer: restartable(),
    );
  }

  Future<void> _handleTask(
      TaskEvent event, void Function(VisualizerState) emit) async {
    emit(stateValue.copyWith(
      activeTasks: [event.id],
    ));
    await Future.delayed(Duration(milliseconds: event.durationMs));
    emit(stateValue.copyWith(
      activeTasks: [],
      completedTaskIds: [...stateValue.completedTaskIds, event.id],
    ));
  }
}

void main() {
  runApp(const ConcurrencyVisualizerApp());
}

class ConcurrencyVisualizerApp extends StatelessWidget {
  const ConcurrencyVisualizerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BlocSignal Concurrency Visualizer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const ConcurrencyVisualizerHomePage(),
    );
  }
}

class ConcurrencyVisualizerHomePage extends StatefulWidget {
  const ConcurrencyVisualizerHomePage({super.key});

  @override
  State<ConcurrencyVisualizerHomePage> createState() =>
      _ConcurrencyVisualizerHomePageState();
}

class _ConcurrencyVisualizerHomePageState
    extends State<ConcurrencyVisualizerHomePage> {
  int _taskCounter = 1;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Streamless Event Concurrency'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Sequential'),
              Tab(text: 'Droppable'),
              Tab(text: 'Restartable'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            BlocSignalProvider<SequentialVisualizerBloc>(
              create: (_) => SequentialVisualizerBloc(),
              child: VisualizerView<SequentialVisualizerBloc>(
                title: 'Sequential (FIFO Queue)',
                description:
                    'Events execute one after another in order. Subsequent events wait in queue.',
                onDispatchBurst: _dispatchBurst,
              ),
            ),
            BlocSignalProvider<DroppableVisualizerBloc>(
              create: (_) => DroppableVisualizerBloc(),
              child: VisualizerView<DroppableVisualizerBloc>(
                title: 'Droppable (Ignore New)',
                description:
                    'Incoming events dispatched while a handler is running are dropped.',
                onDispatchBurst: _dispatchBurst,
              ),
            ),
            BlocSignalProvider<RestartableVisualizerBloc>(
              create: (_) => RestartableVisualizerBloc(),
              child: VisualizerView<RestartableVisualizerBloc>(
                title: 'Restartable (Cancel Previous)',
                description:
                    'Cancels the active handler immediately and starts the new event.',
                onDispatchBurst: _dispatchBurst,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _dispatchBurst(BaseVisualizerBloc bloc) async {
    final startId = _taskCounter;
    setState(() => _taskCounter += 4);
    for (var i = 0; i < 4; i++) {
      bloc.add(TaskEvent(id: startId + i, durationMs: 800));
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }
}

class VisualizerView<T extends BaseVisualizerBloc> extends StatelessWidget {
  const VisualizerView({
    super.key,
    required this.title,
    required this.description,
    required this.onDispatchBurst,
  });

  final String title;
  final String description;
  final void Function(T bloc) onDispatchBurst;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<T>();
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(description, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          Row(
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.bolt),
                label: const Text('Dispatch 4 Rapid Events'),
                onPressed: () => onDispatchBurst(bloc),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () => bloc.clearLogs(),
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: BlocSignalBuilder<T, VisualizerState>(
              builder: (context, state) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Active Processing: Task ${state.activeTasks}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        if (state.activeTasks.isNotEmpty)
                          const LinearProgressIndicator(),
                        const Divider(height: 24),
                        Text(
                          'Completed Tasks (${state.completedTaskIds.length}): ${state.completedTaskIds}',
                          style: const TextStyle(color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
