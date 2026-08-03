import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import '../state/game_state.dart';

/// Central reset button with smiley face icon reflecting game status.
///
/// Uses `context.select<GameBlocSignal, GameStatus>` to update the smiley icon
/// (playing: 🙂, won: 😎, lost: 😵) without rebuilding on timer ticks.
class ResetButtonWidget extends StatelessWidget {
  const ResetButtonWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final status = context.select<GameBlocSignal, GameStatus>(
      (bloc) => bloc.stateValue.status,
    );
    final bloc = context.read<GameBlocSignal>();

    return GestureDetector(
      onTap: () => bloc.add(const ResetGameEvent()),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey.shade400,
          border: Border.all(color: Colors.grey.shade700),
        ),
        child: Icon(_getIconForStatus(status), size: 30),
      ),
    );
  }

  IconData _getIconForStatus(GameStatus status) {
    switch (status) {
      case GameStatus.playing:
        return Icons.sentiment_satisfied;
      case GameStatus.won:
        return Icons.sentiment_very_satisfied;
      case GameStatus.lost:
        return Icons.sentiment_very_dissatisfied;
    }
  }
}
