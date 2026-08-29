import 'package:blocsignal_website/src/models/app_route.dart';
import 'package:blocsignal_website/src/models/docs_registry.dart';
import 'package:test/test.dart';

void main() {
  group('DocsRegistry', () {
    test('contains all expected documentation categories', () {
      final categories = DocsRegistry.categories;
      expect(categories, isNotEmpty);
      expect(
        categories.map((c) => c.title),
        containsAll([
          'Getting Started',
          'Core Concepts',
          'Flutter Integration',
          'Testing',
          'Satellite Packages',
          'Architecture & Recipes',
          'Migration Guides',
        ]),
      );
    });

    test('resolveSection returns matching section by id', () {
      final overview = DocsRegistry.resolveSection('overview');
      expect(overview.id, equals('overview'));
      expect(overview.title, equals('Overview & Why BlocSignal'));
      expect(overview.category, equals('Getting Started'));

      final installation = DocsRegistry.resolveSection('installation');
      expect(installation.id, equals('installation'));
      expect(installation.path, equals('/docs/installation'));

      final quickstart = DocsRegistry.resolveSection('quickstart');
      expect(quickstart.id, equals('quickstart'));
      expect(quickstart.path, equals('/docs/quickstart'));

      final decisionMatrix = DocsRegistry.resolveSection('decision-matrix');
      expect(decisionMatrix.id, equals('decision-matrix'));
      expect(decisionMatrix.path, equals('/docs/decision-matrix'));
      expect(decisionMatrix.category, equals('Getting Started'));

      final cubitVsBloc = DocsRegistry.resolveSection('cubit-vs-bloc');
      expect(cubitVsBloc.id, equals('cubit-vs-bloc'));
      expect(cubitVsBloc.category, equals('Core Concepts'));

      final stateModeling = DocsRegistry.resolveSection('state-modeling');
      expect(stateModeling.id, equals('state-modeling'));
      expect(stateModeling.category, equals('Core Concepts'));

      final events = DocsRegistry.resolveSection('events-and-handlers');
      expect(events.id, equals('events-and-handlers'));

      final transformers = DocsRegistry.resolveSection('event-transformers');
      expect(transformers.id, equals('event-transformers'));

      final lifecycle = DocsRegistry.resolveSection('lifecycle-and-observers');
      expect(lifecycle.id, equals('lifecycle-and-observers'));

      final reactivity = DocsRegistry.resolveSection('signals-reactivity');
      expect(reactivity.id, equals('signals-reactivity'));

      final flutterProviders = DocsRegistry.resolveSection('flutter-providers');
      expect(flutterProviders.id, equals('flutter-providers'));
      expect(flutterProviders.category, equals('Flutter Integration'));

      final flutterWidgets = DocsRegistry.resolveSection('flutter-widgets');
      expect(flutterWidgets.id, equals('flutter-widgets'));
      expect(flutterWidgets.category, equals('Flutter Integration'));

      final flutterContext = DocsRegistry.resolveSection('flutter-context');
      expect(flutterContext.id, equals('flutter-context'));
      expect(flutterContext.category, equals('Flutter Integration'));

      final testingGuide = DocsRegistry.resolveSection('testing-guide');
      expect(testingGuide.id, equals('testing-guide'));
      expect(testingGuide.category, equals('Testing'));

      final pkgHydrate = DocsRegistry.resolveSection('pkg-hydrate');
      expect(pkgHydrate.id, equals('pkg-hydrate'));
      expect(pkgHydrate.category, equals('Satellite Packages'));

      final pkgReplay = DocsRegistry.resolveSection('pkg-replay');
      expect(pkgReplay.id, equals('pkg-replay'));
      expect(pkgReplay.category, equals('Satellite Packages'));

      final pkgRiverpod = DocsRegistry.resolveSection('pkg-riverpod');
      expect(pkgRiverpod.id, equals('pkg-riverpod'));
      expect(pkgRiverpod.category, equals('Satellite Packages'));

      final pkgBloc = DocsRegistry.resolveSection('pkg-bloc');
      expect(pkgBloc.id, equals('pkg-bloc'));
      expect(pkgBloc.category, equals('Satellite Packages'));

      final pkgOtel = DocsRegistry.resolveSection('pkg-otel');
      expect(pkgOtel.id, equals('pkg-otel'));
      expect(pkgOtel.category, equals('Satellite Packages'));

      final pkgDevtools = DocsRegistry.resolveSection('pkg-devtools');
      expect(pkgDevtools.id, equals('pkg-devtools'));
      expect(pkgDevtools.category, equals('Satellite Packages'));

      final recipeOneShot = DocsRegistry.resolveSection('recipe-one-shot');
      expect(recipeOneShot.id, equals('recipe-one-shot'));
      expect(recipeOneShot.category, equals('Architecture & Recipes'));

      final recipeFormValidation = DocsRegistry.resolveSection(
        'recipe-form-validation',
      );
      expect(recipeFormValidation.id, equals('recipe-form-validation'));
      expect(recipeFormValidation.category, equals('Architecture & Recipes'));

      final recipeControllers = DocsRegistry.resolveSection(
        'recipe-controllers',
      );
      expect(recipeControllers.id, equals('recipe-controllers'));
      expect(recipeControllers.category, equals('Architecture & Recipes'));

      final recipeCaching = DocsRegistry.resolveSection('recipe-caching');
      expect(recipeCaching.id, equals('recipe-caching'));
      expect(recipeCaching.category, equals('Architecture & Recipes'));

      final migrationBloc = DocsRegistry.resolveSection('migration-bloc');
      expect(migrationBloc.id, equals('migration-bloc'));
      expect(migrationBloc.category, equals('Migration Guides'));

      final migrationRiverpod = DocsRegistry.resolveSection(
        'migration-riverpod',
      );
      expect(migrationRiverpod.id, equals('migration-riverpod'));
      expect(migrationRiverpod.category, equals('Migration Guides'));

      // Variations with trailing slashes, index.html, and full paths
      expect(
        DocsRegistry.resolveSection('installation/').id,
        equals('installation'),
      );
      expect(
        DocsRegistry.resolveSection('/docs/installation/').id,
        equals('installation'),
      );
      expect(
        DocsRegistry.resolveSection('/docs/quickstart/index.html').id,
        equals('quickstart'),
      );
      expect(
        DocsRegistry.resolveSection('/docs/cubit-vs-bloc').id,
        equals('cubit-vs-bloc'),
      );
      expect(
        DocsRegistry.resolveSection('/docs/pkg-hydrate').id,
        equals('pkg-hydrate'),
      );
      expect(
        DocsRegistry.resolveSection('/docs/pkg-bloc').id,
        equals('pkg-bloc'),
      );
      expect(
        DocsRegistry.resolveSection('/docs/migration-bloc').id,
        equals('migration-bloc'),
      );
    });

    test('resolveSection falls back to first section on unknown id', () {
      final fallback = DocsRegistry.resolveSection('unknown-section-123');
      expect(fallback.id, equals('overview'));
    });

    test('getAdjacentSections returns correct prev and next sections', () {
      // First section has no previous
      final (firstPrev, firstNext) = DocsRegistry.getAdjacentSections(
        'overview',
      );
      expect(firstPrev, isNull);
      expect(firstNext?.id, equals('installation'));

      // Middle section has both prev and next
      final (midPrev, midNext) = DocsRegistry.getAdjacentSections(
        'installation',
      );
      expect(midPrev?.id, equals('overview'));
      expect(midNext?.id, equals('quickstart'));

      // Unknown section returns (null, null)
      final (nonePrev, noneNext) = DocsRegistry.getAdjacentSections(
        'nonexistent',
      );
      expect(nonePrev, isNull);
      expect(noneNext, isNull);
    });

    test('all registered section builders instantiate valid components', () {
      for (final category in DocsRegistry.categories) {
        for (final section in category.sections) {
          final component = section.builder();
          expect(component, isNotNull, reason: 'Failed building ${section.id}');
        }
      }
    });
  });

  group('AppRoute & Location Parsing', () {
    test('fromLocation resolves /docs and sub-paths to AppRoute.docs', () {
      expect(AppRoute.fromLocation(path: '/docs'), equals(AppRoute.docs));
      expect(
        AppRoute.fromLocation(path: '/docs/overview'),
        equals(AppRoute.docs),
      );
      expect(
        AppRoute.fromLocation(path: '/docs/installation'),
        equals(AppRoute.docs),
      );
      expect(
        AppRoute.fromLocation(path: '/docs/quickstart'),
        equals(AppRoute.docs),
      );
      expect(
        AppRoute.fromLocation(hash: '#docs/quickstart'),
        equals(AppRoute.docs),
      );
    });

    test('fromLocation resolves other routes correctly', () {
      expect(AppRoute.fromLocation(path: '/'), equals(AppRoute.home));
      expect(
        AppRoute.fromLocation(path: '/showcase'),
        equals(AppRoute.showcase),
      );
      expect(
        AppRoute.fromLocation(path: '/ported-examples'),
        equals(AppRoute.portedExamples),
      );
      expect(
        AppRoute.fromLocation(path: '/minesweeper'),
        equals(AppRoute.minesweeper),
      );
      expect(
        AppRoute.fromLocation(path: '/publications'),
        equals(AppRoute.publications),
      );
    });
  });
}
