import 'package:flutter/material.dart';
import 'mine_counter_widget.dart';
import 'reset_button_widget.dart';
import 'timer_widget.dart';

/// Top bar container holding the mine counter, smiley reset button, and timer display.
class HeaderWidget extends StatelessWidget {
  const HeaderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade300,
      padding: const EdgeInsets.all(10.0),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [MineCounterWidget(), ResetButtonWidget(), TimerWidget()],
      ),
    );
  }
}
