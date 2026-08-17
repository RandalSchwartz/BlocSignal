import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../components/docs/pages/docs_installation.dart';
import '../components/docs/pages/docs_overview.dart';
import '../components/docs/pages/docs_quickstart.dart';
import 'docs_models.dart';

/// Central registry of all documentation topics and categories across all phases.
class const DocsRegistry() {
  static final List<DocCategory> categories = [
    const DocCategory(
      title: 'Getting Started',
      icon: '🚀',
      sections: [
        DocSectionItem(
          id: 'overview',
          title: 'Overview & Why BlocSignal',
          path: '/docs/overview',
          category: 'Getting Started',
          description: '0ms synchronous reactivity, signals graph integration, and comparison matrix.',
          builder: DocsOverviewPage.new,
        ),
        DocSectionItem(
          id: 'installation',
          title: 'Installation & Package Matrix',
          path: '/docs/installation',
          category: 'Getting Started',
          description:
              'Platform-specific installation and monorepo package catalog.',
          builder: DocsInstallationPage.new,
        ),
        DocSectionItem(
          id: 'quickstart',
          title: 'Quickstart Guide',
          path: '/docs/quickstart',
          category: 'Getting Started',
          description: '5-minute tutorial covering Cubit, Bloc, Flutter UI, and testing.',
          builder: DocsQuickstartPage.new,
        ),
      ],
    ),
    DocCategory(
      title: 'Core Concepts',
      icon: '🧠',
      sections: [
        DocSectionItem(
          id: 'cubit-vs-bloc',
          title: 'CubitSignal vs. BlocSignal',
          path: '/docs/cubit-vs-bloc',
          category: 'Core Concepts',
          description: 'Choosing between direct method invocation and event-driven architectures.',
          badge: 'Phase 2',
          builder: () => _PlaceholderDoc(
            title: 'CubitSignal vs. BlocSignal',
            phase: 'Phase 2',
            description: 'In-depth architectural comparison, philosophy, and decision matrix between CubitSignal and BlocSignal.',
          ),
        ),
        DocSectionItem(
          id: 'state-modeling',
          title: 'State Modeling & Immutability',
          path: '/docs/state-modeling',
          category: 'Core Concepts',
          description: 'Immutable data models, Dart Records, Fast Immutable Collections (FIC), and custom equality comparators.',
          badge: 'Phase 2',
          builder: () => _PlaceholderDoc(
            title: 'State Modeling & Immutability',
            phase: 'Phase 2',
            description: 'Best practices for state modeling, immutability, Record states, and SignalOptions custom equals.',
          ),
        ),
        DocSectionItem(
          id: 'events-and-handlers',
          title: 'Events & Handlers',
          path: '/docs/events-and-handlers',
          category: 'Core Concepts',
          description: 'Registering typed event handlers with on<E>(), concurrency coordination, and error tracking.',
          badge: 'Phase 2',
          builder: () => _PlaceholderDoc(
            title: 'Events & Handlers',
            phase: 'Phase 2',
            description: 'How on<E> handlers work, synchronous event dispatching, and Future.wait concurrency.',
          ),
        ),
        DocSectionItem(
          id: 'event-transformers',
          title: 'Event Transformers',
          path: '/docs/event-transformers',
          category: 'Core Concepts',
          description: 'Streamless event transformers (droppable, sequential, restartable) and custom debounce/mutex locks.',
          badge: 'Phase 2',
          builder: () => _PlaceholderDoc(
            title: 'Event Transformers',
            phase: 'Phase 2',
            description: 'Streamless higher-order function concurrency transformers and Mutex locks.',
          ),
        ),
        DocSectionItem(
          id: 'lifecycle-and-observers',
          title: 'Lifecycle & Observers',
          path: '/docs/lifecycle-and-observers',
          category: 'Core Concepts',
          description: 'BlocSignalObserver, Change, Transition, and OpenTelemetry identity span tracking.',
          badge: 'Phase 2',
          builder: () => _PlaceholderDoc(
            title: 'Lifecycle & Observers',
            phase: 'Phase 2',
            description: 'Global and local observer lifecycles, Change/Transition logging, and DevTools hooks.',
          ),
        ),
        DocSectionItem(
          id: 'signals-reactivity',
          title: 'Signals Graph Reactivity',
          path: '/docs/signals-reactivity',
          category: 'Core Concepts',
          description: 'Understanding stateValue vs state, computed() derivations, and managed effect() reactions.',
          badge: 'Phase 2',
          builder: () => _PlaceholderDoc(
            title: 'Signals Graph Reactivity',
            phase: 'Phase 2',
            description: 'How ReadonlySignal powers automatic de-duplication, fine-grained reactivity, and 0ms updates.',
          ),
        ),
      ],
    ),
    DocCategory(
      title: 'Flutter Integration',
      icon: '📱',
      sections: [
        DocSectionItem(
          id: 'flutter-providers',
          title: 'BlocSignalProvider & Lookup',
          path: '/docs/flutter-providers',
          category: 'Flutter Integration',
          description: 'Dependency injection with BlocSignalProvider, MultiBlocSignalProvider, and O(1) lookups.',
          badge: 'Phase 3',
          builder: () => _PlaceholderDoc(
            title: 'BlocSignalProvider & Lookup',
            phase: 'Phase 3',
            description: 'Scoped state provision, lazy initialization, and O(1) InheritedElement resolution.',
          ),
        ),
        DocSectionItem(
          id: 'flutter-widgets',
          title: 'Builders, Listeners & Selectors',
          path: '/docs/flutter-widgets',
          category: 'Flutter Integration',
          description: 'BlocSignalBuilder, BlocSignalListener, BlocSignalConsumer, and fine-grained BlocSignalSelector.',
          badge: 'Phase 3',
          builder: () => _PlaceholderDoc(
            title: 'Builders, Listeners & Selectors',
            phase: 'Phase 3',
            description: 'UI binding widgets, side-effect listeners, and selector performance optimizations.',
          ),
        ),
        DocSectionItem(
          id: 'flutter-context',
          title: 'Context Extensions',
          path: '/docs/flutter-context',
          category: 'Flutter Integration',
          description: 'context.read<T>(), context.watch<T>(), and two-type-parameter context.select<B, R>().',
          badge: 'Phase 3',
          builder: () => _PlaceholderDoc(
            title: 'Context Extensions',
            phase: 'Phase 3',
            description: 'Type-safe BuildContext extensions for concise UI state access.',
          ),
        ),
      ],
    ),
    DocCategory(
      title: 'Testing',
      icon: '🧪',
      sections: [
        DocSectionItem(
          id: 'testing-guide',
          title: 'Declarative Testing with blocSignalTest',
          path: '/docs/testing-guide',
          category: 'Testing',
          description: 'Declarative unit testing, observer scoping, lifecycle verification, and async frame expectations.',
          badge: 'Phase 3',
          builder: () => _PlaceholderDoc(
            title: 'Declarative Testing with blocSignalTest',
            phase: 'Phase 3',
            description: 'How to test BlocSignal and CubitSignal state machines declaratively using bloc_signals_test.',
          ),
        ),
      ],
    ),
    DocCategory(
      title: 'Satellite Packages',
      icon: '📦',
      sections: [
        DocSectionItem(
          id: 'pkg-hydrate',
          title: 'bloc_signals_hydrate',
          path: '/docs/pkg-hydrate',
          category: 'Satellite Packages',
          description: 'Synchronous frame 1 state persistence across restarts.',
          badge: 'Phase 4',
          builder: () => _PlaceholderDoc(
            title: 'bloc_signals_hydrate',
            phase: 'Phase 4',
            description: 'State persistence with zero-boilerplate primitive and collection storage.',
          ),
        ),
        DocSectionItem(
          id: 'pkg-replay',
          title: 'bloc_signals_replay',
          path: '/docs/pkg-replay',
          category: 'Satellite Packages',
          description: 'Undo and redo history management with ReplayCubit and ReplayBloc.',
          badge: 'Phase 4',
          builder: () => _PlaceholderDoc(
            title: 'bloc_signals_replay',
            phase: 'Phase 4',
            description:
                'Time-travel and undo/redo stacks for state containers.',
          ),
        ),
        DocSectionItem(
          id: 'pkg-riverpod',
          title: 'bloc_signals_riverpod',
          path: '/docs/pkg-riverpod',
          category: 'Satellite Packages',
          description:
              'Bidirectional Riverpod 2 & 3 interoperability adapters.',
          badge: 'Phase 4',
          builder: () => _PlaceholderDoc(
            title: 'bloc_signals_riverpod',
            phase: 'Phase 4',
            description:
                'Bridging Riverpod providers into BlocSignal and vice-versa.',
          ),
        ),
        DocSectionItem(
          id: 'pkg-otel',
          title: 'bloc_signals_otel',
          path: '/docs/pkg-otel',
          category: 'Satellite Packages',
          description:
              'OpenTelemetry distributed tracing and observability spans.',
          badge: 'Phase 4',
          builder: () => _PlaceholderDoc(
            title: 'bloc_signals_otel',
            phase: 'Phase 4',
            description: 'Distributed tracing and OpenTelemetry metrics for transitions and errors.',
          ),
        ),
        DocSectionItem(
          id: 'pkg-devtools',
          title: 'bloc_signals_devtools',
          path: '/docs/pkg-devtools',
          category: 'Satellite Packages',
          description: 'DevTools timeline inspection and leak detector badge.',
          badge: 'Phase 4',
          builder: () => _PlaceholderDoc(
            title: 'bloc_signals_devtools',
            phase: 'Phase 4',
            description: 'Custom DevTools extension for timeline debugging and state inspection.',
          ),
        ),
      ],
    ),
    DocCategory(
      title: 'Architecture & Recipes',
      icon: '💡',
      sections: [
        DocSectionItem(
          id: 'recipe-one-shot',
          title: 'One-Shot UI Side Effects',
          path: '/docs/recipe-one-shot',
          category: 'Architecture & Recipes',
          description: 'Handling snackbars, dialogs, and navigation without polluting domain state.',
          badge: 'Phase 4',
          builder: () => _PlaceholderDoc(
            title: 'One-Shot UI Side Effects',
            phase: 'Phase 4',
            description:
                'Recipes for transient side-effects without state corruption.',
          ),
        ),
        DocSectionItem(
          id: 'recipe-form-validation',
          title: 'Form Validation',
          path: '/docs/recipe-form-validation',
          category: 'Architecture & Recipes',
          description: 'Primary input signals paired with computed() derived validation states.',
          badge: 'Phase 4',
          builder: () => _PlaceholderDoc(
            title: 'Form Validation',
            phase: 'Phase 4',
            description: 'Building performant, boilerplate-free forms with computed signals.',
          ),
        ),
        DocSectionItem(
          id: 'recipe-controllers',
          title: 'Coordinating Controllers',
          path: '/docs/recipe-controllers',
          category: 'Architecture & Recipes',
          description: 'Bidirectional syncing of TextEditingControllers without build-phase mutation loops.',
          badge: 'Phase 4',
          builder: () => _PlaceholderDoc(
            title: 'Coordinating Controllers',
            phase: 'Phase 4',
            description: 'How to coordinate Flutter controllers with reactive state containers safely.',
          ),
        ),
        DocSectionItem(
          id: 'recipe-caching',
          title: 'API Caching & TTL Expiration',
          path: '/docs/recipe-caching',
          category: 'Architecture & Recipes',
          description: 'Managing asynchronous server data with automatic cache invalidation.',
          badge: 'Phase 4',
          builder: () => _PlaceholderDoc(
            title: 'API Caching & TTL Expiration',
            phase: 'Phase 4',
            description: 'Implementing resilient API caching with time-to-live expiration.',
          ),
        ),
      ],
    ),
    DocCategory(
      title: 'Migration Guides',
      icon: '🔄',
      sections: [
        DocSectionItem(
          id: 'migration-bloc',
          title: 'Migrating from package:bloc',
          path: '/docs/migration-bloc',
          category: 'Migration Guides',
          description: 'Step-by-step migration guide from classic BLoC / flutter_bloc to BlocSignal.',
          badge: 'Phase 4',
          builder: () => _PlaceholderDoc(
            title: 'Migrating from package:bloc',
            phase: 'Phase 4',
            description: 'Comprehensive guide and code comparisons for migrating from Flutter BLoC.',
          ),
        ),
        DocSectionItem(
          id: 'migration-riverpod',
          title: 'Migrating from Riverpod',
          path: '/docs/migration-riverpod',
          category: 'Migration Guides',
          description: 'Step-by-step migration guide from Riverpod providers to BlocSignal.',
          badge: 'Phase 4',
          builder: () => _PlaceholderDoc(
            title: 'Migrating from Riverpod',
            phase: 'Phase 4',
            description: 'Comparing concepts and converting Riverpod state notifiers to BlocSignal.',
          ),
        ),
      ],
    ),
  ];

