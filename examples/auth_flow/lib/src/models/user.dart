import 'package:flutter/foundation.dart';

/// User domain model.
///
/// Note: This state class could also use `package:equatable` (extending `Equatable` with `props`) for concise equality.
@immutable
class User {
  const User({required this.id, required this.email, required this.name});

  final String id;
  final String email;
  final String name;

  Map<String, dynamic> toJson() => {'id': id, 'email': email, 'name': name};

  factory User.fromJson(dynamic json) {
    if (json is Map) {
      return User(
        id: json['id']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
      );
    }
    return const User(id: '', email: '', name: '');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          email == other.email &&
          name == other.name;

  @override
  int get hashCode => Object.hash(id, email, name);
}
