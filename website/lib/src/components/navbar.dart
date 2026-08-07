import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

class Navbar extends StatelessComponent {
  const Navbar({this.currentPath = '/', super.key});

  final String currentPath;

  @override
  Component build(BuildContext context) {
    return header(classes: 'navbar', [
      div(classes: 'container nav-content', [
        a(href: '/', classes: 'brand', [
          img(
              src: '/assets/logo.png',
              alt: 'BlocSignal Logo',
              width: 36,
              height: 36),
          span(classes: 'brand-title', [Component.text('BlocSignal')]),
          span(classes: 'brand-badge', [Component.text('v1.0.0')]),
        ]),
        nav(classes: 'nav-links', [
          a(
            href: '/',
            classes: currentPath == '/' ? 'nav-active' : '',
            [Component.text('Home')],
          ),
          a(
            href: '/showcase',
            classes: currentPath == '/showcase' ? 'nav-active' : '',
            [Component.text('Showcase')],
          ),
          a(
            href: '/ported-examples',
            classes: currentPath == '/ported-examples' ? 'nav-active' : '',
            [Component.text('Ported Examples')],
          ),
          a(
            href: '/minesweeper',
            classes: currentPath == '/minesweeper' ? 'nav-active' : '',
            [Component.text('🎮 Minesweeper')],
          ),
          a(
            href: '/publications',
            classes: currentPath == '/publications' ? 'nav-active' : '',
            [Component.text('📚 Publications')],
          ),
          a(
              href: 'https://pub.dev/packages/bloc_signals',
              target: Target.blank,
              [Component.text('pub.dev')]),
          a(
            href: 'https://github.com/RandalSchwartz/BlocSignal',
            target: Target.blank,
            classes: 'btn-github',
            [Component.text('GitHub ⭐️')],
          ),
        ]),
      ]),
    ]);
  }
}
