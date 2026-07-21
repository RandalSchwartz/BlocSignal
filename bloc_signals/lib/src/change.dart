import 'package:meta/meta.dart';

/// A [Change] represents the change from one state to another.
///
/// It consists of the [currentState] and the [nextState].
///
/// Example:
/// ```dart
/// final change = Change(currentState: 0, nextState: 1);
/// print(change.currentState); // 0
/// print(change.nextState); // 1
/// ```
@immutable
class Change<State> {
  /// Creates a [Change] that captures [currentState] and [nextState].
  const Change({required this.currentState, required this.nextState});

  /// The state before the change occurred.
  final State currentState;

  /// The state after the change occurred.
  final State nextState;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Change<State> &&
          runtimeType == other.runtimeType &&
          currentState == other.currentState &&
          nextState == other.nextState;

  @override
  int get hashCode => currentState.hashCode ^ nextState.hashCode;

  @override
  String toString() {
    return 'Change { currentState: $currentState, nextState: $nextState }';
  }
}
