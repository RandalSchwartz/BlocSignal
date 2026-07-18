---
name: kaisel
description: Best practices for using the kaisel type-safe router package in Flutter.
---
# Kaisel Router Best Practices

`kaisel` is a Dart 3-native router built on sealed routes, pattern matching, and a stack-as-state model. Follow these patterns:

## 1. Defining sealed routes
All routes must extend `KaiselRoute`. Define them as a sealed class hierarchy to guarantee compiler-time exhaustiveness:

```dart
import 'package:kaisel/kaisel.dart';

sealed class AppRoute extends KaiselRoute {
  const AppRoute();
}

final class LoginRoute extends AppRoute {
  const LoginRoute();
}

final class HomeRoute extends AppRoute {
  const HomeRoute(this.username);
  final String username;

  @override
  List<Object?> get props => [username];
}
```

## 2. Router Configuration
Build your router configuration using `KaiselRouterConfig` and map routes to screens using a `switch` expression:

```dart
final routerConfig = KaiselRouterConfig<AppRoute>(
  initial: const LoginRoute(),
  builder: (context, route) => switch (route) {
    LoginRoute() => const LoginScreen(),
    HomeRoute(:final username) => HomeScreen(username: username),
  },
);
```

## 3. MaterialApp Integration
Pass the `KaiselRouterConfig` directly to `MaterialApp.router`:

```dart
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: routerConfig,
    );
  }
}
```

## 4. Navigation
Perform navigation on `BuildContext` using typed routes rather than string paths:

```dart
// Push a new route
context.push(const HomeRoute('Alice'));

// Replace current route
context.go(const HomeRoute('Alice'));

// Pop the current route
context.pop();
```
