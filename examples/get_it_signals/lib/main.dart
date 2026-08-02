/// # GetIt Dependency Injection Example — GetIt with BlocSignal
///
/// This example demonstrates how [BlocSignal] integrates with [GetIt] service locator DI:
/// 1. Register state containers (`CounterCubit`, `NewsBloc`) as singletons or factories in `GetIt`.
/// 2. Provide them to the Flutter widget tree using `BlocSignalProvider.value(value: GetIt.I<T>())`.
///
/// Using `BlocSignalProvider.value` ensures that `BlocSignalProvider` does **not** call `.close()`
/// when widgets unmount, allowing `GetIt` to maintain container ownership across route pushes and pops.
library;

import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

// =============================================================================
// 1. Service Locator Setup
// =============================================================================

/// Global [GetIt] instance locator.
final GetIt getIt = GetIt.instance;

/// Registers application services and state containers with [GetIt].
void setupServiceLocator() {
  if (!getIt.isRegistered<ServiceCubit>()) {
    getIt.registerSingleton<ServiceCubit>(ServiceCubit());
  }
}

// =============================================================================
// 2. ServiceCubit Implementation
// =============================================================================

/// A [CubitSignal] managed by [GetIt].
class ServiceCubit extends CubitSignal<int> {
  ServiceCubit() : super(initialState: 100);

  void increment() => emit(stateValue + 1);
  void decrement() => emit(stateValue - 1);
}

// =============================================================================
// 3. Application Entrypoint & UI Layout
// =============================================================================

void main() {
  setupServiceLocator();
  runApp(const GetItApp());
}

/// Root application widget bridging [GetIt] singletons to the widget tree.
class GetItApp extends StatelessWidget {
  const GetItApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSignalProvider<ServiceCubit>.value(
      value: getIt<ServiceCubit>(),
      child: MaterialApp(
        title: 'BlocSignal GetIt DI',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
          useMaterial3: true,
        ),
        home: const GetItHomePage(),
      ),
    );
  }
}

/// Main page displaying state retrieved via GetIt DI.
class GetItHomePage extends StatelessWidget {
  const GetItHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GetIt Service Locator DI'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'State Managed by GetIt Singleton',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            BlocSignalBuilder<ServiceCubit, int>(
              builder: (context, count) {
                return Text(
                  '$count',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                );
              },
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.remove),
                  label: const Text('Decrement'),
                  onPressed: () => context.read<ServiceCubit>().decrement(),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Increment'),
                  onPressed: () => context.read<ServiceCubit>().increment(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
