import 'package:bloc_signals_jaspr/bloc_signals_jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../cubits/navigation_cubit.dart';
import '../models/app_route.dart';

class const Navbar({final AppRoute? currentRoute, super.key})
    extends StatefulComponent {
  @override
  State<Navbar> createState() => _NavbarState();
}

class _NavbarState() extends State<Navbar> {
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
    final activeRoute =
        component.currentRoute ??
        (() {
          try {
            return context.select<NavigationCubit, AppRoute>(
              (c) => c.stateValue,
            );
          } catch (_) {
            return AppRoute.home;
          }
        })();

    return header(classes: 'navbar', [
      div(classes: 'container nav-content', [
        a(href: AppRoute.home.path, classes: 'brand', onClick: _closeDrawer, [
          img(
            src: '/assets/logo.png',
            alt: 'BlocSignal Logo',
            width: 36,
            height: 36,
          ),
          span(classes: 'brand-title', [Component.text('BlocSignal')]),
          span(classes: 'brand-badge', [Component.text('v1.1.0')]),
        ]),

        // Desktop Navigation Links
        nav(classes: 'nav-links nav-desktop', [
          a(
            href: AppRoute.home.path,
            classes: activeRoute == AppRoute.home ? 'nav-active' : '',
            [Component.text('Home')],
          ),
          a(
            href: AppRoute.docs.path,
            classes: activeRoute == AppRoute.docs ? 'nav-active' : '',
            [Component.text('Docs 📖')],
          ),
          a(href: '/#architecture', [Component.text('Architecture')]),
          a(
            href: AppRoute.showcase.path,
            classes: activeRoute == AppRoute.showcase ? 'nav-active' : '',
            [Component.text(AppRoute.showcase.label)],
          ),
          a(
            href: AppRoute.portedExamples.path,
            classes: activeRoute == AppRoute.portedExamples ? 'nav-active' : '',
            [Component.text(AppRoute.portedExamples.label)],
          ),
          a(
            href: AppRoute.minesweeper.path,
            classes: activeRoute == AppRoute.minesweeper ? 'nav-active' : '',
            [Component.text(AppRoute.minesweeper.label)],
          ),
          a(
            href: AppRoute.publications.path,
            classes: activeRoute == AppRoute.publications ? 'nav-active' : '',
            [Component.text(AppRoute.publications.label)],
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
          attributes: {'role': 'dialog', 'aria-label': 'Mobile Navigation'},
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
                href: AppRoute.home.path,
                classes:
                    'drawer-link ${activeRoute == AppRoute.home ? "active" : ""}',
                onClick: _closeDrawer,
                [
                  span(classes: 'drawer-link-icon', [Component.text('🏠')]),
                  span(classes: 'drawer-link-label', [Component.text('Home')]),
                ],
              ),
              a(
                href: AppRoute.docs.path,
                classes:
                    'drawer-link ${activeRoute == AppRoute.docs ? "active" : ""}',
                onClick: _closeDrawer,
                [
                  span(classes: 'drawer-link-icon', [Component.text('📖')]),
                  span(classes: 'drawer-link-label', [Component.text('Docs')]),
                ],
              ),
              a(
                href: '/#architecture',
                classes: 'drawer-link',
                onClick: _closeDrawer,
                [
                  span(classes: 'drawer-link-icon', [Component.text('⚡')]),
                  span(classes: 'drawer-link-label', [
                    Component.text('Architecture'),
                  ]),
                ],
              ),
              a(
                href: AppRoute.showcase.path,
                classes:
                    'drawer-link ${activeRoute == AppRoute.showcase ? "active" : ""}',
                onClick: _closeDrawer,
                [
                  span(classes: 'drawer-link-icon', [Component.text('✨')]),
                  span(classes: 'drawer-link-label', [
                    Component.text(AppRoute.showcase.label),
                  ]),
                ],
              ),
              a(
                href: AppRoute.portedExamples.path,
                classes:
                    'drawer-link ${activeRoute == AppRoute.portedExamples ? "active" : ""}',
                onClick: _closeDrawer,
                [
                  span(classes: 'drawer-link-icon', [Component.text('🔄')]),
                  span(classes: 'drawer-link-label', [
                    Component.text(AppRoute.portedExamples.label),
                  ]),
                ],
              ),
              a(
                href: AppRoute.minesweeper.path,
                classes:
                    'drawer-link ${activeRoute == AppRoute.minesweeper ? "active" : ""}',
                onClick: _closeDrawer,
                [
                  span(classes: 'drawer-link-icon', [Component.text('🎮')]),
                  span(classes: 'drawer-link-label', [
                    Component.text('Minesweeper'),
                  ]),
                ],
              ),
              a(
                href: AppRoute.publications.path,
                classes:
                    'drawer-link ${activeRoute == AppRoute.publications ? "active" : ""}',
                onClick: _closeDrawer,
                [
                  span(classes: 'drawer-link-icon', [Component.text('📚')]),
                  span(classes: 'drawer-link-label', [
                    Component.text('Publications'),
                  ]),
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
