// Cascade invocations are ignored to keep test setup clean and readable.
// ignore_for_file: cascade_invocations

import 'dart:convert';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:test/test.dart';

sealed class TestCounterEvent {}

class IncrementEvent extends TestCounterEvent {}

class ErrorEvent extends TestCounterEvent {}

class TestCounterBloc extends BlocSignal<TestCounterEvent, int> {
  TestCounterBloc({super.initialState = 0}) {
    on<IncrementEvent>((event, emit) => emit(stateValue + 1));
    on<ErrorEvent>(
      (event, emit) => throw const FormatException('Test failure'),
    );
  }
}

class TestCubit extends CubitSignal<int> {
  TestCubit({super.initialState = 0});

  void increment() => emit(stateValue + 1);
}

class RecordingObserver extends BlocSignalObserver {
  final List<String> calls = [];

  @override
  void onCreate(BlocSignalBase<dynamic> bloc) {
    super.onCreate(bloc);
    calls.add('onCreate');
  }

  @override
  void onEvent(BlocSignalBase<dynamic> bloc, Object? event) {
    super.onEvent(bloc, event);
    calls.add('onEvent');
  }

  @override
  void onTransition(
    BlocSignalBase<dynamic> bloc,
    Object? event,
    Object? state,
  ) {
    super.onTransition(bloc, event, state);
    calls.add('onTransition');
  }

  @override
  void onChange(BlocSignalBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    calls.add('onChange');
  }

  @override
  void onError(
    BlocSignalBase<dynamic> bloc,
    Object error,
    StackTrace stackTrace,
  ) {
    super.onError(bloc, error, stackTrace);
    calls.add('onError');
  }

  @override
  void onTelemetry(
    BlocSignalBase<dynamic> bloc,
    String name, {
    Object? event,
    Map<String, dynamic>? metadata,
  }) {
    super.onTelemetry(bloc, name, event: event, metadata: metadata);
    calls.add('onTelemetry');
  }

  @override
  void onClose(BlocSignalBase<dynamic> bloc) {
    super.onClose(bloc);
    calls.add('onClose');
  }
}

class _TelemetryCubit extends CubitSignal<int> {
  _TelemetryCubit() : super(initialState: 0);

  void sendTelemetry() {
    emitTelemetry(
      'cache_hit',
      metadata: {
        'count': 1,
        'nested': {'k': 'v'},
        'list': [1, 2],
        'flag': true,
      },
    );
  }

  void sendTelemetryWithEvent(Object event) {
    emitTelemetry(
      'event_processed',
      event: event,
      metadata: {
        'date': DateTime(2026, 2, 3),
      },
    );
  }
}

