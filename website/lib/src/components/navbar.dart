import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

class Navbar extends StatefulComponent {
  const Navbar({this.currentPath = '/', super.key});

  final String currentPath;

  @override
  State<Navbar> createState() => _NavbarState();
}

class _NavbarState extends State<Navbar> {
  bool _isOpen = false;

  void _toggleDrawer() {
    setState(() {
      _isOpen = !_isOpen;
    });
  }

  void _closeDrawer() {
    if (_isOpen) {
      setState(() {
        _isOpen = false;
      });
    }
  }

  @override
  Component build(BuildContext context) {
    return header(classes: 'navbar', [
      div(classes: 'container nav-content', [
        a(
          href: '/',
          classes: 'brand',
          onClick: _closeDrawer,
          [
            img(
              src: '/assets/logo.png',
              alt: 'BlocSignal Logo',
              width: 36,
              height: 36,
            ),
            span(classes: 'brand-title', [Component.text('BlocSignal')]),
            span(classes: 'brand-badge', [Component.text('v1.0.0')]),
          ],
        ),

        // Desktop Navigation Links
        nav(classes: 'nav-links nav-desktop', [
          a(
            href: '/',
            classes: component.currentPath == '/' ? 'nav-active' : '',
            [Component.text('Home')],
          ),
          a(
            href: '/#architecture',
            [Component.text('Architecture')],
          ),
          a(
            href: '/showcase',
            classes: component.currentPath == '/showcase' ? 'nav-active' : '',
            [Component.text('Showcase')],
          ),
          a(
            href: '/ported-examples',
            classes: component.currentPath == '/ported-examples' ? 'nav-active' : '',
            [Component.text('Ported Examples')],
          ),
          a(
            href: '/minesweeper',
            classes: component.currentPath == '/minesweeper' ? 'nav-active' : '',
            [Component.text('🎮 Minesweeper')],
          ),
          a(
            href: '/publications',
            classes: component.currentPath == '/publications' ? 'nav-active' : '',
            [Component.text('📚 Publications')],
          ),
          a(
            href: 'https://pub.dev/packages/bloc_signals',
            target: Target.blank,
            [Component.text('pub.dev')],
          ),
          a(
            href: 'https://github.com/RandalSchwartz/BlocSignal',
            target: Target.blank,
            classes: 'btn-github',
            [Component.text('GitHub ⭐️')],
          ),
        ]),

        // Mobile Hamburger / Close Button
        button(
          classes: 'nav-toggle ${_isOpen ? "open" : ""}',
          onClick: _toggleDrawer,
          attributes: {
            'aria-label': 'Toggle navigation menu',
            'aria-expanded': '$_isOpen',
          },
          [
            span(classes: 'burger-line line-1', []),
            span(classes: 'burger-line line-2', []),
            span(classes: 'burger-line line-3', []),
          ],
        ),
      ]),

      // Mobile Drawer Backdrop & Menu Panel
      if (_isOpen) ...[
        div(
          classes: 'nav-drawer-backdrop',
          events: {'click': (_) => _closeDrawer()},
          [],
        ),
        nav(
          classes: 'nav-drawer-panel',
          attributes: {
            'role': 'dialog',
            'aria-label': 'Mobile Navigation',
          },
          [
            div(classes: 'drawer-header', [
              span(classes: 'drawer-title', [Component.text('Navigation')]),
              button(
                classes: 'drawer-close-btn',
                onClick: _closeDrawer,
                attributes: {'aria-label': 'Close Navigation'},
                [Component.text('✕')],
              ),
            ]),
            div(classes: 'drawer-links', [
              a(
                href: '/',
                classes:
                    'drawer-link ${component.currentPath == "/" ? "active" : ""}',
                onClick: _closeDrawer,
                [
                  span(classes: 'drawer-link-icon', [Component.text('🏠')]),
                  span(classes: 'drawer-link-label', [Component.text('Home')]),
                ],
              ),
              a(
                href: '/#architecture',
                classes: 'drawer-link',
                onClick: _closeDrawer,
                [
                  span(classes: 'drawer-link-icon', [Component.text('⚡')]),
                  span(classes: 'drawer-link-label', [Component.text('Architecture')]),
                ],
              ),
              a(
                href: '/showcase',
                classes:
                    'drawer-link ${component.currentPath == "/showcase" ? "active" : ""}',
                onClick: _closeDrawer,
                [
                  span(classes: 'drawer-link-icon', [Component.text('✨')]),
                  span(classes: 'drawer-link-label', [Component.text('Showcase')]),
                ],
              ),
              a(
                href: '/ported-examples',
                classes:
                    'drawer-link ${component.currentPath == "/ported-examples" ? "active" : ""}',
                onClick: _closeDrawer,
                [
                  span(classes: 'drawer-link-icon', [Component.text('🔄')]),
                  span(classes: 'drawer-link-label', [Component.text('Ported Examples')]),
                ],
              ),
              a(
                href: '/minesweeper',
                classes:
                    'drawer-link ${component.currentPath == "/minesweeper" ? "active" : ""}',
                onClick: _closeDrawer,
                [
                  span(classes: 'drawer-link-icon', [Component.text('🎮')]),
                  span(classes: 'drawer-link-label', [Component.text('Minesweeper')]),
                ],
              ),
              a(
                href: '/publications',
                classes:
                    'drawer-link ${component.currentPath == "/publications" ? "active" : ""}',
                onClick: _closeDrawer,
                [
                  span(classes: 'drawer-link-icon', [Component.text('📚')]),
                  span(classes: 'drawer-link-label', [Component.text('Publications')]),
                ],
              ),
            ]),
            div(classes: 'drawer-actions', [
              a(
                href: 'https://pub.dev/packages/bloc_signals',
                target: Target.blank,
                classes: 'drawer-btn drawer-btn-pub',
                [Component.text('View on pub.dev ↗')],
              ),
              a(
                href: 'https://github.com/RandalSchwartz/BlocSignal',
                target: Target.blank,
                classes: 'drawer-btn drawer-btn-github',
                [Component.text('GitHub Star ⭐️')],
              ),
            ]),
          ],
        ),
      ],
    ]);
  }
}
