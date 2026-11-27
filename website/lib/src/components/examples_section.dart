import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../models/app_route.dart';

class const ExamplesSection({super.key}) extends StatelessComponent {
  /// Community-built showcase applications using BlocSignal.
  static const List<
    ({
      String title,
      String tag,
      String desc,
      String icon,
      String author,
      String url,
    })
  >
  communityShowcase = [
    (
      title: 'dog_ceo_signals_app',
      tag: 'Fine-Grained Signals & Breed Browser',
      desc: 'Real-world Flutter adoption showcasing fine-grained computed signals, preserved dropdown state during image fetches, and clean BlocSignal architecture.',
      icon: '🐶',
      author: 'Daniel Casey (@tataDan)',
      url: 'https://github.com/tataDan/dog_ceo_signals_app',
    ),
  ];

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
        title: 'Enterprise FIC Shopping Cart',
        tag: 'Fast Immutable Collections & Replay',
        desc: 'Unbreakable shopping cart with IMap, offline JSON persistence, O(1) copy-on-write mutations, and zero-cost time-travel undo/redo.',
        icon: '🛍️',
        path: 'examples/fic_shopping_cart',
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
        title: 'Self-Paging Controller',
        tag: 'CubitSignalMixin & Stateless UI',
        desc: 'ScrollController with CubitSignalMixin & BlocSignalMixin for zero-glue infinite scroll with 100% StatelessWidgets.',
        icon: '⚡',
        path: 'examples/infinite_scroll_mixin',
        webLink: null,
      ),
      (
        title: 'The Iceberg Pattern',
        tag: 'Real-Time Architecture',
        desc: 'Submerged reactive repository engine with 0ms optimistic mutations, silent rollback, and screen-scoped facades.',
        icon: '🧊',
        path: 'examples/iceberg_pattern',
        webLink: null,
      ),
      (
        title: 'AI Flight Booking Assistant',
        tag: 'Generative UI & A2UI',
        desc: 'Real-time generative UI streaming via Gemini SSE, interactive seat selection, passenger form signals, and deterministic offline mock mode.',
        icon: '✈️',
        path: 'examples/genui_flight_booking',
        webLink: null,
      ),
      (
        title: 'Context Selector Ergonomics',
        tag: 'Fine-Grained Selectors',
        desc: 'Granular context.select<B, R> rebuild optimization and modern constructor ergonomics in Flutter.',
        icon: '🎯',
        path: 'examples/flutter_context_ergonomics',
        webLink: null,
      ),
      (
        title: 'Terminal GenUI Agent',
        tag: 'A2UI CLI & Pure Dart',
        desc: 'Interactive ANSI terminal TUI agent proving pure-Dart state machine decoupling without Flutter.',
        icon: '💻',
        path: 'examples/genui_tui_agent',
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
        webLink: AppRoute.minesweeper.path,
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
                  attributes: const {'rel': 'noopener noreferrer'},
                  classes: 'card-link',
                  [Component.text('View Source & Tests ↗')],
                ),
              ]),
            ]),
        ]),
        div(classes: 'spacer-vertical', []),
        h2(classes: 'section-title', [Component.text('Community Showcase')]),
        p(classes: 'section-subtitle', [
          Component.text(
            'Open-source applications built by the Flutter and Dart community with BlocSignal.',
          ),
        ]),
        div(classes: 'package-grid', [
          for (final item in communityShowcase)
            div(classes: 'package-card', [
              div(classes: 'card-header', [
                span(classes: 'card-icon', [Component.text(item.icon)]),
                span(classes: 'card-version', [Component.text(item.tag)]),
              ]),
              h3(classes: 'card-title', [Component.text(item.title)]),
              p(classes: 'card-desc', [Component.text(item.desc)]),
              p(classes: 'card-desc', [
                Component.text('Built by ${item.author}'),
              ]),
              div(classes: 'card-links-row', [
                a(
                  href: item.url,
                  target: Target.blank,
                  attributes: const {'rel': 'noopener noreferrer'},
                  classes: 'card-link',
                  [Component.text('View on GitHub ↗')],
                ),
              ]),
            ]),
        ]),
      ]),
    ]);
  }
}
