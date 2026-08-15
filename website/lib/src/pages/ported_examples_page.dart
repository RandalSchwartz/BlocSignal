import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../components/footer.dart';
import '../components/navbar.dart';
import '../components/ported_examples_section.dart';
import '../models/app_route.dart';

class const PortedExamplesPage({super.key}) extends StatelessComponent {
  @override
  Component build(BuildContext context) {
    return div(classes: 'app-root', [
      const Navbar(currentRoute: AppRoute.portedExamples),
      main_([const PortedExamplesSection()]),
      const Footer(),
    ]);
  }
}
