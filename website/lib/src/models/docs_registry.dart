import '../components/docs/pages/docs_cubit_vs_bloc.dart';
import '../components/docs/pages/docs_event_transformers.dart';
import '../components/docs/pages/docs_events_and_handlers.dart';
import '../components/docs/pages/docs_flutter_context.dart';
import '../components/docs/pages/docs_flutter_providers.dart';
import '../components/docs/pages/docs_flutter_widgets.dart';
import '../components/docs/pages/docs_installation.dart';
import '../components/docs/pages/docs_lifecycle_and_observers.dart';
import '../components/docs/pages/docs_migration_bloc.dart';
import '../components/docs/pages/docs_migration_riverpod.dart';
import '../components/docs/pages/docs_overview.dart';
import '../components/docs/pages/docs_pkg_devtools.dart';
import '../components/docs/pages/docs_pkg_hydrate.dart';
import '../components/docs/pages/docs_pkg_otel.dart';
import '../components/docs/pages/docs_pkg_replay.dart';
import '../components/docs/pages/docs_pkg_riverpod.dart';
import '../components/docs/pages/docs_quickstart.dart';
import '../components/docs/pages/docs_recipe_caching.dart';
import '../components/docs/pages/docs_recipe_controllers.dart';
import '../components/docs/pages/docs_recipe_form_validation.dart';
import '../components/docs/pages/docs_recipe_one_shot.dart';
import '../components/docs/pages/docs_signals_reactivity.dart';
import '../components/docs/pages/docs_state_modeling.dart';
import '../components/docs/pages/docs_testing_guide.dart';
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
    const DocCategory(
      title: 'Core Concepts',
      icon: '🧠',
      sections: [
        DocSectionItem(
          id: 'cubit-vs-bloc',
          title: 'CubitSignal vs. BlocSignal',
          path: '/docs/cubit-vs-bloc',
          category: 'Core Concepts',
          description: 'Choosing between direct method invocation and event-driven architectures.',
          builder: DocsCubitVsBlocPage.new,
        ),
        DocSectionItem(
          id: 'state-modeling',
          title: 'State Modeling & Immutability',
          path: '/docs/state-modeling',
          category: 'Core Concepts',
          description: 'Immutable data models, Dart Records, Fast Immutable Collections (FIC), and custom equality comparators.',
          builder: DocsStateModelingPage.new,
        ),
        DocSectionItem(
          id: 'events-and-handlers',
          title: 'Events & Handlers',
          path: '/docs/events-and-handlers',
          category: 'Core Concepts',
          description: 'Registering typed event handlers with on<E>(), concurrency coordination, and error tracking.',
          builder: DocsEventsAndHandlersPage.new,
        ),
        DocSectionItem(
          id: 'event-transformers',
          title: 'Event Transformers & Concurrency',
          path: '/docs/event-transformers',
          category: 'Core Concepts',
          description: 'droppable(), sequential(), restartable(), and custom streamless event Transformers.',
          builder: DocsEventTransformersPage.new,
        ),
        DocSectionItem(
          id: 'lifecycle-and-observers',
          title: 'Lifecycle & Observers',
          path: '/docs/lifecycle-and-observers',
          category: 'Core Concepts',
          description: 'State container lifecycles, isClosed guarantees, and global observability with BlocSignalObserver.',
          builder: DocsLifecycleAndObserversPage.new,
        ),
        DocSectionItem(
          id: 'signals-reactivity',
          title: 'Signals Graph Reactivity',
          path: '/docs/signals-reactivity',
          category: 'Core Concepts',
          description: 'Preact signals v7 integration, 0ms synchronous propagation, computed signals, and effects.',
          builder: DocsSignalsReactivityPage.new,
        ),
      ],
    ),
    const DocCategory(
      title: 'Flutter Integration',
      icon: '💙',
      sections: [
        DocSectionItem(
          id: 'flutter-providers',
          title: 'Providers & Dependency Injection',
          path: '/docs/flutter-providers',
          category: 'Flutter Integration',
          description: 'BlocSignalProvider scoping, lazy loading, and O(1) InheritedElement resolution.',
          builder: DocsFlutterProvidersPage.new,
        ),
        DocSectionItem(
          id: 'flutter-widgets',
          title: 'Builders, Listeners & Selectors',
          path: '/docs/flutter-widgets',
          category: 'Flutter Integration',
          description: 'BlocSignalBuilder, BlocSignalListener, BlocSignalConsumer, and fine-grained BlocSignalSelector.',
          builder: DocsFlutterWidgetsPage.new,
        ),
        DocSectionItem(
          id: 'flutter-context',
          title: 'Context Extensions',
          path: '/docs/flutter-context',
          category: 'Flutter Integration',
          description: 'context.read<T>(), context.watch<T>(), and two-type-parameter context.select<B, R>().',
          builder: DocsFlutterContextPage.new,
        ),
      ],
    ),
    const DocCategory(
      title: 'Testing',
      icon: '🧪',
      sections: [
        DocSectionItem(
          id: 'testing-guide',
          title: 'Declarative Testing with blocSignalTest',
          path: '/docs/testing-guide',
          category: 'Testing',
          description: 'Declarative unit testing, observer scoping, lifecycle verification, and async frame expectations.',
          builder: DocsTestingGuidePage.new,
        ),
      ],
    ),
    const DocCategory(
      title: 'Satellite Packages',
      icon: '📦',
      sections: [
        DocSectionItem(
          id: 'pkg-hydrate',
          title: 'bloc_signals_hydrate',
          path: '/docs/pkg-hydrate',
          category: 'Satellite Packages',
          description: 'Synchronous frame 1 state persistence across restarts.',
          builder: DocsPkgHydratePage.new,
        ),
        DocSectionItem(
          id: 'pkg-replay',
          title: 'bloc_signals_replay',
          path: '/docs/pkg-replay',
          category: 'Satellite Packages',
          description: 'Undo and redo history management with ReplayCubit and ReplayBloc.',
          builder: DocsPkgReplayPage.new,
        ),
        DocSectionItem(
          id: 'pkg-riverpod',
          title: 'bloc_signals_riverpod',
          path: '/docs/pkg-riverpod',
          category: 'Satellite Packages',
          description:
              'Bidirectional Riverpod 2 & 3 interoperability adapters.',
          builder: DocsPkgRiverpodPage.new,
        ),
        DocSectionItem(
          id: 'pkg-otel',
          title: 'bloc_signals_otel',
          path: '/docs/pkg-otel',
          category: 'Satellite Packages',
          description:
              'OpenTelemetry distributed tracing and observability spans.',
          builder: DocsPkgOtelPage.new,
        ),
        DocSectionItem(
          id: 'pkg-devtools',
          title: 'bloc_signals_devtools',
          path: '/docs/pkg-devtools',
          category: 'Satellite Packages',
          description: 'DevTools timeline inspection and leak detector badge.',
          builder: DocsPkgDevtoolsPage.new,
        ),
      ],
    ),
    const DocCategory(
      title: 'Architecture & Recipes',
      icon: '💡',
      sections: [
        DocSectionItem(
          id: 'recipe-one-shot',
          title: 'One-Shot UI Side Effects',
          path: '/docs/recipe-one-shot',
          category: 'Architecture & Recipes',
          description: 'Handling snackbars, dialogs, and navigation without polluting domain state.',
          builder: DocsRecipeOneShotPage.new,
        ),
        DocSectionItem(
          id: 'recipe-form-validation',
          title: 'Form Validation',
          path: '/docs/recipe-form-validation',
          category: 'Architecture & Recipes',
          description: 'Primary input signals paired with computed() derived validation states.',
          builder: DocsRecipeFormValidationPage.new,
        ),
        DocSectionItem(
          id: 'recipe-controllers',
          title: 'Coordinating Controllers',
          path: '/docs/recipe-controllers',
          category: 'Architecture & Recipes',
          description: 'Bidirectional syncing of TextEditingControllers without build-phase mutation loops.',
          builder: DocsRecipeControllersPage.new,
        ),
        DocSectionItem(
          id: 'recipe-caching',
          title: 'API Caching & TTL Expiration',
          path: '/docs/recipe-caching',
          category: 'Architecture & Recipes',
          description: 'Managing asynchronous server data with automatic cache invalidation.',
          builder: DocsRecipeCachingPage.new,
        ),
      ],
    ),
    const DocCategory(
      title: 'Migration Guides',
      icon: '🔄',
      sections: [
        DocSectionItem(
          id: 'migration-bloc',
          title: 'Migrating from package:bloc',
          path: '/docs/migration-bloc',
          category: 'Migration Guides',
          description: 'Step-by-step migration guide from classic BLoC / flutter_bloc to BlocSignal.',
          builder: DocsMigrationBlocPage.new,
        ),
        DocSectionItem(
          id: 'migration-riverpod',
          title: 'Migrating from Riverpod',
          path: '/docs/migration-riverpod',
          category: 'Migration Guides',
          description: 'Step-by-step migration guide from Riverpod providers to BlocSignal.',
          builder: DocsMigrationRiverpodPage.new,
        ),
      ],
    ),
  ];

  /// Resolves a section by its ID or returns the default overview.
  static DocSectionItem resolveSection(String id) {
    var cleanId = id.trim();
    if (cleanId.startsWith('/')) cleanId = cleanId.substring(1);
    if (cleanId.endsWith('/'))
      cleanId = cleanId.substring(0, cleanId.length - 1);
    if (cleanId.endsWith('/index.html')) {
      cleanId = cleanId.substring(0, cleanId.length - '/index.html'.length);
    } else if (cleanId.endsWith('index.html')) {
      cleanId = cleanId.substring(0, cleanId.length - 'index.html'.length);
    }
    if (cleanId.startsWith('docs/')) {
      cleanId = cleanId.substring('docs/'.length);
    }

    for (final category in categories) {
      for (final section in category.sections) {
        if (section.id == id ||
            section.id == cleanId ||
            section.path == id ||
            section.path == '/$id' ||
            section.path == '/docs/$cleanId' ||
            section.path == '/$cleanId') {
          return section;
        }
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
