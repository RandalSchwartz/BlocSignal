import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import '../state/game_state.dart';

/// Digital LED-style display widget for elapsed game time in seconds.
///
/// Uses `context.select<GameBlocSignal, int>` to extract `timer` and rebuilds
/// strictly once per second when the timer increments.
class TimerWidget extends StatelessWidget {
  const TimerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final timer = context.select<GameBlocSignal, int>(
      (bloc) => bloc.stateValue.timer,
    );

    return Container(
      padding: const EdgeInsets.all(8.0),
      color: Colors.black,
      child: Text(
        timer.toString().padLeft(3, '0'),
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
