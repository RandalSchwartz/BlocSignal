import 'package:blocsignal_website/src/cubits/docs_cubit.dart';
import 'package:test/test.dart';

void main() {
  group('DocsCubit', () {
    late DocsCubit cubit;

    setUp(() {
      cubit = DocsCubit(initialSectionId: 'overview');
    });

    tearDown(() async {
      await cubit.close();
    });

    test('initializes with default state values', () {
      expect(cubit.stateValue.activeSectionId, equals('overview'));
      expect(cubit.stateValue.searchQuery, isEmpty);
      expect(cubit.stateValue.isMobileDrawerOpen, isFalse);
      expect(cubit.stateValue.selectedDartVersion, equals('3.13'));
      expect(
        cubit.stateValue.expandedCategories,
        containsAll([
          'Getting Started',
          'Core Concepts',
          'Flutter Integration',
        ]),
      );
    });

    test(
      'selectSection updates activeSectionId and expands target category',
      () {
        cubit.selectSection('testing-guide', pushHistory: false);

        expect(cubit.stateValue.activeSectionId, equals('testing-guide'));
        expect(cubit.stateValue.expandedCategories, contains('Testing'));
        expect(cubit.stateValue.isMobileDrawerOpen, isFalse);
      },
    );

    test('selectSection ignores selecting the already active section', () {
      final initialState = cubit.stateValue;
      cubit.selectSection('overview', pushHistory: false);

      expect(cubit.stateValue, equals(initialState));
    });

    test('updateSearch updates searchQuery in state', () {
      cubit.updateSearch('hydrate');
      expect(cubit.stateValue.searchQuery, equals('hydrate'));

      cubit.updateSearch('');
      expect(cubit.stateValue.searchQuery, isEmpty);
    });

    test('toggleCategory adds and removes category expansion', () {
      expect(cubit.stateValue.expandedCategories, contains('Getting Started'));

      // Collapse
      cubit.toggleCategory('Getting Started');
      expect(
        cubit.stateValue.expandedCategories,
        isNot(contains('Getting Started')),
      );

      // Re-expand
      cubit.toggleCategory('Getting Started');
      expect(cubit.stateValue.expandedCategories, contains('Getting Started'));
    });

    test('toggleMobileDrawer and closeMobileDrawer manage drawer state', () {
      expect(cubit.stateValue.isMobileDrawerOpen, isFalse);

      cubit.toggleMobileDrawer();
      expect(cubit.stateValue.isMobileDrawerOpen, isTrue);

      cubit.closeMobileDrawer();
      expect(cubit.stateValue.isMobileDrawerOpen, isFalse);
    });

    test('setDartVersion updates code syntax preference', () {
      expect(cubit.stateValue.selectedDartVersion, equals('3.13'));

      cubit.setDartVersion('3.5');
      expect(cubit.stateValue.selectedDartVersion, equals('3.5'));

      // Setting same version does not emit duplicate
      cubit.setDartVersion('3.5');
      expect(cubit.stateValue.selectedDartVersion, equals('3.5'));
    });
  });
}
