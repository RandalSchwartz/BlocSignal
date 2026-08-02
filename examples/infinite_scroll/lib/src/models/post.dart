import 'package:flutter/foundation.dart';

/// Post model.
///
/// Note: This state class could also use `package:equatable` (extending `Equatable` with `props`) for concise equality.
@immutable
class Post {
  const Post({required this.id, required this.title, required this.body});

  final int id;
  final String title;
  final String body;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Post &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          body == other.body;

  @override
  int get hashCode => Object.hash(id, title, body);
}
