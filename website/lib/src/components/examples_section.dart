import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

class const ExamplesSection({super.key}) extends StatelessComponent {
  @override
  Component build(BuildContext context) {
    final nativeShowcase = [
      (
        title: 'Auth & Session Flow',
        tag: 'Persistence & Hydration',
        desc: 'HydratedCubitSignal auth state restoration, token storage, and session lifecycle across app restarts.',
        icon: '🔐',
        path: 'examples/auth_flow',
        webLink: null,
      ),
      (
        title: 'Shopping Cart & Catalog',
        tag: 'State & Selectors',
        desc: 'CatalogCubit, CartBloc, and fine-grained BlocSignalSelector rebuild optimizations.',
        icon: '🛒',
        path: 'examples/shopping_cart',
        webLink: null,
      ),
      (
        title: 'Infinite Scroll Search',
        tag: 'Streamless Concurrency',
        desc: 'Streamless droppable() list throttling & restartable() search input debouncing without RxStreams.',
        icon: '📜',
        path: 'examples/infinite_scroll',
        webLink: null,
      ),
      (
        title: 'Flutter Counter',
        tag: 'Core Primitives',
        desc: 'Side-by-side demonstration of CubitSignal vs BlocSignal with zero microtask latency.',
        icon: '🔢',
        path: 'examples/flutter_counter',
        webLink: null,
      ),
      (
        title: 'Minesweeper Puzzle Game',
        tag: 'Sealed Events & Hydration',
        desc: 'HydratedBlocSignal puzzle game with Dart 3 pattern matching, safe first click & BFS flood fill.',
        icon: '💣',
        path: 'examples/mine_sweeper',
        webLink: '/minesweeper',
      ),
    ];

    return section(id: 'examples', classes: 'catalog-section', [
      div(classes: 'container', [
        h2(classes: 'section-title', [
          Component.text('Native Showcase Applications'),
        ]),
        p(classes: 'section-subtitle', [
          Component.text(
            'Real-world applications built natively for BlocSignal demonstrating production architecture, hydration, and fine-grained selector rebuilds.',
          ),
        ]),
        div(classes: 'package-grid', [
          for (final ex in nativeShowcase)
            div(classes: 'package-card', [
              div(classes: 'card-header', [
                span(classes: 'card-icon', [Component.text(ex.icon)]),
                span(classes: 'card-version', [Component.text(ex.tag)]),
              ]),
              h3(classes: 'card-title', [Component.text(ex.title)]),
              p(classes: 'card-desc', [Component.text(ex.desc)]),
              div(classes: 'card-links-row', [
                if (ex.webLink != null) ...[
                  a(href: ex.webLink!, classes: 'card-link demo-link', [
                    Component.text('🎮 Play Interactive Web Demo →'),
                  ]),
                  span([Component.text(' • ')]),
                ],
                a(
                  href:
                      'https://github.com/RandalSchwartz/BlocSignal/tree/main/${ex.path}',
                  target: Target.blank,
                  classes: 'card-link',
                  [Component.text('View Source & Tests ↗')],
                ),
              ]),
            ]),
        ]),
      ]),
    ]);
  }
}
