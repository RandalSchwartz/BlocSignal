import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../components/examples_section.dart';
import '../components/footer.dart';
import '../components/navbar.dart';

class const ShowcasePage({super.key}) extends StatelessComponent {
  @override
  Component build(BuildContext context) {
    return div(classes: 'app-root', [
      const Navbar(currentPath: '/showcase'),
      main_([const ExamplesSection()]),
      const Footer(),
    ]);
  }
}
