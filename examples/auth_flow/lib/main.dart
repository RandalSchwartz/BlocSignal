import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import 'src/auth/auth_cubit.dart';
import 'src/views/home_view.dart';
import 'src/views/login_view.dart';

void main() {
  runApp(const AuthFlowApp());
}

class AuthFlowApp extends StatelessWidget {
  const AuthFlowApp({super.key, this.authCubit});

  final AuthCubit? authCubit;

  @override
  Widget build(BuildContext context) {
    return BlocSignalProvider<AuthCubit>(
      lazy: false,
      create: (context) => authCubit ?? AuthCubit(),
      child: MaterialApp(
        title: 'BlocSignal Auth Flow',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          useMaterial3: true,
        ),
        home: BlocSignalBuilder<AuthCubit, AuthState>(
          builder: (context, state) {
            if (state case Authenticated(:final user)) {
              return HomeView(user: user);
            }
            return const LoginView();
          },
        ),
      ),
    );
  }
}
