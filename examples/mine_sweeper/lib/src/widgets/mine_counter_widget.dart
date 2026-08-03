import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import '../state/game_state.dart';

/// Digital LED-style display widget for remaining unflagged mines.
///
/// Uses `context.select<GameBlocSignal, int>` to compute remaining mines
/// (`mineCount - flagCount`) and rebuilds ONLY when flag placement changes.
class MineCounterWidget extends StatelessWidget {
  const MineCounterWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final remainingMines = context.select<GameBlocSignal, int>(
      (bloc) => bloc.stateValue.mineCount - bloc.stateValue.flagCount,
    );

    return Container(
      padding: const EdgeInsets.all(8.0),
      color: Colors.black,
      child: Text(
        remainingMines.toString().padLeft(3, '0'),
        style: const TextStyle(
          color: Colors.red,
          fontSize: 24,
          fontFamily: 'monospace',
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
