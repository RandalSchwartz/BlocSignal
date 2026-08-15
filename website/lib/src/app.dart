import 'package:bloc_signals_jaspr/bloc_signals_jaspr.dart';
import 'package:jaspr/jaspr.dart';

import 'cubits/navigation_cubit.dart';
import 'models/app_route.dart';

class const App({super.key}) extends StatelessComponent {
  @override
  Component build(BuildContext context) {
    return BlocSignalProvider<NavigationCubit>(
      create: (_) => NavigationCubit(),
      child: const _AppRouter(),
    );
  }
}

class const _AppRouter() extends StatelessComponent {
  @override
  Component build(BuildContext context) {
    return BlocSignalBuilder<NavigationCubit, AppRoute>(
      builder: (context, currentRoute) => currentRoute.builder(),
    );
  }
}
