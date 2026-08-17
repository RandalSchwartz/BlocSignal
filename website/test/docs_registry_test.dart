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
