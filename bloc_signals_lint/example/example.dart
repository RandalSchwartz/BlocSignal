import 'dart:async';

import 'package:bloc_signals/bloc_signals.dart';

/// Sealed event hierarchy for sample counter BLoC.
abstract class CounterEvent {}

/// Increment event.
class IncrementEvent extends CounterEvent {}

/// Sample BLoC demonstrating correct `onEvent` override and event handlers.
class SampleCounterBloc extends BlocSignal<CounterEvent, int> {
  /// Creates a [SampleCounterBloc] with initial state 0.
  SampleCounterBloc() : super(initialState: 0) {
    // Single event handler registration (prevents
    // avoid_duplicate_event_handlers)
    on<IncrementEvent>((event, emit) {
      emit(stateValue + 1);
    });
  }

  @override
  void onEvent(CounterEvent event) {
    // Must invoke super.onEvent(event) (enforced by require_super_on_event)
    unawaited(Future.value(super.onEvent(event)));
  }
}

void main() async {
  final bloc = SampleCounterBloc()..add(IncrementEvent());

  // Print output for example demonstration.
  // ignore: avoid_print
  print('Current count: ${bloc.stateValue}');

  await bloc.close();
}
