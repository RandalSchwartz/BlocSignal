/// # Counter Example — CubitSignal vs BlocSignal
///
/// This example demonstrates the two primary state container primitives of `BlocSignal`:
/// 1. `CubitSignal<int>` — Direct method invocation (`increment()`, `decrement()`).
/// 2. `BlocSignal<CounterEvent, int>` — Event-driven state machine (`add(CounterIncremented())`).
///
/// Both containers emit state updates synchronously on the same frame, automatically de-duplicate
/// identical states, and integrate seamlessly with `BlocSignalBuilder` and `context.read<T>()`.
library;

import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';

// =============================================================================
// 1. CubitSignal Implementation
// =============================================================================

/// A simple [CubitSignal] managing an integer counter state.
///
/// Use `CubitSignal` when state transitions are triggered via direct method calls.
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  /// Increments the counter state synchronously.
  void increment() => emit(stateValue + 1);

  /// Decrements the counter state synchronously.
  void decrement() => emit(stateValue - 1);
}

// =============================================================================
// 2. BlocSignal Implementation
// =============================================================================

/// Sealed hierarchy representing events dispatched to [CounterBloc].
sealed class CounterEvent {
  const CounterEvent();
}

/// Dispatched to increment the counter.
final class CounterIncremented extends CounterEvent {
  const CounterIncremented();
}

/// Dispatched to decrement the counter.
final class CounterDecremented extends CounterEvent {
  const CounterDecremented();
}

/// An event-driven [BlocSignal] managing an integer counter state.
///
/// Use `BlocSignal` when state transitions require explicit event tracing, observer logging,
/// or event concurrency transformers (for example `sequential()`, `droppable()`).
class CounterBloc extends BlocSignal<CounterEvent, int> {
  CounterBloc() : super(initialState: 0) {
    on<CounterIncremented>((event, emit) => emit(stateValue + 1));
    on<CounterDecremented>((event, emit) => emit(stateValue - 1));
  }
}

// =============================================================================
// 3. Application Entrypoint & UI Layout
// =============================================================================

void main() {
  runApp(const CounterApp());
}

/// Root application widget providing both [CounterCubit] and [CounterBloc] to the subtree.
class CounterApp extends StatelessWidget {
  const CounterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSignalProvider<CounterCubit>(
      create: (context) => CounterCubit(),
      child: BlocSignalProvider<CounterBloc>(
        create: (context) => CounterBloc(),
        child: MaterialApp(
          title: 'BlocSignal Counter',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            useMaterial3: true,
          ),
          home: const CounterHomePage(),
        ),
      ),
    );
  }
}

/// Displays side-by-side counter UI widgets for Cubit and Bloc.
class CounterHomePage extends StatelessWidget {
  const CounterHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Counter: Cubit vs Bloc'),
      ),
      body: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Cubit Section
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'CubitSignal',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                BlocSignalBuilder<CounterCubit, int>(
                  builder: (context, count) {
                    return Text(
                      '$count',
                      style: Theme.of(context).textTheme.displayMedium,
                    );
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    IconButton.filled(
                      icon: const Icon(Icons.remove),
                      onPressed: () => context.read<CounterCubit>().decrement(),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      icon: const Icon(Icons.add),
                      onPressed: () => context.read<CounterCubit>().increment(),
                    ),
                  ],
                ),
              ],
            ),

            const VerticalDivider(indent: 100, endIndent: 100),

            // Bloc Section
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'BlocSignal',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                BlocSignalBuilder<CounterBloc, int>(
                  builder: (context, count) {
                    return Text(
                      '$count',
                      style: Theme.of(context).textTheme.displayMedium,
                    );
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    IconButton.filledTonal(
                      icon: const Icon(Icons.remove),
                      onPressed: () => context
                          .read<CounterBloc>()
                          .add(const CounterDecremented()),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.add),
                      onPressed: () => context
                          .read<CounterBloc>()
                          .add(const CounterIncremented()),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
