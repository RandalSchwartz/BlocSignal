import 'package:bloc_signals_devtools/bloc_signals_devtools.dart';
// Preserves sdk: ^3.5.0 compatibility on Flutter <3.47.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

void main() {
  runApp(
    MaterialApp(
      home: BlocSignalsDevToolsExtension(
        instances: const [
          {
            'hashCode': 101,
            'type': 'CounterCubit',
            'stateValue': '42',
            'isClosed': false,
          },
        ],
        history: const [
          {
            'type': 'transition',
            'timestamp': '2026-07-23T12:00:00.000',
            'data': {'event': 'increment', 'nextState': '42'},
          },
        ],
      ),
    ),
  );
}
