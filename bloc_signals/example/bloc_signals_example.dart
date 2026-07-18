// Prints are used in this example file to demonstrate simple console outputs.
// ignore_for_file: avoid_print

import 'package:bloc_signals/bloc_signals.dart';

/// 1. Define the Events
/// Events represent incoming actions dispatched to the BLoC.
sealed class CounterEvent {}

class Increment extends CounterEvent {}

/// 2. Implement the BlocSignal
/// The BLoC holds states of type [int] and receives events of type [CounterEvent].
/// State updates are synchronous and reactive.
class CounterBloc extends BlocSignal<CounterEvent, int> {
  CounterBloc() : super(initialState: 0);

  @override
  void onEvent(CounterEvent event) {
    // Map incoming events to state modifications
    switch (event) {
      case Increment():
        // emit() updates the state value synchronously
        emit(stateValue + 1);
    }
  }
}

/// 3. Implement a Global Observer
/// The observer intercepts events, transitions, and errors for all active
/// BlocSignals, perfect for analytics, debugging, and tracing.
class SimpleLogger extends BlocSignalObserver {
  @override
  void onEvent(BlocSignal<dynamic, dynamic> bloc, Object? event) {
    print('Logger -> Event received: $event on ${bloc.runtimeType}');
  }

  @override
  void onTransition(
    BlocSignal<dynamic, dynamic> bloc,
    Object? event,
    Object? state,
  ) {
    print('Logger -> State changed to: $state on ${bloc.runtimeType}');
  }
}

void main() {
  // Register the global observer
  BlocSignalObserver.observer = SimpleLogger();

  // Instantiate the BLoC (initial state is 0)
  final bloc = CounterBloc();

  print('Initial State Value: ${bloc.stateValue}'); // Prints: 0

  // Adding an event synchronously maps and processes it.
  // This notifies the observer and updates state in the current execution block.
  bloc.add(Increment()); 

  print('Synchronous Updated State Value: ${bloc.stateValue}'); // Prints: 1

  // Clean up resources, cancel the internally managed SignalModel lifecycle and any downstream effects
  bloc.close();
}
