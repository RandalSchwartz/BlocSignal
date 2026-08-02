/// # Eval Calculator Example — Event-Driven State Machine with BlocSignal
///
/// This example demonstrates an interactive calculator state machine using [BlocSignal].
///
/// Calculator logic is notoriously prone to edge cases (trailing operators, division by zero,
/// multi-digit decimal assembly). Using `BlocSignal` and sealed event classes ensures that
/// state transitions remain 100% deterministic, observer-traceable, and testable.
library;

import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';

// =============================================================================
// 1. Calculator Events
// =============================================================================

/// Sealed hierarchy of user interaction events for [CalculatorBloc].
sealed class CalculatorEvent {
  const CalculatorEvent();
}

final class DigitPressed extends CalculatorEvent {
  const DigitPressed(this.digit);
  final String digit;
}

final class OperatorPressed extends CalculatorEvent {
  const OperatorPressed(this.op);
  final String op;
}

final class EqualsPressed extends CalculatorEvent {
  const EqualsPressed();
}

final class ClearPressed extends CalculatorEvent {
  const ClearPressed();
}

// =============================================================================
// 2. Calculator State Model
// =============================================================================

/// Immutable state model representing current calculator display and operation buffer.
@immutable
class CalculatorState {
  const CalculatorState({
    this.display = '0',
    this.firstOperand,
    this.operator,
    this.isNewOperand = true,
  });

  final String display;
  final double? firstOperand;
  final String? operator;
  final bool isNewOperand;

  CalculatorState copyWith({
    String? display,
    double? firstOperand,
    String? operator,
    bool? isNewOperand,
  }) {
    return CalculatorState(
      display: display ?? this.display,
      firstOperand: firstOperand ?? this.firstOperand,
      operator: operator ?? this.operator,
      isNewOperand: isNewOperand ?? this.isNewOperand,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalculatorState &&
          runtimeType == other.runtimeType &&
          display == other.display &&
          firstOperand == other.firstOperand &&
          operator == other.operator &&
          isNewOperand == other.isNewOperand;

  @override
  int get hashCode =>
      Object.hash(display, firstOperand, operator, isNewOperand);
}

// =============================================================================
// 3. CalculatorBloc Implementation
// =============================================================================

/// Manages interactive calculator arithmetic operations.
class CalculatorBloc extends BlocSignal<CalculatorEvent, CalculatorState> {
  CalculatorBloc() : super(initialState: const CalculatorState()) {
    on<DigitPressed>((event, emit) {
      final currentDisplay = stateValue.display;
      final isNew = stateValue.isNewOperand;

      if (isNew || currentDisplay == '0') {
        emit(stateValue.copyWith(
          display: event.digit,
          isNewOperand: false,
        ));
      } else {
        emit(stateValue.copyWith(
          display: currentDisplay + event.digit,
          isNewOperand: false,
        ));
      }
    });

    on<OperatorPressed>((event, emit) {
      final currentValue = double.tryParse(stateValue.display) ?? 0.0;
      emit(stateValue.copyWith(
        firstOperand: currentValue,
        operator: event.op,
        isNewOperand: true,
      ));
    });

    on<EqualsPressed>((event, emit) {
      final first = stateValue.firstOperand;
      final op = stateValue.operator;
      final second = double.tryParse(stateValue.display) ?? 0.0;

      if (first == null || op == null) return;

      double result = 0.0;
      switch (op) {
        case '+':
          result = first + second;
        case '-':
          result = first - second;
        case '×':
          result = first * second;
        case '÷':
          result = second != 0 ? first / second : double.nan;
      }

      final displayStr = result.isNaN
          ? 'Error'
          : result == result.roundToDouble()
              ? result.toInt().toString()
              : result.toString();

      emit(CalculatorState(
        display: displayStr,
        firstOperand: null,
        operator: null,
        isNewOperand: true,
      ));
    });

    on<ClearPressed>((event, emit) {
      emit(const CalculatorState());
    });
  }
}

// =============================================================================
// 4. Application Entrypoint & UI Layout
// =============================================================================

void main() {
  runApp(const CalculatorApp());
}

/// Root application widget.
class CalculatorApp extends StatelessWidget {
  const CalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSignalProvider<CalculatorBloc>(
      lazy: false,
      create: (context) => CalculatorBloc(),
      child: MaterialApp(
        title: 'BlocSignal Calculator',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
          useMaterial3: true,
        ),
        home: const CalculatorHomePage(),
      ),
    );
  }
}

/// Main calculator UI page.
class CalculatorHomePage extends StatelessWidget {
  const CalculatorHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('State Machine Calculator')),
      body: Column(
        children: [
          // Display Screen
          Expanded(
            child: Container(
              alignment: Alignment.bottomRight,
              padding: const EdgeInsets.all(32.0),
              child:
                  BlocSignalSelector<CalculatorBloc, CalculatorState, String>(
                selector: (state) => state.display,
                builder: (context, display) {
                  return Text(
                    display,
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  );
                },
              ),
            ),
          ),

          // Keypad Buttons
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildRow(context, ['7', '8', '9', '÷']),
                _buildRow(context, ['4', '5', '6', '×']),
                _buildRow(context, ['1', '2', '3', '-']),
                _buildRow(context, ['C', '0', '=', '+']),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, List<String> labels) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: labels.map((label) {
        final isOperator = ['+', '-', '×', '÷', '='].contains(label);
        final isClear = label == 'C';
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.all(6.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                backgroundColor: isOperator
                    ? Colors.deepOrange
                    : isClear
                        ? Colors.red[400]
                        : null,
                foregroundColor: (isOperator || isClear) ? Colors.white : null,
              ),
              onPressed: () {
                final bloc = context.read<CalculatorBloc>();
                if (label == 'C') {
                  bloc.add(const ClearPressed());
                } else if (label == '=') {
                  bloc.add(const EqualsPressed());
                } else if (isOperator) {
                  bloc.add(OperatorPressed(label));
                } else {
                  bloc.add(DigitPressed(label));
                }
              },
              child: Text(
                label,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
