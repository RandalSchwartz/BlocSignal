/// # Async State Example — AsyncState with CubitSignal
///
/// This example demonstrates how [CubitSignal] handles asynchronous network requests using
/// [AsyncState] (`AsyncData`, `AsyncLoading`, `AsyncError`).
///
/// In classic Flutter BLoC, async data streams require complex status enums and nullable fields.
/// With `BlocSignal`, [AsyncState] encapsulates loading, data, and error boundaries cleanly
/// while guaranteeing frame-1 synchronous reactivity.
library;

import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import 'package:signals_core/signals_core.dart';

// =============================================================================
// 1. Data Model
// =============================================================================

/// User domain model.
class UserProfile {
  const UserProfile({required this.id, required this.name, required this.role});

  final String id;
  final String name;
  final String role;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          role == other.role;

  @override
  int get hashCode => Object.hash(id, name, role);
}

// =============================================================================
// 2. UserCubit Implementation
// =============================================================================

/// Manages asynchronous user profile fetching state using [AsyncState].
class UserCubit extends CubitSignal<AsyncState<UserProfile>> {
  UserCubit() : super(initialState: const AsyncLoading());

  /// Simulates fetching a user profile from a remote REST API.
  Future<void> fetchUser({bool shouldFail = false}) async {
    emit(const AsyncLoading());
    await Future<void>.delayed(const Duration(milliseconds: 50));

    if (shouldFail) {
      emit(AsyncError(
          Exception('Failed to connect to user service'), StackTrace.current));
    } else {
      emit(const AsyncData(UserProfile(
        id: 'usr_789',
        name: 'Samantha Reed',
        role: 'Principal Systems Architect',
      )));
    }
  }
}

// =============================================================================
// 3. Application Entrypoint & UI Layout
// =============================================================================

void main() {
  runApp(const AsyncApp());
}

/// Root application widget.
class AsyncApp extends StatelessWidget {
  const AsyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSignalProvider<UserCubit>(
      lazy: false,
      create: (context) => UserCubit()..fetchUser(),
      child: MaterialApp(
        title: 'BlocSignal Async State',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
          useMaterial3: true,
        ),
        home: const UserProfilePage(),
      ),
    );
  }
}

/// Renders user profile UI based on current [AsyncState].
class UserProfilePage extends StatelessWidget {
  const UserProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Async Profile Loader'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: BlocSignalBuilder<UserCubit, AsyncState<UserProfile>>(
            builder: (context, state) {
              return switch (state) {
                AsyncLoading() => const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Fetching user profile...'),
                    ],
                  ),
                AsyncError(:final error) => Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 48),
                      const SizedBox(height: 12),
                      Text('Error: $error',
                          style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => context.read<UserCubit>().fetchUser(),
                        child: const Text('Retry Fetch'),
                      ),
                    ],
                  ),
                AsyncData(:final value) => Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircleAvatar(
                        radius: 36,
                        child: Icon(Icons.person, size: 36),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        value.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value.role,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.grey[700],
                                ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton(
                            onPressed: () =>
                                context.read<UserCubit>().fetchUser(),
                            child: const Text('Refresh'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () => context
                                .read<UserCubit>()
                                .fetchUser(shouldFail: true),
                            child: const Text('Simulate Error'),
                          ),
                        ],
                      ),
                    ],
                  ),
              };
            },
          ),
        ),
      ),
    );
  }
}
