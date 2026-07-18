import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import 'package:kaisel/kaisel.dart';

// ==========================================
// 1. Routes Definition
// ==========================================
/// Sealed class hierarchy representing the application's routes.
/// Using a sealed class guarantees compile-time exhaustiveness checks in routers.
sealed class AppRoute extends KaiselRoute {
  const AppRoute();
}

/// The login screen route.
final class LoginRoute extends AppRoute {
  const LoginRoute();
}

/// The home dashboard route which takes a dynamic [username] parameter.
final class HomeRoute extends AppRoute {
  final String username;
  const HomeRoute(this.username);

  @override
  List<Object?> get props => [username];
}

// ==========================================
// 2. BLoC State & Events
// ==========================================
/// Sealed class representing events dispatched to the [LoginBloc].
sealed class LoginEvent {}

/// Triggered when the user types in the username text field.
class UsernameChanged extends LoginEvent {
  final String username;
  UsernameChanged(this.username);
}

/// Triggered when the user types in the password text field.
class PasswordChanged extends LoginEvent {
  final String password;
  PasswordChanged(this.password);
}

/// Triggered when the user clicks the "Sign In" button.
class SubmitLogin extends LoginEvent {}

/// Triggered when the user logs out from the dashboard.
class Logout extends LoginEvent {}

/// Immutable state containing the login UI credentials, loading status,
/// error message, and authentication state.
class LoginState {
  final String username;
  final String password;
  final bool isLoading;
  final String? error;
  final bool isLoggedIn;

  const LoginState({
    this.username = '',
    this.password = '',
    this.isLoading = false,
    this.error,
    this.isLoggedIn = false,
  });

  /// Returns a copy of the state with modified properties.
  LoginState copyWith({
    String? username,
    String? password,
    bool? isLoading,
    String? error,
    bool? isLoggedIn,
  }) {
    return LoginState(
      username: username ?? this.username,
      password: password ?? this.password,
      isLoading: isLoading ?? this.isLoading,
      error: error, // If passed null, it clears the error.
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
    );
  }
}

/// [LoginBloc] coordinates the user authentication flow.
/// It receives [LoginEvent] inputs and processes updates synchronously.
class LoginBloc extends BlocSignal<LoginEvent, LoginState> {
  LoginBloc() : super(initialState: const LoginState());

  @override
  void onEvent(LoginEvent event) async {
    if (event is UsernameChanged) {
      emit(stateValue.copyWith(username: event.username));
    } else if (event is PasswordChanged) {
      emit(stateValue.copyWith(password: event.password));
    } else if (event is SubmitLogin) {
      // Validate inputs
      if (stateValue.username.trim().isEmpty) {
        emit(stateValue.copyWith(error: 'Username cannot be empty'));
        return;
      }
      if (stateValue.password.length < 4) {
        emit(
          stateValue.copyWith(error: 'Password must be at least 4 characters'),
        );
        return;
      }

      // Enter loading state
      emit(stateValue.copyWith(isLoading: true, error: null));

      // Simulate a network latency/async process
      await Future.delayed(const Duration(milliseconds: 800));

      if (stateValue.password == 'password') {
        // Authenticated successfully
        emit(stateValue.copyWith(isLoading: false, isLoggedIn: true));
      } else {
        // Authentication failed
        emit(
          stateValue.copyWith(
            isLoading: false,
            error: 'Incorrect password! (Hint: use "password")',
          ),
        );
      }
    } else if (event is Logout) {
      // Reset state on logout
      emit(const LoginState());
    }
  }
}

// ==========================================
// 3. Main App Entry
// ==========================================
void main() {
  /// Initialize type-safe Kaisel router matching routes to screen widgets.
  final config = KaiselRouterConfig<AppRoute>(
    initial: const LoginRoute(),
    builder: (context, route) => switch (route) {
      LoginRoute() => const LoginScreen(),
      HomeRoute(:final username) => HomeScreen(username: username),
    },
  );

  runApp(
    /// Inject [LoginBloc] globally using [BlocSignalProvider].
    /// It automatically manages the BLoC's lifecycle and disposes it on removal.
    BlocSignalProvider<LoginBloc>(
      create: (_) => LoginBloc(),
      child: MyApp(routerConfig: config),
    ),
  );
}

class MyApp extends StatelessWidget {
  final KaiselRouterConfig<AppRoute> routerConfig;

  const MyApp({super.key, required this.routerConfig});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'BlocSignal Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      routerConfig: routerConfig,
    );
  }
}

// ==========================================
// 4. UI Screens
// ==========================================
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    /// Retrieve [LoginBloc] instance using the context reader extension.
    /// This retrieves the instance without establishing a widget rebuild dependency.
    final bloc = context.read<LoginBloc>();

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: BlocSignalBuilder<LoginBloc, LoginState>(
                    builder: (context, state) {
                      // Navigate to dashboard if logged in
                      if (state.isLoggedIn) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          context.replaceTop(HomeRoute(state.username));
                        });
                      }

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Icon(
                            Icons.lock_outline,
                            size: 64,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Welcome Back',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Sign in to demonstrate BlocSignal + Kaisel',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 32),

                          // Username field
                          TextField(
                            decoration: InputDecoration(
                              labelText: 'Username',
                              prefixIcon: const Icon(Icons.person_outline),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            // Dispatch event on change
                            onChanged: (val) => bloc.add(UsernameChanged(val)),
                          ),
                          const SizedBox(height: 16),

                          // Password field
                          TextField(
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_open_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            // Dispatch event on change
                            onChanged: (val) => bloc.add(PasswordChanged(val)),
                          ),

                          // Render validation errors dynamically
                          if (state.error != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              state.error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          const SizedBox(height: 24),

                          // Submit button
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: state.isLoading
                                ? null
                                : () => bloc.add(SubmitLogin()),
                            child: state.isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Sign In'),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  final String username;

  const HomeScreen({super.key, required this.username});

  @override
  Widget build(BuildContext context) {
    /// Retrieve the BLoC to handle the logout event.
    final bloc = context.read<LoginBloc>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // Dispatch logout event and navigate back
              bloc.add(Logout());
              context.replaceTop(const LoginRoute());
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Hello, $username!',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'You have successfully signed in using a synchronous '
                'BlocSignal pattern and Kaisel router!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
