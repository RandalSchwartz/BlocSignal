import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import '../components/footer.dart';
import '../components/navbar.dart';
import '../components/ported_examples_section.dart';

class PortedExamplesPage extends StatelessComponent {
  const PortedExamplesPage({super.key});

  @override
  Component build(BuildContext context) {
    return div(classes: 'app-root', [
      const Navbar(currentPath: '/ported-examples'),
      main_([
        const PortedExamplesSection(),
      ]),
      const Footer(),
    ]);
  }
}
