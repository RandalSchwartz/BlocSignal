import 'package:flutter/foundation.dart';

/// Immutable model representing a Todo item.
@immutable
final class Todo {
  /// Creates a [Todo] instance.
  const Todo({
    required this.id,
    required this.description,
    this.completed = false,
  });

  /// Unique identifier for this todo.
  final String id;

  /// Text description of the task.
  final String description;

  /// Whether the task is completed.
  final bool completed;

  /// Returns a copy of this [Todo] with updated properties.
  Todo copyWith({
    String? id,
    String? description,
    bool? completed,
  }) {
    return Todo(
      id: id ?? this.id,
      description: description ?? this.description,
      completed: completed ?? this.completed,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Todo &&
        other.id == id &&
        other.description == description &&
        other.completed == completed;
  }

  @override
  int get hashCode => Object.hash(id, description, completed);

  @override
  String toString() =>
      'Todo(id: $id, description: $description, completed: $completed)';
}

/// Filter options for todo list display.
enum TodoFilter {
  /// Show all todos.
  all,

  /// Show active (uncompleted) todos only.
  active,

  /// Show completed todos only.
  completed,
}
