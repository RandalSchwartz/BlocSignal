import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';
import 'package:flutter/foundation.dart';
import '../models/user.dart';

@immutable
sealed class AuthState {
  const AuthState();
}

final class Unauthenticated extends AuthState {
  const Unauthenticated();
}

final class Authenticating extends AuthState {
  const Authenticating();
}

final class Authenticated extends AuthState {
  const Authenticated(this.user);
  final User user;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Authenticated &&
          runtimeType == other.runtimeType &&
          user == other.user;

  @override
  int get hashCode => user.hashCode;
}

class AuthCubit extends HydratedCubitSignal<AuthState> {
  AuthCubit({super.storage}) : super(initialState: const Unauthenticated());

  void login(String email, String password) {
    emit(const Authenticating());
    final user = User(
      id: 'usr_${email.hashCode}',
      email: email,
      name: email.split('@').first,
    );
    emit(Authenticated(user));
  }

  void logout() {
    clear();
  }

  @override
  AuthState? fromJson(dynamic json) {
    if (json is Map && json['authenticated'] == true) {
      return Authenticated(User.fromJson(json['user']));
    }
    return const Unauthenticated();
  }

  @override
  dynamic toJson(AuthState state) {
    if (state case Authenticated(:final user)) {
      return {
        'authenticated': true,
        'user': user.toJson(),
      };
    }
    return {'authenticated': false};
  }
}
