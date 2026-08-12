import 'package:flutter/foundation.dart';

/// Immutable model representing a Marvel character.
@immutable
final class MarvelCharacter {
  /// Creates a [MarvelCharacter].
  const MarvelCharacter({
    required this.id,
    required this.name,
    required this.description,
    required this.thumbnailUrl,
  });

  /// Unique character ID.
  final String id;

  /// Character name.
  final String name;

  /// Character bio or description.
  final String description;

  /// Character avatar / thumbnail image URL.
  final String thumbnailUrl;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MarvelCharacter &&
        other.id == id &&
        other.name == name &&
        other.description == description &&
        other.thumbnailUrl == thumbnailUrl;
  }

  @override
  int get hashCode => Object.hash(id, name, description, thumbnailUrl);

  @override
  String toString() => 'MarvelCharacter(id: $id, name: $name)';
}
