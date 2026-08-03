import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../components/footer.dart';
import '../components/minesweeper/minesweeper_component.dart';
import '../components/navbar.dart';

class MinesweeperPage extends StatelessComponent {
  const MinesweeperPage({super.key});

  @override
  Component build(BuildContext context) {
    return div(classes: 'app-root', [
      const Navbar(currentPath: '/minesweeper'),
      main_([
        section(classes: 'minesweeper-hero-section', [
          div(classes: 'container', [
            h1(classes: 'section-title', [
              Component.text('🎮 Interactive Minesweeper Case Study'),
            ]),
            p(classes: 'section-subtitle', [
              Component.text(
                'Built live with BlocSignal & Jaspr web component bindings. Demonstrates 0ms synchronous flood fill, client-side state persistence, and shareable seed passcodes.',
              ),
            ]),
            const MinesweeperComponent(),
            div(classes: 'ms-tech-highlights', [
              h3([Component.text('⚡ Architectural Highlights')]),
              ul([
                li([
                  strong([Component.text('0ms Synchronous Flood Fill: ')]),
                  Component.text(
                    'Revealing a blank cell recursively opens neighboring regions synchronously in the exact same frame without microtask lag.',
                  ),
                ]),
                li([
                  strong([Component.text('Synchronous State Persistence: ')]),
                  Component.text(
                    'Active game progress is saved synchronously to localStorage on every move so your board restores instantly on tab refreshes.',
                  ),
                ]),
                li([
                  strong([Component.text('Seed Passcodes: ')]),
                  Component.text(
                    'Share base64-encoded game seeds to challenge friends on identical minefield layouts.',
                  ),
                ]),
              ]),
            ]),
          ]),
        ]),
      ]),
      const Footer(),
    ]);
  }
}
