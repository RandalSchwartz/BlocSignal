import 'package:meta/meta.dart';

/// A [Transition] represents the change from one state to another triggered by
/// an event.
///
/// It consists of the [currentState], the [event] that triggered the
/// transition, and the [nextState].
///
/// Example:
/// ```dart
/// final transition = Transition(
///   currentState: 0,
///   event: Increment(),
///   nextState: 1,
/// );
/// print(transition.currentState); // 0
/// print(transition.event); // Increment()
/// print(transition.nextState); // 1
/// ```
@immutable
class Transition<Event, State> {
  /// Creates a [Transition] that captures [currentState], [event], and
  /// [nextState].
  const Transition({
    required this.currentState,
    required this.event,
    required this.nextState,
  });

  /// The state before the transition occurred.
  final State currentState;

  /// The event that triggered the transition.
  final Event event;

  /// The state after the transition occurred.
  final State nextState;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Transition<Event, State> &&
          runtimeType == other.runtimeType &&
          currentState == other.currentState &&
          event == other.event &&
          nextState == other.nextState;

  @override
  int get hashCode =>
      currentState.hashCode ^ event.hashCode ^ nextState.hashCode;

  @override
  String toString() {
    return 'Transition { currentState: $currentState, '
        'event: $event, nextState: $nextState }';
  }
}
