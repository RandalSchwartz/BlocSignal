import 'package:flutter_test/flutter_test.dart';
import 'package:example/main.dart';
import 'package:kaisel/kaisel.dart';
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';

void main() {
  testWidgets('App renders login screen initially', (
    WidgetTester tester,
  ) async {
    final config = KaiselRouterConfig<AppRoute>(
      initial: const LoginRoute(),
      builder: (context, route) => switch (route) {
        LoginRoute() => const LoginScreen(),
        HomeRoute(:final username) => HomeScreen(username: username),
      },
    );

    await tester.pumpWidget(
      BlocSignalProvider<LoginBloc>(
        create: (_) => LoginBloc(),
        child: MyApp(routerConfig: config),
      ),
    );

    // Verify that the login screen welcome text is present
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
