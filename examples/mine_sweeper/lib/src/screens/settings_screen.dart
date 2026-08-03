import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import '../models/difficulty.dart';
import '../state/game_state.dart';

/// Settings screen for selecting game board difficulty.
///
/// Uses `context.select<GameBlocSignal, GameDifficulty>` to subscribe strictly
/// to difficulty changes without rebuilding when the board grid or timer ticks.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentDifficulty = context.select<GameBlocSignal, GameDifficulty>(
      (bloc) => bloc.stateValue.difficulty,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Select Difficulty')),
      body: Center(
        child: RadioGroup<GameDifficulty>(
          groupValue: currentDifficulty,
          onChanged: (GameDifficulty? value) {
            if (value != null) {
              context.read<GameBlocSignal>().add(ResetGameEvent(value));
              Navigator.of(context).pop();
            }
          },
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RadioListTile<GameDifficulty>(
                title: Text('Beginner'),
                value: GameDifficulty.beginner,
              ),
              RadioListTile<GameDifficulty>(
                title: Text('Intermediate'),
                value: GameDifficulty.intermediate,
              ),
              RadioListTile<GameDifficulty>(
                title: Text('Expert'),
                value: GameDifficulty.expert,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
