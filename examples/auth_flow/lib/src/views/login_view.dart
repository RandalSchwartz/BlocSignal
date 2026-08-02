import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import '../auth/auth_cubit.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _emailController = TextEditingController(text: 'alex@blocsignal.dev');
  final _passwordController = TextEditingController(text: 'password123');

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 24),
            BlocSignalBuilder<AuthCubit, AuthState>(
              builder: (context, state) {
                if (state is Authenticating) {
                  return const CircularProgressIndicator();
                }
                return ElevatedButton(
                  onPressed: () {
                    context.read<AuthCubit>().login(
                          _emailController.text,
                          _passwordController.text,
                        );
                  },
                  child: const Text('Sign In'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
