import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import '../components/footer.dart';
import '../components/hero.dart';
import '../components/live_visualizer.dart';
import '../components/navbar.dart';
import '../components/package_catalog.dart';

class HomePage extends StatelessComponent {
  const HomePage({super.key});

  @override
  Component build(BuildContext context) {
    return div(classes: 'app-root', [
      const Navbar(),
      main_([
        const HeroBanner(),
        const LiveVisualizer(),
        const PackageCatalog(),
      ]),
      const Footer(),
    ]);
  }
}
