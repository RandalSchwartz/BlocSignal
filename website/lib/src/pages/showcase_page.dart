import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../components/examples_section.dart';
import '../components/footer.dart';
import '../components/navbar.dart';
import '../models/app_route.dart';

class const ShowcasePage({super.key}) extends StatelessComponent {
  @override
  Component build(BuildContext context) {
    return div(classes: 'app-root', [
      const Navbar(currentRoute: AppRoute.showcase),
      main_([const ExamplesSection()]),
      const Footer(),
    ]);
  }
}
