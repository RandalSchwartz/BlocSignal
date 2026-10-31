import 'package:bloc_signals_genui/bloc_signals_genui.dart';
import 'package:bloc_signals_genui_jaspr/bloc_signals_genui_jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:test/test.dart';

void main() {
  group('A2uiComponentContext tests', () {
    late A2uiSurfaceBloc bloc;
    final testCatalog = MinimalCatalog();

    setUp(() {
      bloc = A2uiSurfaceBloc(catalogs: [testCatalog]);
    });

    tearDown(() async {
      await bloc.close();
    });

    test('isValid reflects props and validationErrors', () {
      final comp = ComponentModel('comp_1', 'Text', const {});

      final ctx1 = A2uiComponentContext(
        component: comp,
        props: const {'isValid': false},
        surfaceBloc: bloc,
        surfaceId: 'surf_1',
        buildChildCallback: (_) => const div([]),
        buildChildrenCallback: (_) => const [],
      );
      expect(ctx1.isValid, isFalse);

      final ctx2 = A2uiComponentContext(
        component: comp,
        props: const {
          'validationErrors': ['Error 1'],
        },
        surfaceBloc: bloc,
        surfaceId: 'surf_1',
        buildChildCallback: (_) => const div([]),
        buildChildrenCallback: (_) => const [],
      );
      expect(ctx2.isValid, isFalse);
      expect(ctx2.validationErrors, equals(['Error 1']));

      final ctx3 = A2uiComponentContext(
        component: comp,
        props: const {},
        surfaceBloc: bloc,
        surfaceId: 'surf_1',
        buildChildCallback: (_) => const div([]),
        buildChildrenCallback: (_) => const [],
      );
      expect(ctx3.isValid, isTrue);
      expect(ctx3.validationErrors, isEmpty);
      expect(ctx3.validationResults, isEmpty);
    });

    test('validationResults extracts ValidationResult instances', () {
      final comp = ComponentModel('comp_1', 'TextField', const {});

      const resultObj = ValidationResult(
        valid: false,
        message: 'Must be filled',
      );

      final ctx = A2uiComponentContext(
        component: comp,
        props: const {
          'validationResults': [resultObj, 'not_a_result'],
        },
        surfaceBloc: bloc,
        surfaceId: 'surf_1',
        buildChildCallback: (_) => const div([]),
        buildChildrenCallback: (_) => const [],
      );

      expect(ctx.validationResults, equals([resultObj]));
    });

    test(
        'resolveBoundPath handles WritableBinding, Map paths, fallback, '
        'and scoping', () {
      final compWithProp = ComponentModel(
        'comp_with_path',
        'TextField',
        const {
          'boundProp': {'path': '/explicit/path'},
          'atPathProp': {'@path': '/at/path'},
        },
      );

      final ctx = A2uiComponentContext(
        component: compWithProp,
        props: const {},
        rawProps: {
          'writableProp': WritableBinding<Object?>(
            'val',
            (_) {},
            '/from/writable',
          ),
        },
        surfaceBloc: bloc,
        surfaceId: 'surf_1',
        buildChildCallback: (_) => const div([]),
        buildChildrenCallback: (_) => const [],
      );

      expect(ctx.resolveBoundPath('writableProp'), equals('/from/writable'));
      expect(ctx.resolveBoundPath('boundProp'), equals('/explicit/path'));
      expect(ctx.resolveBoundPath('atPathProp'), equals('/at/path'));
      expect(
        ctx.resolveBoundPath('missing', fallbackPath: '/fallback'),
        equals('/fallback'),
      );
      expect(ctx.resolveBoundPath('missing'), equals('/comp_with_path'));

      // Scoped relative paths
      final scopedCtx = A2uiComponentContext(
        component: compWithProp,
        props: const {},
        surfaceBloc: bloc,
        surfaceId: 'surf_1',
        dataPath: '/items/0',
        buildChildCallback: (_) => const div([]),
        buildChildrenCallback: (_) => const [],
      );

      expect(
        scopedCtx.resolveBoundPath('missing', fallbackPath: 'relative_field'),
        equals('/items/0/relative_field'),
      );
      expect(
        scopedCtx.resolveBoundPath('missing'),
        equals('/items/0/comp_with_path'),
      );
    });

    test('buildChild and buildChildren invoke callbacks correctly', () {
      final comp = ComponentModel('c1', 'Card', const {});

      var childInvoked = '';
      final childrenInvoked = <String>[];

      A2uiComponentContext(
        component: comp,
        props: const {},
        surfaceBloc: bloc,
        surfaceId: 'surf_1',
        buildChildCallback: (id) {
          childInvoked = id;
          return Component.text(id);
        },
        buildChildrenCallback: (ids) {
          childrenInvoked.addAll(ids);
          return ids.map(Component.text).toList();
        },
      )
        ..buildChild('child_1')
        ..buildChildren(const ['c_1', 'c_2']);
      expect(childInvoked, equals('child_1'));
      expect(childrenInvoked, equals(['c_1', 'c_2']));
    });

    test('actions, form fields, and surface events dispatch to bloc', () {
      final comp = ComponentModel('c1', 'Button', const {});

      // Initialize surface in bloc
      bloc.add(
        ProcessJsonMessage({
          'version': 'v0.9',
          'createSurface': {
            'surfaceId': 'surf_test',
            'catalogId': testCatalog.id,
          },
        }),
      );

      A2uiComponentContext(
        component: comp,
        props: const {},
        surfaceBloc: bloc,
        surfaceId: 'surf_test',
        buildChildCallback: (_) => const div([]),
        buildChildrenCallback: (_) => const [],
      )
        ..updateBoundValue('value', 'new_val')
        ..dispatchAction('clickAction', context: const {'key': 'val'})
        ..cancelSubmission(error: 'aborted')
        ..completeAction(error: 'failed')
        ..selectSurface('other_surf')
        ..closeSurface()
        ..closeSurface('target_surf');

      expect(bloc.state.value, isA<A2uiSurfaceState>());
    });

    test('resolveBoundPath handles relative paths and root fallback', () {
      final comp = ComponentModel('c1', 'TextField', const {
        'value': {'path': 'relativeField'},
      });
      final ctx1 = A2uiComponentContext(
        component: comp,
        props: const {
          'value': {'path': 'relativeField'},
        },
        dataPath: '/rootData',
        surfaceBloc: bloc,
        surfaceId: 'surf_1',
        buildChildCallback: (_) => const div([]),
        buildChildrenCallback: (_) => const [],
      );
      expect(ctx1.resolveBoundPath('value'), equals('/rootData/relativeField'));

      final ctx2 = A2uiComponentContext(
        component: comp,
        props: const {
          'value': {'path': 'relativeField'},
        },
        surfaceBloc: bloc,
        surfaceId: 'surf_1',
        buildChildCallback: (_) => const div([]),
        buildChildrenCallback: (_) => const [],
      );
      expect(ctx2.resolveBoundPath('value'), equals('/relativeField'));
    });
  });
}
