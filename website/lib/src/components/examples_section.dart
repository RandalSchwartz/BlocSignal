import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

class ExamplesSection extends StatelessComponent {
  const ExamplesSection({super.key});

  @override
  Component build(BuildContext context) {
    final examples = [
      (
        title: 'Flutter Counter',
        tag: 'Basics',
        desc:
            'Side-by-side comparison of CubitSignal vs BlocSignal with zero microtask latency.',
        icon: '🔢',
        path: 'examples/flutter_counter',
      ),
      (
        title: 'Flutter AsyncState',
        tag: 'Async UI',
        desc:
            'Handling AsyncData, AsyncLoading, and AsyncError using signals_core.',
        icon: '⏳',
        path: 'examples/flutter_async',
      ),
      (
        title: 'Shopping Cart',
        tag: 'State & Selectors',
        desc:
            'CatalogCubit, CartBloc, and fine-grained BlocSignalSelector rebuilds.',
        icon: '🛒',
        path: 'examples/shopping_cart',
      ),
      (
        title: 'Auth & Session Flow',
        tag: 'Persistence',
        desc: 'HydratedCubitSignal auth state restoration across app restarts.',
        icon: '🔐',
        path: 'examples/auth_flow',
      ),
      (
        title: 'Infinite Scroll Search',
        tag: 'Concurrency',
        desc: 'Streamless droppable() throttling & restartable() debouncing.',
        icon: '📜',
        path: 'examples/infinite_scroll',
      ),
      (
        title: 'Dynamic Colorband',
        tag: 'Signal Derivations',
        desc:
            'Computed RGBA color channels and fine-grained UI slider updates.',
        icon: '🎨',
        path: 'examples/flutter_colorband',
      ),
      (
        title: 'State Machine Calculator',
        tag: 'Sealed Events',
        desc:
            'Arithmetic state machine with sealed event classes (DigitPressed, EqualsPressed).',
        icon: '🧮',
        path: 'examples/eval_calculator',
      ),
      (
        title: 'SharedPreferences Persistence',
        tag: 'Hydration',
        desc:
            'Zero-override primitive & collection persistence with HydratedCubitSignal.',
        icon: '💾',
        path: 'examples/persist_shared_preferences',
      ),
      (
        title: 'Clean Architecture Weather',
        tag: 'Layered Architecture',
        desc:
            '3-tier Presentation / Domain / Data separation with mock repositories.',
        icon: '🏗️',
        path: 'examples/clean_architecture',
      ),
      (
        title: 'GetIt Service Locator DI',
        tag: 'Dependency Injection',
        desc:
            'Bridging GetIt singletons to widget tree via BlocSignalProvider.value.',
        icon: '🔌',
        path: 'examples/get_it_signals',
      ),
    ];

    return section(id: 'examples', classes: 'catalog-section', [
      div(classes: 'container', [
        h2(
            classes: 'section-title',
            [Component.text('Runnable Showcase Applications')]),
        p(classes: 'section-subtitle', [
          Component.text(
              '10 fully tested, self-contained example applications with complete doc comments and widget unit tests.'),
        ]),
        div(classes: 'package-grid', [
          for (final ex in examples)
            div(classes: 'package-card', [
              div(classes: 'card-header', [
                span(classes: 'card-icon', [Component.text(ex.icon)]),
                span(classes: 'card-version', [Component.text(ex.tag)]),
              ]),
              h3(classes: 'card-title', [Component.text(ex.title)]),
              p(classes: 'card-desc', [Component.text(ex.desc)]),
              a(
                href:
                    'https://github.com/RandalSchwartz/BlocSignal/tree/main/${ex.path}',
                target: Target.blank,
                classes: 'card-link',
                [Component.text('View Source & Tests →')],
              ),
            ]),
        ]),
      ]),
    ]);
  }
}
