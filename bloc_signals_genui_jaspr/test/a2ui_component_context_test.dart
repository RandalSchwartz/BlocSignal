import 'package:a2ui_core/a2ui_core.dart' show ReadonlySignal, Signal, signal;
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

    test(
        '(Issue #436) metadata getter exposes ComponentModel.metadata and '
        'triggerAction dispatches NodeAction, Map, and String payloads',
        () async {
      final comp = ComponentModel(
        'btn_1',
        'Button',
        const {
          'action': {
            'functionCall': {'call': 'openUrl', 'args': <String, Object?>{}},
          },
        },
        metadata: const {
          'extensions': {'role': 'cta', 'priority': 1},
        },
      );

      bloc.add(
        ProcessJsonMessage({
          'version': 'v0.9',
          'createSurface': {
            'surfaceId': 'surf_action',
            'catalogId': testCatalog.id,
          },
        }),
      );

      var nodeActionCalled = false;
      final actionsDispatched = <SurfaceSubmitting>[];
      final unsub = bloc.state.subscribe((state) {
        if (state is SurfaceSubmitting) {
          actionsDispatched.add(state);
        }
      });
      addTearDown(unsub);

      Future<void> nodeAction([ActionDispatchOptions? options]) async {
        nodeActionCalled = true;
      }

      final ctxFn = A2uiComponentContext(
        component: comp,
        props: {'action': nodeAction},
        surfaceBloc: bloc,
        surfaceId: 'surf_action',
        buildChildCallback: (_) => const div([]),
        buildChildrenCallback: (_) => const [],
      );
      expect(
        ctxFn.metadata,
        equals(const {
          'extensions': {'role': 'cta', 'priority': 1},
        }),
      );

      ctxFn.triggerAction();
      await Future<void>.microtask(() {});
      expect(nodeActionCalled, isTrue);
      // functionCall NodeAction should not also emit a duplicate SubmitAction.
      expect(actionsDispatched, isEmpty);

      // Legacy Map action
      A2uiComponentContext(
        component: ComponentModel('btn_2', 'Button', const {
          'action': {
            'event': {
              'name': 'saveForm',
              'context': {'id': 42},
            },
          },
        }),
        props: const {
          'action': {
            'event': {
              'name': 'saveForm',
              'context': {'id': 42},
            },
          },
        },
        surfaceBloc: bloc,
        surfaceId: 'surf_action',
        buildChildCallback: (_) => const div([]),
        buildChildrenCallback: (_) => const [],
      ).triggerAction();
      await Future<void>.microtask(() {});
      expect(actionsDispatched, hasLength(1));
      expect(actionsDispatched.first.actionName, equals('saveForm'));
      expect(
        actionsDispatched.first.payload['context'],
        equals({'id': 42}),
      );

      // String action
      A2uiComponentContext(
        component: ComponentModel('btn_3', 'Button', const {
          'action': 'ping',
        }),
        props: const {'action': 'ping'},
        surfaceBloc: bloc,
        surfaceId: 'surf_action',
        buildChildCallback: (_) => const div([]),
        buildChildrenCallback: (_) => const [],
      ).triggerAction();
      await Future<void>.microtask(() {});
      expect(actionsDispatched, hasLength(2));
      expect(actionsDispatched.last.actionName, equals('ping'));

      // NodeAction with event Map dispatches both NodeAction and SubmitAction.
      var eventNodeCalled = false;
      Future<void> eventNodeAction([ActionDispatchOptions? options]) async {
        eventNodeCalled = true;
      }

      A2uiComponentContext(
        component: ComponentModel('btn_node_ev', 'Button', const {
          'action': {
            'event': {'name': 'nodeEvent'},
          },
        }),
        props: {'action': eventNodeAction},
        surfaceBloc: bloc,
        surfaceId: 'surf_action',
        buildChildCallback: (_) => const div([]),
        buildChildrenCallback: (_) => const [],
      ).triggerAction();
      await Future<void>.microtask(() {});
      expect(eventNodeCalled, isTrue);
      expect(actionsDispatched, hasLength(3));
      expect(actionsDispatched.last.actionName, equals('nodeEvent'));
    });

    test('(Issue #436) buildWeightedChildren wraps weighted children',
        () async {
      bloc
        ..add(
          ProcessJsonMessage({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 'surf_weight',
              'catalogId': testCatalog.id,
            },
          }),
        )
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateComponents': {
              'surfaceId': 'surf_weight',
              'components': [
                {
                  'id': 'root',
                  'component': 'Row',
                  'children': ['c1', 'c2', 'c3'],
                },
                {'id': 'c1', 'component': 'Text', 'text': 'One', 'weight': 2},
                {'id': 'c2', 'component': 'Text', 'text': 'Two'},
                {
                  'id': 'c3',
                  'component': 'Text',
                  'text': 'Three',
                  'weight': -1,
                },
              ],
            },
          }),
        );
      await Future<void>.microtask(() {});

      final rowComp = ComponentModel('root', 'Row', const {
        'children': ['c1', 'c2', 'c3'],
      });
      final ctx = A2uiComponentContext(
        component: rowComp,
        props: const {
          'children': ['c1', 'c2', 'c3'],
        },
        surfaceBloc: bloc,
        surfaceId: 'surf_weight',
        buildChildCallback: (_) => const div([]),
        buildChildrenCallback: (ids) => ids.map(Component.text).toList(),
      );

      final weighted = ctx.buildWeightedChildren(const ['c1', 'c2', 'c3']);
      expect(weighted, hasLength(3));
      expect(weighted[0], isA<div>());
      expect(weighted[1], isNot(isA<div>()));
      expect(weighted[2], isNot(isA<div>()));

      // Node-based buildWeightedChildren with Map prop traversal.
      final childNode = _StubComponentNode(
        componentId: 'child_n',
        instanceId: 'child_n',
        initialProps: const {'text': 'Hi', 'weight': 2},
      );
      final rowNode = _StubComponentNode(
        componentId: 'row_n',
        instanceId: 'row_n',
        initialProps: {
          'nested': {'slot': childNode},
        },
      );
      final nodeCtx = A2uiComponentContext(
        component: rowComp,
        props: const {},
        node: rowNode,
        surfaceBloc: bloc,
        surfaceId: 'surf_weight',
        buildChildCallback: (_) => const div([]),
        buildChildrenCallback: (ids) => ids.map(Component.text).toList(),
      );
      final nodeWeighted = nodeCtx.buildWeightedChildren(const ['child_n']);
      expect(nodeWeighted.single, isA<div>());
    });
  });
}

class _StubComponentNode implements ComponentNode<ComponentApi> {
  _StubComponentNode({
    required this.componentId,
    required this.instanceId,
    required Map<String, Object?> initialProps,
  }) : _propsSignal = signal(initialProps);

  @override
  final String componentId;

  @override
  final String instanceId;

  final Signal<Map<String, Object?>> _propsSignal;

  @override
  ReadonlySignal<Map<String, Object?>> get props => _propsSignal;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
