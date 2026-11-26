import 'dart:async';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_genui/bloc_signals_genui.dart';
import 'package:bloc_signals_genui_flutter/bloc_signals_genui_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
        buildChildCallback: (_) => const SizedBox.shrink(),
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
        buildChildCallback: (_) => const SizedBox.shrink(),
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
        buildChildCallback: (_) => const SizedBox.shrink(),
        buildChildrenCallback: (_) => const [],
      ).triggerAction();

      A2uiComponentContext(
        component: ComponentModel('btn_call', 'Button', const {
          'action': {'call': 'v09TopCall'},
        }),
        props: {'action': nodeAction},
        surfaceBloc: bloc,
        surfaceId: 'surf_top',
        buildChildCallback: (_) => const SizedBox.shrink(),
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
        buildChildCallback: (_) => const SizedBox.shrink(),
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
        buildChildCallback: (_) => const SizedBox.shrink(),
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
          buildChildCallback: (_) => const SizedBox.shrink(),
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
            buildChildCallback: (_) => const SizedBox.shrink(),
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
        buildChildCallback: (_) => const SizedBox.shrink(),
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
        buildChildCallback: (_) => const SizedBox.shrink(),
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
        buildChildCallback: (_) => const SizedBox.shrink(),
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
            buildChildCallback: (_) => const SizedBox.shrink(),
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
        buildChildCallback: (_) => const SizedBox.shrink(),
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