  /// Resolves a section by its ID or returns the default overview.
  static DocSectionItem resolveSection(String id) {
    for (final category in categories) {
      for (final section in category.sections) {
        if (section.id == id) return section;
      }
    }
    return categories.first.sections.first;
  }

  /// Resolves the next and previous section items for footer pagination.
  static (DocSectionItem? prev, DocSectionItem? next) getAdjacentSections(
    String currentId,
  ) {
    final allSections = [
      for (final cat in categories)
        for (final sec in cat.sections) sec,
    ];

    final index = allSections.indexWhere((s) => s.id == currentId);
    if (index == -1) return (null, null);

    final prev = index > 0 ? allSections[index - 1] : null;
    final next = index < allSections.length - 1 ? allSections[index + 1] : null;
    return (prev, next);
  }
}

class const _PlaceholderDoc({
  required final String title,
  required final String phase,
  required final String description,
}) extends StatelessComponent {
  @override
  Component build(BuildContext context) {
    return article(classes: 'docs-article', [
      header(classes: 'docs-article-header', [
        div(classes: 'docs-badge', [Component.text('⏳ In Progress ($phase)')]),
        h1([Component.text(title)]),
        p(classes: 'docs-lead', [Component.text(description)]),
      ]),
      section(classes: 'docs-section', [
        div(classes: 'docs-placeholder-card', [
          span(classes: 'placeholder-icon', [Component.text('🚧')]),
          h3([Component.text('Coming Soon in $phase')]),
          p([
            Component.text(
              'This documentation chapter is currently being drafted as part of $phase of the BlocSignal Documentation Hub rollout. '
              'In the meantime, refer to the Getting Started guides and the official README.',
            ),
          ]),
          div(classes: 'placeholder-actions', [
            a(href: '/docs/quickstart', classes: 'btn-primary-sm', [
              Component.text('Go to Quickstart Guide ➔'),
            ]),
          ]),
        ]),
      ]),
    ]);
  }
}
