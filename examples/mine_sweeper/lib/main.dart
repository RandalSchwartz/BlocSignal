import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';
import 'package:bloc_signals_hydrate/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/screens/settings_screen.dart';
import 'src/state/game_state.dart';
import 'src/widgets/board_widget.dart';
import 'src/widgets/header_widget.dart';

/// Entry point for the Minesweeper application.
///
/// Initializes [HydratedStorage] with [SharedPreferences] and binds
/// [GameBlocSignal] to the widget tree using [BlocSignalProvider].
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  HydratedStorage.storage = SharedPreferencesHydratedStorage(prefs);

  runApp(
    BlocSignalProvider<GameBlocSignal>(
      create: (context) => GameBlocSignal(),
      child: const MyApp(),
    ),
  );
}

/// Root widget of the Minesweeper application.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Minesweeper',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: const GameScreen(),
    );
  }
}

/// Primary game screen displaying the header bar, reset button, timer, and grid board.
///
/// Fully stateless because timer ticking and state persistence are managed
/// directly inside [GameBlocSignal].
class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minesweeper'),
        backgroundColor: Colors.grey.shade300,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: const SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [HeaderWidget(), SizedBox(height: 20), BoardWidget()],
          ),
        ),
      ),
    );
  }
}