void main() {
  group('DevToolsBlocSignalObserver', () {
    late RecordingObserver recordingObserver;
    late DevToolsBlocSignalObserver devToolsObserver;

    setUp(() {
      recordingObserver = RecordingObserver();
      devToolsObserver = DevToolsBlocSignalObserver(
        previousObserver: recordingObserver,
      );
      BlocSignalObserver.observer = devToolsObserver;
    });

    tearDown(() {
      BlocSignalObserver.observer = null;
    });

    test('captures onCreate and forwards to previousObserver', () async {
      final cubit = TestCubit(initialState: 10);
      expect(recordingObserver.calls, contains('onCreate'));
      await cubit.close();
    });

    test('captures state changes on cubit emit', () async {
      final cubit = TestCubit()..increment();

      expect(cubit.stateValue, equals(1));
      expect(recordingObserver.calls, contains('onChange'));
      await cubit.close();
    });

    test('captures events and transitions on bloc add', () async {
      final bloc = TestCounterBloc()..add(IncrementEvent());

      expect(bloc.stateValue, equals(1));
      expect(
        recordingObserver.calls,
        containsAll(['onEvent', 'onTransition', 'onChange']),
      );
      await bloc.close();
    });

    test('captures onError on operational exceptions', () async {
      final bloc = TestCounterBloc()..add(ErrorEvent());

      expect(recordingObserver.calls, contains('onError'));
      await bloc.close();
    });

    test('captures onClose when container is closed', () async {
      final bloc = TestCounterBloc();
      await bloc.close();

      expect(recordingObserver.calls, contains('onClose'));
    });

    test('captures onTelemetry and forwards to previousObserver', () async {
      final cubit = _TelemetryCubit();
      cubit.sendTelemetry();

      expect(recordingObserver.calls, contains('onTelemetry'));
      await cubit.close();
    });

    test('captures onTelemetry with event and custom metadata types', () async {
      final cubit = _TelemetryCubit();
      cubit.sendTelemetryWithEvent(IncrementEvent());

      expect(recordingObserver.calls, contains('onTelemetry'));
      await cubit.close();
    });

    test(
      '(Issue #474: F03) stateRedactor, eventRedactor, errorRedactor, '
      'stackTraceRedactor, and maxPayloadLength redact and truncate recorded '
      'history and RPC responses',
      () async {
        DevToolsService.instance.reset();
        addTearDown(DevToolsService.instance.reset);

        final observer = DevToolsBlocSignalObserver(
          stateRedactor: (bloc, state) => 'STATE[$state]',
          eventRedactor: (bloc, event) => 'EVENT[$event]',
          errorRedactor: (bloc, error) => 'ERR[$error]',
          stackTraceRedactor: (st) => 'STACK_REDACTED',
          maxPayloadLength: 18,
        );
        BlocSignalObserver.observer = observer;

        final bloc = TestCounterBloc()..add(IncrementEvent());
        addTearDown(bloc.close);
        bloc.add(ErrorEvent());

        final id = identityHashCode(bloc);
        final history = DevToolsService.instance.getHistoryForTest(id);
        expect(history, isNotNull);

        final transitionEntry = history!.firstWhere(
          (e) => e.type == 'transition',
        );
        expect(
          transitionEntry.data['event'],
          equals('EVENT[Instance of ...[truncated]'),
        );
        expect(transitionEntry.data['currentState'], equals('STATE[0]'));
        expect(transitionEntry.data['nextState'], equals('STATE[1]'));

        final errorEntry = history.firstWhere((e) => e.type == 'error');
        expect(
          errorEntry.data['error'],
          equals('ERR[FormatExceptio...[truncated]'),
        );
        expect(errorEntry.data['stackTrace'], equals('STACK_REDACTED'));
      },
    );

    test(
      '(Issue #474: F03) maxPayloadLength null or <= 0 disables truncation',
      () async {
        DevToolsService.instance.reset();
        addTearDown(DevToolsService.instance.reset);

        final observer = DevToolsBlocSignalObserver(
          stateRedactor: (bloc, state) => 'X' * 5000,
          maxPayloadLength: 0,
        );
        BlocSignalObserver.observer = observer;

        final cubit = TestCubit();
        addTearDown(cubit.close);

        final instancesRes = await DevToolsService.instance.handleGetInstances(
          'ext.bloc_signal.getInstances',
          const {},
        );
        final decoded =
            jsonDecode(instancesRes.result!) as Map<String, dynamic>;
        final instances = decoded['instances'] as List<dynamic>;
        final entry = instances.first as Map<String, dynamic>;
        expect((entry['stateValue'] as String).length, equals(5000));
      },
    );

    test(
      '(Issue #474: F04) throwing redactor is isolated and does not abort '
      'state transitions or RPCs',
      () async {
        DevToolsService.instance.reset();
        addTearDown(DevToolsService.instance.reset);

        final observer = DevToolsBlocSignalObserver(
          stateRedactor: (bloc, state) => throw const FormatException('boom'),
          eventRedactor: (bloc, event) => throw const FormatException('boom'),
          errorRedactor: (bloc, error) => throw const FormatException('boom'),
          stackTraceRedactor: (st) => throw const FormatException('boom'),
        );
        BlocSignalObserver.observer = observer;

        final bloc = TestCounterBloc()..add(IncrementEvent());
        addTearDown(bloc.close);
        expect(bloc.stateValue, equals(1));

        bloc.add(ErrorEvent());

        final id = identityHashCode(bloc);
        final history = DevToolsService.instance.getHistoryForTest(id);
        expect(history, isNotNull);
        final transitionEntry = history!.firstWhere(
          (e) => e.type == 'transition',
        );
        expect(transitionEntry.data['event'], equals('<redaction_error>'));
        expect(transitionEntry.data['nextState'], equals('<redaction_error>'));

        final errorEntry = history.firstWhere((e) => e.type == 'error');
        expect(errorEntry.data['error'], equals('<redaction_error>'));
        expect(errorEntry.data['stackTrace'], equals('<redaction_error>'));
      },
    );

    test(
      '(Issue #474: F05) _sanitizeMetadata recursively converts NaN/Infinity, '
      'nested collections, and cyclic structures into jsonEncode-safe payloads',
      () async {
        DevToolsService.instance.reset();
        addTearDown(DevToolsService.instance.reset);

        final observer = DevToolsBlocSignalObserver(maxPayloadLength: 32);
        BlocSignalObserver.observer = observer;

        final cubit = TestCubit();
        addTearDown(cubit.close);

        final cyclicList = <dynamic>[1];
        cyclicList.add(cyclicList);

        final cyclicMap = <String, dynamic>{'nan': double.nan};
        cyclicMap['self'] = cyclicMap;

        var deep = <String, dynamic>{'leaf': double.infinity};
        for (var i = 0; i < 12; i++) {
          deep = {'level$i': deep};
        }

        observer.onTelemetry(
          cubit,
          'complex_meta',
          metadata: {
            'nan': double.nan,
            'inf': double.infinity,
            'ninf': double.negativeInfinity,
            'nested': {
              'items': [double.nan, double.infinity, 'ok'],
            },
            'cyclicList': cyclicList,
            'cyclicMap': cyclicMap,
            'deep': deep,
          },
        );

        final id = identityHashCode(cubit);
        final history = DevToolsService.instance.getHistoryForTest(id);
        expect(history, isNotNull);
        final entry = history!.last;
        final meta = entry.data['metadata'] as Map<String, dynamic>;
        expect(meta['nan'], equals('NaN'));
        expect(meta['inf'], equals('Infinity'));
        expect(meta['ninf'], equals('-Infinity'));
        expect(
          (meta['nested'] as Map<String, dynamic>)['items'],
          equals(['NaN', 'Infinity', 'ok']),
        );
        expect(
          (meta['cyclicList'] as List<dynamic>)[1],
          equals('<max_depth_or_cycle>'),
        );
        expect(
          (meta['cyclicMap'] as Map<String, dynamic>)['self'],
          equals('<max_depth_or_cycle>'),
        );
        // Walk down 8 levels of 'deep' to verify <max_depth_or_cycle>
        dynamic cursor = meta['deep'];
        for (var i = 11; i >= 5; i--) {
          cursor = (cursor as Map<String, dynamic>)['level$i'];
        }
        expect(cursor, equals('<max_depth_or_cycle>'));
        expect(() => jsonEncode(entry.toJson()), returnsNormally);
      },
    );

    test(
      '(Issue #474: BLOCKER-1, BLOCKER-5) intentional null redactor returns '
      'preserve null without falling back to raw toString()',
      () async {
        DevToolsService.instance.reset();
        addTearDown(DevToolsService.instance.reset);

        final observer = DevToolsBlocSignalObserver(
          stateRedactor: (bloc, state) => null,
          eventRedactor: (bloc, event) => null,
          errorRedactor: (bloc, error) => null,
        );
        BlocSignalObserver.observer = observer;

        final bloc = TestCounterBloc()..add(IncrementEvent());
        addTearDown(bloc.close);
        bloc.add(ErrorEvent());

        final id = identityHashCode(bloc);
        final history = DevToolsService.instance.getHistoryForTest(id)!;
        final transitionEntry = history.firstWhere(
          (e) => e.type == 'transition',
        );
        expect(transitionEntry.data['event'], isNull);
        expect(transitionEntry.data['currentState'], isNull);
        expect(transitionEntry.data['nextState'], isNull);

        final errorEntry = history.firstWhere((e) => e.type == 'error');
        expect(errorEntry.data['error'], isNull);
      },
    );

    test(
      '(Issue #474: BLOCKER-1, BLOCKER-5, NBO-2) maxPayloadLength null '
      'disables metadata truncation, default 4096 truncates, and '
      'truncatePayload preserves UTF-16 surrogate pairs',
      () async {
        DevToolsService.instance.reset();
        addTearDown(DevToolsService.instance.reset);

        // 1. maxPayloadLength: null disables truncation even for >4096 strings
        final unlimitedObserver = DevToolsBlocSignalObserver(
          maxPayloadLength: null,
        );
        BlocSignalObserver.observer = unlimitedObserver;

        final cubit = TestCubit();
        addTearDown(cubit.close);

        final longText = 'A' * 5000;
        unlimitedObserver.onTelemetry(
          cubit,
          'large_meta',
          metadata: {'payload': longText},
        );
        final id = identityHashCode(cubit);
        final unlimitedEntry =
            DevToolsService.instance.getHistoryForTest(id)!.last;
        expect(
          (unlimitedEntry.data['metadata'] as Map<String, dynamic>)['payload'],
          equals(longText),
        );

        // Also verify handleGetInstances / formatState with maxPayloadLength: null
        final instancesRes = await DevToolsService.instance.handleGetInstances(
          'ext.bloc_signal.getInstances',
          const {},
        );
        final decodedInstances = (jsonDecode(instancesRes.result!)
            as Map<String, dynamic>)['instances'] as List<dynamic>;
        expect(
          DevToolsService.instance.formatState(cubit, longText),
          equals(longText),
        );
        expect(decodedInstances, isNotEmpty);

        // 2. Default maxPayloadLength (4096) truncates >4096 strings
        DevToolsService.instance.reset();
        final defaultObserver = DevToolsBlocSignalObserver();
        BlocSignalObserver.observer = defaultObserver;
        final cubit2 = TestCubit();
        addTearDown(cubit2.close);
        defaultObserver.onTelemetry(
          cubit2,
          'default_cap',
          metadata: {'payload': longText, 'key_${'K' * 4100}': 'v'},
        );
        final defaultEntry = DevToolsService.instance
            .getHistoryForTest(identityHashCode(cubit2))!
            .last;
        final defaultMeta =
            defaultEntry.data['metadata'] as Map<String, dynamic>;
        expect(
          defaultMeta['payload'],
          equals('${'A' * 4096}...[truncated]'),
        );
        expect(
          defaultMeta.keys.firstWhere((k) => k.startsWith('key_')),
          endsWith('...[truncated]'),
        );

        // 3. Surrogate-pair safety: 'abcd' + U+1F600 (length 6) capped at 5
        // must back off to 4 so the high surrogate is not orphaned.
        const emojiStr = 'abcd\u{1F600}';
        expect(
          DevToolsService.truncatePayload(emojiStr, 5),
          equals('abcd...[truncated]'),
        );
      },
    );
  });
}
