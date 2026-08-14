import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../components/footer.dart';
import '../components/navbar.dart';
import '../components/ported_examples_section.dart';

class const PortedExamplesPage({super.key}) extends StatelessComponent {
  @override
  Component build(BuildContext context) {
    return div(classes: 'app-root', [
      const Navbar(currentPath: '/ported-examples'),
      main_([const PortedExamplesSection()]),
      const Footer(),
    ]);
  }
}
