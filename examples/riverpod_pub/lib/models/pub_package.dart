import 'package:flutter/foundation.dart';

/// Model representing a package returned by pub.dev search.
@immutable
final class PubPackage {
  /// Creates a [PubPackage].
  const PubPackage({
    required this.name,
    required this.version,
    required this.description,
  });

  /// Name of the package.
  final String name;

  /// Latest published version string.
  final String version;

  /// Short description of the package.
  final String description;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PubPackage &&
        other.name == name &&
        other.version == version &&
        other.description == description;
  }

  @override
  int get hashCode => Object.hash(name, version, description);

  @override
  String toString() =>
      'PubPackage(name: $name, version: $version, description: $description)';
}
