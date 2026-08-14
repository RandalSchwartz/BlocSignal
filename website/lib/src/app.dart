import 'package:bloc_signals_jaspr/bloc_signals_jaspr.dart';
import 'package:jaspr/jaspr.dart';

import 'cubits/navigation_cubit.dart';
import 'pages/home_page.dart';
import 'pages/minesweeper_page.dart';
import 'pages/ported_examples_page.dart';
import 'pages/publications_page.dart';
import 'pages/showcase_page.dart';

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
    return BlocSignalBuilder<NavigationCubit, String>(
      builder: (context, currentPath) {
        switch (currentPath) {
          case '/showcase':
            return const ShowcasePage();
          case '/ported-examples':
            return const PortedExamplesPage();
          case '/minesweeper':
            return const MinesweeperPage();
          case '/publications':
            return const PublicationsPage();
          case '/':
          default:
            return const HomePage();
        }
      },
    );
  }
}
