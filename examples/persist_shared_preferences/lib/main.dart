/// # SharedPreferences State Persistence Example — HydratedCubitSignal
///
/// This example demonstrates how [HydratedCubitSignal] persists application theme settings
/// and user preferences across app restarts synchronously without UI flickers.
///
/// Unlike classic `hydrated_bloc` which requires complex `Map<String, dynamic>` structures,
/// `HydratedCubitSignal` supports primitive types (`bool`, `int`, `String`) with **zero method overrides**!
library;

import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';
import 'package:flutter/material.dart';

// =============================================================================
// 1. ThemeCubit Implementation
// =============================================================================

/// Persists dark mode theme preference (`bool`).
///
/// Primitive state types require **zero method overrides** for `fromJson` and `toJson`!
class ThemeCubit extends HydratedCubitSignal<bool> {
  ThemeCubit({super.storage}) : super(initialState: false);

  /// Toggles theme mode synchronously.
  void toggleTheme() => emit(!stateValue);
}

// =============================================================================
// 2. Application Entrypoint & UI Layout
// =============================================================================

void main() {
  runApp(const PersistApp());
}

/// Root application widget.
class PersistApp extends StatelessWidget {
  const PersistApp({super.key, this.storage});

  final HydratedStorage? storage;

  @override
  Widget build(BuildContext context) {
    return BlocSignalProvider<ThemeCubit>(
      lazy: false,
      create: (context) => ThemeCubit(storage: storage),
      child: BlocSignalBuilder<ThemeCubit, bool>(
        builder: (context, isDarkMode) {
          return MaterialApp(
            title: 'BlocSignal State Persistence',
            themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
            ),
            home: const SettingsPage(),
          );
        },
      ),
    );
  }
}

/// Main settings page with persistent theme toggle.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Persistent App Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            BlocSignalBuilder<ThemeCubit, bool>(
              builder: (context, isDarkMode) {
                return SwitchListTile(
                  secondary: Icon(
                    isDarkMode ? Icons.dark_mode : Icons.light_mode,
                  ),
                  title: const Text('Dark Mode'),
                  subtitle: Text(
                    isDarkMode
                        ? 'Dark theme is active and persisted'
                        : 'Light theme is active and persisted',
                  ),
                  value: isDarkMode,
                  onChanged: (_) {
                    context.read<ThemeCubit>().toggleTheme();
                  },
                );
              },
            ),
            const Spacer(),
            ElevatedButton.icon(
              icon: const Icon(Icons.delete_outline),
              label: const Text('Clear Persisted State'),
              onPressed: () {
                context.read<ThemeCubit>().clear();
              },
            ),
          ],
        ),
      ),
    );
  }
}
