import 'package:jaspr/jaspr.dart';

import '../pages/docs_page.dart';
import '../pages/home_page.dart';
import '../pages/minesweeper_page.dart';
import '../pages/playground_page.dart';
import '../pages/ported_examples_page.dart';
import '../pages/publications_page.dart';
import '../pages/showcase_page.dart';
import 'app_route.dart';

/// UI page builder mapping for [AppRoute].
extension AppRouteBuilder on AppRoute {
  /// Returns the Jaspr page [Component] constructor for this route.
  Component Function() get builder => switch (this) {
    AppRoute.home => HomePage.new,
    AppRoute.docs => DocsPage.new,
    AppRoute.showcase => ShowcasePage.new,
    AppRoute.portedExamples => PortedExamplesPage.new,
    AppRoute.minesweeper => MinesweeperPage.new,
    AppRoute.publications => PublicationsPage.new,
    AppRoute.playground => PlaygroundPage.new,
  };
}
