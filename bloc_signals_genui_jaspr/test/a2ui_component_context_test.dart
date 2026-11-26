import 'dart:async';

import 'package:a2ui_core/a2ui_core.dart' show ReadonlySignal, Signal, signal;
import 'package:bloc_signals/bloc_signals.dart';
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

  group('(Issue #514) A2uiComponentContext NodeAction telemetry bridge', () {
    late A2uiSurfaceBloc bloc;
    final testCatalog = MinimalCatalog();

    setUp(() {
      bloc = A2uiSurfaceBloc(catalogs: [testCatalog]);
    });

    tearDown(() async {
      await bloc.close();
    });

    test(
        'NodeAction with functionCall (call and @call) emits '
        'function_call_evaluated with status ok and omits args', () async {
      final previousObserver = BlocSignalObserver.observer;
      final observer = _TelemetryRecordingObserver();
      BlocSignalObserver.observer = observer;
      addTearDown(() => BlocSignalObserver.observer = previousObserver);

      bloc.add(
        ProcessJsonMessage({
          'version': 'v0.9',
          'createSurface': {
            'surfaceId': 'surf_fc',
            'catalogId': testCatalog.id,
          },
        }),
      );

      final actionsDispatched = <SurfaceSubmitting>[];
      final unsub = bloc.state.subscribe((state) {
        if (state is SurfaceSubmitting) {
          actionsDispatched.add(state);
        }
      });
      addTearDown(unsub);

      Future<void> nodeAction([ActionDispatchOptions? options]) async {}

      A2uiComponentContext(
        component: ComponentModel('btn_v09', 'Button', const {
          'action': {
            'functionCall': {
              'call': 'openUrl',
              'args': {'secret': 'token-123'},
            },
          },
        }),
        props: {'action': nodeAction},
        surfaceBloc: bloc,
        surfaceId: 'surf_fc',
        buildChildCallback: (_) => const div([]),
        buildChildrenCallback: (_) => const [],
      ).triggerAction();

      A2uiComponentContext(
        component: ComponentModel('btn_v10', 'Button', const {
          'action': {
            'functionCall': {
              '@call': 'saveDraft',
              'args': {'secret': 'token-456'},
            },
          },
        }),
        props: {'action': nodeAction},
        surfaceBloc: bloc,
        surfaceId: 'surf_fc',
        buildChildCallback: (_) => const div([]),
        buildChildrenCallback: (_) => const [],
      ).triggerAction();

      await Future<void>.microtask(() {});
      expect(actionsDispatched, isEmpty);

      final events = observer.telemetry
          .where((e) => e.name == 'function_call_evaluated')
          .toList();
      expect(events, hasLength(2));
      expect(events[0].metadata?['surface_id'], equals('surf_fc'));
      expect(events[0].metadata?['source_component_id'], equals('btn_v09'));
      expect(events[0].metadata?['call'], equals('openUrl'));
      expect(events[0].metadata?['status'], equals('ok'));
      expect(events[0].metadata?['latency_ms'], greaterThanOrEqualTo(0));
      expect(events[0].metadata?.containsKey('args'), isFalse);

      expect(events[1].metadata?['source_component_id'], equals('btn_v10'));
      expect(events[1].metadata?['call'], equals('saveDraft'));
      expect(events[1].metadata?['status'], equals('ok'));
      expect(events[1].metadata?.containsKey('args'), isFalse);
    });

    test(
        'NodeAction with top-level @call or call is recognized as functionCall '
        'without dispatching SubmitAction', () async {
      final previousObserver = BlocSignalObserver.observer;
      final observer = _TelemetryRecordingObserver();
      BlocSignalObserver.observer = observer;
      addTearDown(() => BlocSignalObserver.observer = previousObserver);

      bloc.add(
        ProcessJsonMessage({
          'version': 'v0.9',
          'createSurface': {
            'surfaceId': 'surf_top',
            'catalogId': testCatalog.id,
          },
        }),
      );

      final actionsDispatched = <SurfaceSubmitting>[];
      final unsub = bloc.state.subscribe((state) {
        if (state is SurfaceSubmitting) {
          actionsDispatched.add(state);
        }
      });
      addTearDown(unsub);

      Future<void> nodeAction([ActionDispatchOptions? options]) async {}

      A2uiComponentContext(
        component: ComponentModel('btn_at_call', 'Button', const {
          'action': {'@call': 'v1TopCall'},
        }),
        props: {'action': nodeAction},
        surfaceBloc: bloc,
        surfaceId: 'surf_top',
        buildChildCallback: (_) => const div([]),
        buildChildrenCallback: (_) => const [],
      ).triggerAction();

      A2uiComponentContext(
        component: ComponentModel('btn_call', 'Button', const {
          'action': {'call': 'v09TopCall'},
        }),
        props: {'action': nodeAction},
        surfaceBloc: bloc,
        surfaceId: 'surf_top',
        buildChildCallback: (_) => const div([]),
        buildChildrenCallback: (_) => const [],
      ).triggerAction();

      await Future<void>.microtask(() {});
      expect(actionsDispatched, isEmpty);

      final events = observer.telemetry
          .where((e) => e.name == 'function_call_evaluated')
          .toList();
      expect(events, hasLength(2));
      expect(events[0].metadata?['call'], equals('v1TopCall'));
      expect(events[1].metadata?['call'], equals('v09TopCall'));
    });

    test(
        'NodeAction async and sync Exception throws emit status error, omit '
        'raw message, and swallow Exception', () async {
      final previousObserver = BlocSignalObserver.observer;
      final observer = _TelemetryRecordingObserver();
      BlocSignalObserver.observer = observer;
      addTearDown(() => BlocSignalObserver.observer = previousObserver);

      Future<void> asyncFail([ActionDispatchOptions? options]) async {
        throw const FormatException('sensitive-async-msg');
      }

      Future<void> syncFail([ActionDispatchOptions? options]) {
        throw const FormatException('sensitive-sync-msg');
      }

      A2uiComponentContext(
        component: ComponentModel('btn_async_ex', 'Button', const {
          'action': {
            'functionCall': {'call': 'asyncOp'},
          },
        }),
        props: {'action': asyncFail},
        surfaceBloc: bloc,
        surfaceId: 'surf_ex',
        buildChildCallback: (_) => const div([]),
        buildChildrenCallback: (_) => const [],
      ).triggerAction();

      A2uiComponentContext(
        component: ComponentModel('btn_sync_ex', 'Button', const {
          'action': {
            'functionCall': {'call': 'syncOp'},
          },
        }),
        props: {'action': syncFail},
        surfaceBloc: bloc,
        surfaceId: 'surf_ex',
        buildChildCallback: (_) => const div([]),
        buildChildrenCallback: (_) => const [],
      ).triggerAction();

      await Future<void>.microtask(() {});

      final events = observer.telemetry
          .where((e) => e.name == 'function_call_evaluated')
          .toList();
      expect(events, hasLength(2));
      for (final event in events) {
        expect(event.metadata?['status'], equals('error'));
        expect(event.metadata?['error_type'], equals('FormatException'));
        expect(
          event.metadata.toString(),
          isNot(contains('sensitive')),
        );
      }
    });

    test(
        'NodeAction sync throw and async non-Exception Error emit status error '
        'and propagate Error', () async {
      final previousObserver = BlocSignalObserver.observer;
      final observer = _TelemetryRecordingObserver();
      BlocSignalObserver.observer = observer;
      addTearDown(() => BlocSignalObserver.observer = previousObserver);

      Future<void> syncError([ActionDispatchOptions? options]) {
        throw StateError('sync-fatal');
      }

      Future<void> asyncError([ActionDispatchOptions? options]) async {
        throw StateError('async-fatal');
      }

      expect(
        () => A2uiComponentContext(
          component: ComponentModel('btn_sync_err', 'Button', const {
            'action': {
              'functionCall': {'call': 'syncErrOp'},
            },
          }),
          props: {'action': syncError},
          surfaceBloc: bloc,
          surfaceId: 'surf_err',
          buildChildCallback: (_) => const div([]),
          buildChildrenCallback: (_) => const [],
        ).triggerAction(),
        throwsStateError,
      );

      final uncaught = <Object>[];
      final done = Completer<void>();
      runZonedGuarded(
        () {
          A2uiComponentContext(
            component: ComponentModel('btn_async_err', 'Button', const {
              'action': {
                'functionCall': {'call': 'asyncErrOp'},
              },
            }),
            props: {'action': asyncError},
            surfaceBloc: bloc,
            surfaceId: 'surf_err',
            buildChildCallback: (_) => const div([]),
            buildChildrenCallback: (_) => const [],
          ).triggerAction();
        },
        (error, _) {
          uncaught.add(error);
          if (!done.isCompleted) done.complete();
        },
      );
      await done.future;

      expect(uncaught, hasLength(1));
      expect(uncaught.single, isA<StateError>());

      final events = observer.telemetry
          .where((e) => e.name == 'function_call_evaluated')
          .toList();
      expect(events, hasLength(2));
      expect(events[0].metadata?['status'], equals('error'));
      expect(events[0].metadata?['error_type'], equals('StateError'));
      expect(events[1].metadata?['status'], equals('error'));
      expect(events[1].metadata?['error_type'], equals('StateError'));
    });

    test(
        'NodeAction on closed A2uiSurfaceBloc does not throw or emit telemetry',
        () async {
      final previousObserver = BlocSignalObserver.observer;
      final observer = _TelemetryRecordingObserver();
      BlocSignalObserver.observer = observer;
      addTearDown(() => BlocSignalObserver.observer = previousObserver);

      await bloc.close();

      Future<void> nodeAction([ActionDispatchOptions? options]) async {}

      A2uiComponentContext(
        component: ComponentModel('btn_closed', 'Button', const {
          'action': {
            'functionCall': {'call': 'closedOp'},
          },
        }),
        props: {'action': nodeAction},
        surfaceBloc: bloc,
        surfaceId: 'surf_closed',
        buildChildCallback: (_) => const div([]),
        buildChildrenCallback: (_) => const [],
      ).triggerAction();

      await Future<void>.microtask(() {});
      expect(
        observer.telemetry.where((e) => e.name == 'function_call_evaluated'),
        isEmpty,
      );
    });

    test(
        'onTelemetry Exception is isolated to onError without aborting '
        'NodeAction completion', () async {
      final previousObserver = BlocSignalObserver.observer;
      final observer = _TelemetryRecordingObserver(
        onTelemetryException: const FormatException('observer-boom'),
      );
      BlocSignalObserver.observer = observer;
      addTearDown(() => BlocSignalObserver.observer = previousObserver);

      var actionCompleted = false;
      Future<void> nodeAction([ActionDispatchOptions? options]) async {
        actionCompleted = true;
      }

      A2uiComponentContext(
        component: ComponentModel('btn_obs_err', 'Button', const {
          'action': {
            'functionCall': {'call': 'openUrl'},
          },
        }),
        props: {'action': nodeAction},
        surfaceBloc: bloc,
        surfaceId: 'surf_obs_err',
        buildChildCallback: (_) => const div([]),
        buildChildrenCallback: (_) => const [],
      ).triggerAction();

      await Future<void>.microtask(() {});
      expect(actionCompleted, isTrue);
      expect(
        observer.telemetry.where((e) => e.name == 'function_call_evaluated'),
        hasLength(1),
      );
      expect(observer.errors, hasLength(1));
      expect(observer.errors.single, isA<FormatException>());
    });

    test(
        'mid-flight bloc close before async NodeAction Exception or Error '
        'rejection suppresses telemetry while preserving Exception swallow and '
        'Error propagation', () async {
      final previousObserver = BlocSignalObserver.observer;
      final observer = _TelemetryRecordingObserver();
      BlocSignalObserver.observer = observer;
      addTearDown(() => BlocSignalObserver.observer = previousObserver);

      final exCompleter = Completer<void>();
      Future<void> lateEx([ActionDispatchOptions? options]) =>
          exCompleter.future;
      A2uiComponentContext(
        component: ComponentModel('btn_mid_ex', 'Button', const {
          'action': {
            'functionCall': {'call': 'midEx'},
          },
        }),
        props: {'action': lateEx},
        surfaceBloc: bloc,
        surfaceId: 'surf_mid',
        buildChildCallback: (_) => const div([]),
        buildChildrenCallback: (_) => const [],
      ).triggerAction();

      late Completer<void> errCompleter;
      final uncaught = <Object>[];
      final errDone = Completer<void>();
      runZonedGuarded(
        () {
          errCompleter = Completer<void>();
          Future<void> lateErr([ActionDispatchOptions? options]) =>
              errCompleter.future;
          A2uiComponentContext(
            component: ComponentModel('btn_mid_err', 'Button', const {
              'action': {
                'functionCall': {'call': 'midErr'},
              },
            }),
            props: {'action': lateErr},
            surfaceBloc: bloc,
            surfaceId: 'surf_mid',
            buildChildCallback: (_) => const div([]),
            buildChildrenCallback: (_) => const [],
          ).triggerAction();
        },
        (error, _) {
          uncaught.add(error);
          if (!errDone.isCompleted) errDone.complete();
        },
      );

      await bloc.close();
      exCompleter.completeError(const FormatException('late-ex'));
      errCompleter.completeError(StateError('late-err'));
      await errDone.future;
      await Future<void>.microtask(() {});

      expect(uncaught, hasLength(1));
      expect(uncaught.single, isA<StateError>());
      expect(
        observer.telemetry.where((e) => e.name == 'function_call_evaluated'),
        isEmpty,
      );
    });

    test(
        'Non-functionCall NodeAction dispatches SubmitAction without emitting '
        'function_call_evaluated', () async {
      final previousObserver = BlocSignalObserver.observer;
      final observer = _TelemetryRecordingObserver();
      BlocSignalObserver.observer = observer;
      addTearDown(() => BlocSignalObserver.observer = previousObserver);

      bloc.add(
        ProcessJsonMessage({
          'version': 'v0.9',
          'createSurface': {
            'surfaceId': 'surf_ev',
            'catalogId': testCatalog.id,
          },
        }),
      );

      final actionsDispatched = <SurfaceSubmitting>[];
      final unsub = bloc.state.subscribe((state) {
        if (state is SurfaceSubmitting) {
          actionsDispatched.add(state);
        }
      });
      addTearDown(unsub);

      var called = false;
      Future<void> eventAction([ActionDispatchOptions? options]) async {
        called = true;
      }

      A2uiComponentContext(
        component: ComponentModel('btn_ev', 'Button', const {
          'action': {
            'event': {'name': 'submitForm'},
          },
        }),
        props: {'action': eventAction},
        surfaceBloc: bloc,
        surfaceId: 'surf_ev',
        buildChildCallback: (_) => const div([]),
        buildChildrenCallback: (_) => const [],
      ).triggerAction();

      await Future<void>.microtask(() {});
      expect(called, isTrue);
      expect(actionsDispatched, hasLength(1));
      expect(actionsDispatched.single.actionName, equals('submitForm'));
      expect(
        observer.telemetry.where((e) => e.name == 'function_call_evaluated'),
        isEmpty,
      );
    });
  });
}

class _TelemetryRecord {
  const _TelemetryRecord({
    required this.name,
    this.metadata,
  });

  final String name;
  final Map<String, dynamic>? metadata;
}

class _TelemetryRecordingObserver extends BlocSignalObserver {
  _TelemetryRecordingObserver({this.onTelemetryException});

  final Exception? onTelemetryException;
  final List<_TelemetryRecord> telemetry = <_TelemetryRecord>[];
  final List<Object> errors = <Object>[];

  @override
  void onTelemetry(
    BlocSignalBase<dynamic> bloc,
    String name, {
    Object? event,
    Map<String, dynamic>? metadata,
  }) {
    super.onTelemetry(bloc, name, event: event, metadata: metadata);
    telemetry.add(_TelemetryRecord(name: name, metadata: metadata));
    if (onTelemetryException != null) {
      throw onTelemetryException!;
    }
  }

  @override
  void onError(
    BlocSignalBase<dynamic> bloc,
    Object error,
    StackTrace stackTrace,
  ) {
    super.onError(bloc, error, stackTrace);
    errors.add(error);
  }
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
