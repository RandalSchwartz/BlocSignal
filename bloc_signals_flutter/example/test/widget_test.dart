import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('authGuard unit tests', () {
    test('redirects unauthenticated stack to LoginRoute', () {
      final loginBloc = LoginBloc();
      final guard = authGuard(loginBloc);

      // Attempting to go to HomeRoute while unauthenticated
      final proposed = [const HomeRoute('alice')];
      final result = guard(const [LoginRoute()], proposed);

      expect(result, equals([const LoginRoute()]));
    });

    test('allows authenticated user to navigate to HomeRoute', () {
      final loginBloc = LoginBloc();
      loginBloc.emit(
        const LoginState(username: 'alice', isLoggedIn: true),
      );
      final guard = authGuard(loginBloc);

      final proposed = [const HomeRoute('alice')];
      final result = guard(const [LoginRoute()], proposed);

      expect(result, equals(proposed));
    });

    test('redirects authenticated user away from LoginRoute to HomeRoute', () {
      final loginBloc = LoginBloc();
      loginBloc.emit(
        const LoginState(username: 'alice', isLoggedIn: true),
      );
      final guard = authGuard(loginBloc);

      final proposed = [const LoginRoute()];
      final result = guard(const [HomeRoute('alice')], proposed);

      expect(result, equals([const HomeRoute('alice')]));
    });
  });

  group('Kaisel declarative routing widget tests', () {
    testWidgets('App renders login screen initially and gates protected route',
        (
      WidgetTester tester,
    ) async {
      final loginBloc = LoginBloc();
      final config = createRouterConfig(loginBloc);

      await tester.pumpWidget(
        BlocSignalProvider<LoginBloc>.value(
          value: loginBloc,
          child: MyApp(routerConfig: config),
        ),
      );

      // Verify that the login screen is rendered
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);

      // Attempt unauthenticated navigation to HomeRoute
      config.router.push(const HomeRoute('intruder'));
      await tester.pumpAndSettle();

      // Should still be on LoginScreen because authGuard blocked it
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('Hello, intruder!'), findsNothing);
    });

    testWidgets(
        'Logging in triggers reevaluateOn and transitions to HomeScreen', (
      WidgetTester tester,
    ) async {
      final loginBloc = LoginBloc();
      final config = createRouterConfig(loginBloc);

      await tester.pumpWidget(
        BlocSignalProvider<LoginBloc>.value(
          value: loginBloc,
          child: MyApp(routerConfig: config),
        ),
      );

      expect(find.text('Welcome Back'), findsOneWidget);

      // Enter valid credentials
      await tester.enterText(find.byType(TextField).at(0), 'Randal');
      await tester.enterText(find.byType(TextField).at(1), 'password');
      await tester.tap(find.text('Sign In'));

      // Advance past simulated network delay in LoginBloc (800ms)
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();

      // Verify we arrived at HomeScreen without manual navigation in the widget
      expect(find.text('Hello, Randal!'), findsOneWidget);
      expect(find.text('Welcome Back'), findsNothing);
    });

    testWidgets(
        'Logging out triggers reevaluateOn and transitions back to LoginScreen',
        (
      WidgetTester tester,
    ) async {
      final loginBloc = LoginBloc();
      // Start already logged in
      loginBloc.emit(
        const LoginState(username: 'Randal', isLoggedIn: true),
      );

      final config = createRouterConfig(loginBloc);

      await tester.pumpWidget(
        BlocSignalProvider<LoginBloc>.value(
          value: loginBloc,
          child: MyApp(routerConfig: config),
        ),
      );

      await tester.pumpAndSettle();

      // Verify currently on HomeScreen
      expect(find.text('Hello, Randal!'), findsOneWidget);

      // Tap the logout icon
      await tester.tap(find.byIcon(Icons.logout));
      await tester.pumpAndSettle();

      // Verify we automatically transitioned back to LoginScreen via guard re-evaluation
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('Hello, Randal!'), findsNothing);
    });
  });
}
