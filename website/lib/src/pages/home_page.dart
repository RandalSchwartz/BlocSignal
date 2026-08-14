import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../components/architecture_section.dart';
import '../components/footer.dart';
import '../components/hero.dart';
import '../components/live_visualizer.dart';
import '../components/navbar.dart';
import '../components/package_catalog.dart';

class const HomePage({super.key}) extends StatelessComponent {
  @override
  Component build(BuildContext context) {
    return div(classes: 'app-root', [
      const Navbar(currentPath: '/'),
      main_([
        const HeroBanner(),
        const LiveVisualizer(),
        const ArchitectureSection(),
        const PackageCatalog(),
      ]),
      const Footer(),
    ]);
  }
}
