import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import '../components/examples_section.dart';
import '../components/footer.dart';
import '../components/navbar.dart';

class ShowcasePage extends StatelessComponent {
  const ShowcasePage({super.key});

  @override
  Component build(BuildContext context) {
    return div(classes: 'app-root', [
      const Navbar(currentPath: '/showcase'),
      main_([
        const ExamplesSection(),
      ]),
      const Footer(),
    ]);
  }
}
