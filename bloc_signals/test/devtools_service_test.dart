import 'dart:convert';
import 'dart:typed_data';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:test/test.dart';

class CounterCubit extends CubitSignal<int> {
  CounterCubit({super.initialState = 0});

  void increment() => emit(stateValue + 1);
}

class CounterBloc extends BlocSignal<String, int> {
  CounterBloc() : super(initialState: 0) {
    on<String>((event, emit) {
      if (event == 'inc') {
        emit(stateValue + 1);
      } else if (event == 'error') {
        throw StateError('Test error');
      }
    });
  }
}

class JsonBloc extends BlocSignal<Map<String, dynamic>, String> {
  JsonBloc() : super(initialState: 'none') {
    on<Map<String, dynamic>>((event, emit) {
      emit(event['name'] as String);
    });
  }
}

class OtherBloc extends BlocSignal<String, int> {
  OtherBloc() : super(initialState: 0) {
    on<String>((event, emit) {
      if (event == 'inc') {
        emit(stateValue + 1);
      }
    });
  }
}

@pragma('vm:never-inline')
(int, WeakReference<CounterBloc>) _createUnclosedBlocForGc() {
  final bloc = CounterBloc()..add('inc');
  return (identityHashCode(bloc), WeakReference(bloc));
}

void main() {
  BlocSignalObserver? originalObserver;

  setUp(() {
    originalObserver = BlocSignalObserver.observer;
    BlocSignalObserver.observer = DevToolsBlocSignalObserver();
  });

  tearDown(() {
    BlocSignalObserver.observer = originalObserver;
    DevToolsService.instance.clearEventDeserializers();
  });

  group('DevToolsService RPC Extensions', () {
    test('handleGetInstances returns active container metadata', () async {
      final cubit = CounterCubit(initialState: 10);
      final response = await DevToolsService.instance.handleGetInstances(
        'ext.bloc_signal.getInstances',
        {},
      );

      final json = jsonDecode(response.result!) as Map<String, dynamic>;
      final instances = json['instances'] as List<dynamic>;

      expect(instances.isNotEmpty, isTrue);
      final found = instances.firstWhere(
        (e) => (e as Map<String, dynamic>)['hashCode'] == cubit.hashCode,
      ) as Map<String, dynamic>;

      expect(found['type'], contains('CounterCubit'));
      expect(found['stateValue'], equals('10'));
      expect(found['isClosed'], isFalse);

      await cubit.close();
    });

    test('handleGetHistory records transitions and errors', () async {
      final bloc = CounterBloc()..add('inc');

      try {
        bloc.add('error');
      } on Object catch (_) {}

      final response = await DevToolsService.instance.handleGetHistory(
        'ext.bloc_signal.getHistory',
        {'hashCode': bloc.hashCode.toString()},
      );

      final json = jsonDecode(response.result!) as Map<String, dynamic>;
      final history = json['history'] as List<dynamic>;

      expect(history.length, greaterThanOrEqualTo(2));
      final transition = history.firstWhere(
        (e) => (e as Map<String, dynamic>)['type'] == 'transition',
      ) as Map<String, dynamic>;
      final data = transition['data'] as Map<String, dynamic>;

      expect(data['event'], equals('inc'));
      expect(data['nextState'], equals('1'));

      await bloc.close();
    });

    test(
      'handleGetHistory returns error on missing or invalid hashCode',
      () async {
        final errRes1 = await DevToolsService.instance.handleGetHistory(
          'ext.bloc_signal.getHistory',
          {},
        );
        expect(errRes1.errorCode, equals(-32602));

        final errRes2 = await DevToolsService.instance.handleGetHistory(
          'ext.bloc_signal.getHistory',
          {'hashCode': '99999999'},
        );
        expect(errRes2.errorCode, equals(-32602));
      },
    );

    test('handleDispatch triggers remote event execution', () async {
      final bloc = CounterBloc();

      final response = await DevToolsService.instance.handleDispatch(
        'ext.bloc_signal.dispatch',
        {
          'hashCode': bloc.hashCode.toString(),
          'event': 'inc',
        },
      );

      final json = jsonDecode(response.result!) as Map<String, dynamic>;
      expect(json['success'], isTrue);
      expect(bloc.stateValue, equals(1));

      await bloc.close();
    });

    test(
      'handleDispatch parses JSON string events for structured blocs',
      () async {
        final bloc = JsonBloc();

        final response = await DevToolsService.instance.handleDispatch(
          'ext.bloc_signal.dispatch',
          {
            'hashCode': bloc.hashCode.toString(),
            'event': '{"name":"alice"}',
          },
        );

        final json = jsonDecode(response.result!) as Map<String, dynamic>;
        expect(json['success'], isTrue);
        expect(bloc.stateValue, equals('alice'));

        await bloc.close();
      },
    );

    test(
      'handleDispatch returns error on type mismatch during dispatch',
      () async {
        final bloc = JsonBloc();

        final errRes = await DevToolsService.instance.handleDispatch(
          'ext.bloc_signal.dispatch',
          {
            'hashCode': bloc.hashCode.toString(),
            'event': 'plain_non_json_string',
          },
        );

        expect(errRes.errorCode, equals(-32602));
        await bloc.close();
      },
    );

    test(
      'handleDispatch returns error on closed or missing container',
      () async {
        final cubit = CounterCubit();
        await cubit.close();

        final errRes = await DevToolsService.instance.handleDispatch(
          'ext.bloc_signal.dispatch',
          {
            'hashCode': cubit.hashCode.toString(),
            'event': 'inc',
          },
        );

        expect(errRes.errorCode, equals(-32602));
      },
    );

    test(
        'handleGetHistory includes hashCode, instanceHashCode, and '
        'currentState', () async {
      final bloc = CounterBloc()..add('inc');

      final response = await DevToolsService.instance.handleGetHistory(
        'ext.bloc_signal.getHistory',
        {'hashCode': bloc.hashCode.toString()},
      );

      final json = jsonDecode(response.result!) as Map<String, dynamic>;
      final history = json['history'] as List<dynamic>;
      final transition = history.firstWhere(
        (e) => (e as Map<String, dynamic>)['type'] == 'transition',
      ) as Map<String, dynamic>;

      expect(transition['hashCode'], equals(bloc.hashCode));
      expect(transition['instanceHashCode'], equals(bloc.hashCode));
      final data = transition['data'] as Map<String, dynamic>;
      expect(data['currentState'], equals('0'));
      expect(data['nextState'], equals('1'));

      await bloc.close();
    });

    test('handleDispatch returns error on malformed JSON payload', () async {
      final bloc = JsonBloc();

      final errRes = await DevToolsService.instance.handleDispatch(
        'ext.bloc_signal.dispatch',
        {
          'hashCode': bloc.hashCode.toString(),
          'event': '{"malformed":',
        },
      );

      expect(errRes.errorCode, equals(-32602));
      expect(errRes.errorDetail, contains('Invalid JSON'));
      await bloc.close();
    });

    test('handleDispatch supports registered typed event deserializers',
        () async {
      final bloc = CounterBloc();
      DevToolsService.instance.registerEventDeserializer<CounterBloc>((raw) {
        if (raw is Map && raw['action'] == 'plus') return 'inc';
        return raw;
      });

      final response = await DevToolsService.instance.handleDispatch(
        'ext.bloc_signal.dispatch',
        {
          'hashCode': bloc.hashCode.toString(),
          'event': '{"action":"plus"}',
        },
      );

      final json = jsonDecode(response.result!) as Map<String, dynamic>;
      expect(json['success'], isTrue);
      expect(bloc.stateValue, equals(1));
      await bloc.close();
    });

    test('handleDispatch returns error when registered deserializer throws',
        () async {
      final bloc = CounterBloc();
      DevToolsService.instance.registerEventDeserializer<CounterBloc>((raw) {
        throw const FormatException('Corrupted event payload');
      });

      final response = await DevToolsService.instance.handleDispatch(
        'ext.bloc_signal.dispatch',
        {
          'hashCode': bloc.hashCode.toString(),
          'event': '{"action":"plus"}',
        },
      );

      expect(response.errorCode, equals(-32602));
      expect(
        response.errorDetail,
        contains('Failed to deserialize event for CounterBloc'),
      );
      await bloc.close();
    });

    group(
        '(Issue #332: R18) unregisterEventDeserializer and '
        'clearEventDeserializers', () {
      test(
          '(Issue #332: R18) unregisterEventDeserializer<T>() removes typed '
          'deserializer and stops invoking it on handleDispatch', () async {
        final bloc = CounterBloc();
        addTearDown(bloc.close);

        var deserializerCalls = 0;
        DevToolsService.instance.registerEventDeserializer<CounterBloc>((raw) {
          deserializerCalls++;
          if (raw is Map && raw['action'] == 'plus') return 'inc';
          return raw;
        });

        final res1 = await DevToolsService.instance.handleDispatch(
          'ext.bloc_signal.dispatch',
          {
            'hashCode': bloc.hashCode.toString(),
            'event': '{"action":"plus"}',
          },
        );
        final json1 = jsonDecode(res1.result!) as Map<String, dynamic>;
        expect(json1['success'], isTrue);
        expect(bloc.stateValue, equals(1));
        expect(deserializerCalls, equals(1));

        // Unregistering returns true the first time, false when already absent
        expect(
          DevToolsService.instance.unregisterEventDeserializer<CounterBloc>(),
          isTrue,
        );
        expect(
          DevToolsService.instance.unregisterEventDeserializer<CounterBloc>(),
          isFalse,
        );

        // Subsequent dispatch no longer runs the removed deserializer
        final res2 = await DevToolsService.instance.handleDispatch(
          'ext.bloc_signal.dispatch',
          {
            'hashCode': bloc.hashCode.toString(),
            'event': '{"action":"plus"}',
          },
        );
        expect(res2.errorCode, equals(-32602));
        expect(deserializerCalls, equals(1));
      });

      test(
          '(Issue #332: R18) registerEventDeserializer and '
          'unregisterEventDeserializer support named eventName lookup',
          () async {
        final bloc = CounterBloc();
        addTearDown(bloc.close);

        var namedCalls = 0;
        DevToolsService.instance.registerEventDeserializer(
          (raw) {
            namedCalls++;
            return 'inc';
          },
          eventName: 'customInc',
        );

        // Verify dispatch via JSON payload 'event', 'type', 'name', 'action'
        for (final key in ['event', 'type', 'name', 'action']) {
          final resMapKey = await DevToolsService.instance.handleDispatch(
            'ext.bloc_signal.dispatch',
            {
              'hashCode': bloc.hashCode.toString(),
              'event': '{"$key":"customInc"}',
            },
          );
          expect(
            (jsonDecode(resMapKey.result!) as Map<String, dynamic>)['success'],
            isTrue,
          );
        }
        expect(bloc.stateValue, equals(4));
        expect(namedCalls, equals(4));

        // Verify dispatch via parameter 'eventName'
        final resParam = await DevToolsService.instance.handleDispatch(
          'ext.bloc_signal.dispatch',
          {
            'hashCode': bloc.hashCode.toString(),
            'event': 'raw_payload',
            'eventName': 'customInc',
          },
        );
        expect(
          (jsonDecode(resParam.result!) as Map<String, dynamic>)['success'],
          isTrue,
        );
        expect(bloc.stateValue, equals(5));
        expect(namedCalls, equals(5));

        // Verify non-String map key value (for example {"event": 123}) and
        // non-matching map fall through without invoking the deserializer
        final resNonStringKey = await DevToolsService.instance.handleDispatch(
          'ext.bloc_signal.dispatch',
          {
            'hashCode': bloc.hashCode.toString(),
            'event': '{"event":123}',
          },
        );
        expect(resNonStringKey.errorCode, equals(-32602));
        expect(namedCalls, equals(5));

        final resUnmatchedParam = await DevToolsService.instance.handleDispatch(
          'ext.bloc_signal.dispatch',
          {
            'hashCode': bloc.hashCode.toString(),
            'event': '{"other":"value"}',
            'eventName': 'unknownEventName',
          },
        );
        expect(resUnmatchedParam.errorCode, equals(-32602));
        expect(namedCalls, equals(5));

        // Unregister by eventName
        expect(
          DevToolsService.instance.unregisterEventDeserializer('customInc'),
          isTrue,
        );
        expect(
          DevToolsService.instance.unregisterEventDeserializer('customInc'),
          isFalse,
        );

        final resAfter = await DevToolsService.instance.handleDispatch(
          'ext.bloc_signal.dispatch',
          {
            'hashCode': bloc.hashCode.toString(),
            'event': '{"type":"customInc"}',
          },
        );
        expect(resAfter.errorCode, equals(-32602));
        expect(namedCalls, equals(5));

        // Register with both <CounterBloc> and eventName: 'bothEvent'
        DevToolsService.instance.registerEventDeserializer<CounterBloc>(
          (raw) => 'inc',
          eventName: 'bothEvent',
        );
        expect(
          DevToolsService.instance
              .unregisterEventDeserializer<CounterBloc>('bothEvent'),
          isTrue,
        );
        expect(
          DevToolsService.instance
              .unregisterEventDeserializer<CounterBloc>('bothEvent'),
          isFalse,
        );
      });

      test(
          '(Issue #332: R18) clearEventDeserializers removes all registered '
          'deserializers at once', () async {
        final bloc = CounterBloc();
        addTearDown(bloc.close);

        DevToolsService.instance.registerEventDeserializer<CounterBloc>(
          (raw) => 'inc',
        );
        DevToolsService.instance.registerEventDeserializer(
          (raw) => 'inc',
          eventName: 'namedInc',
        );

        DevToolsService.instance.clearEventDeserializers();

        expect(
          DevToolsService.instance.unregisterEventDeserializer<CounterBloc>(),
          isFalse,
        );
        expect(
          DevToolsService.instance.unregisterEventDeserializer('namedInc'),
          isFalse,
        );
      });
    });

    group('(Issue #429) DevToolsService hardening', () {
      test(
        '(Issue #429) handleGetInstances prunes dead WeakReferences and '
        'evicts _history[id]',
        () async {
          final (id, weakRef) = _createUnclosedBlocForGc();
          expect(DevToolsService.instance.getHistoryForTest(id), isNotNull);

          // Allocate memory to encourage GC of the unreferenced CounterBloc.
          for (var i = 0; i < 128 && weakRef.target != null; i++) {
            Uint8List(1024 * 1024);
            await Future<void>.delayed(Duration.zero);
          }

          expect(
            weakRef.target,
            isNull,
            reason: 'Unclosed CounterBloc must be garbage collected after '
                'allocations',
          );

          await DevToolsService.instance.handleGetInstances(
            'ext.bloc_signal.getInstances',
            {},
          );
          expect(DevToolsService.instance.getHistoryForTest(id), isNull);

          final historyRes = await DevToolsService.instance.handleGetHistory(
            'ext.bloc_signal.getHistory',
            {'hashCode': id.toString()},
          );
          expect(historyRes.errorCode, equals(-32602));
        },
      );

      test(
        '(Issue #429) container-scoped registerEventDeserializer does not '
        'resolve for other container types while unscoped remains global '
        'fallback',
        () async {
          final counterBloc = CounterBloc();
          final otherBloc = OtherBloc();
          addTearDown(() async {
            await counterBloc.close();
            await otherBloc.close();
          });

          DevToolsService.instance.registerEventDeserializer<CounterBloc>(
            (raw) => 'inc',
            eventName: 'scopedEvent',
          );

          // Should resolve for CounterBloc.
          final resCounter = await DevToolsService.instance.handleDispatch(
            'ext.bloc_signal.dispatch',
            {
              'hashCode': counterBloc.hashCode.toString(),
              'event': '{"event":"scopedEvent"}',
            },
          );
          expect(
            (jsonDecode(resCounter.result!) as Map<String, dynamic>)['success'],
            isTrue,
          );
          expect(counterBloc.stateValue, equals(1));

          // Should NOT resolve for OtherBloc.
          final resOther = await DevToolsService.instance.handleDispatch(
            'ext.bloc_signal.dispatch',
            {
              'hashCode': otherBloc.hashCode.toString(),
              'event': '{"event":"scopedEvent"}',
            },
          );
          expect(resOther.errorCode, equals(-32602));
          expect(otherBloc.stateValue, equals(0));

          // Unscoped registration acts as global fallback for both.
          DevToolsService.instance.registerEventDeserializer(
            (raw) => 'inc',
            eventName: 'globalEvent',
          );

          final resGlobalOther = await DevToolsService.instance.handleDispatch(
            'ext.bloc_signal.dispatch',
            {
              'hashCode': otherBloc.hashCode.toString(),
              'event': '{"event":"globalEvent"}',
            },
          );
          expect(
            (jsonDecode(resGlobalOther.result!)
                as Map<String, dynamic>)['success'],
            isTrue,
          );
          expect(otherBloc.stateValue, equals(1));
        },
      );

      test(
        '(Issue #429) handleDispatch returns invalidParams for missing/empty '
        'event, oversized payload, or non-BlocSignalMixin target',
        () async {
          final bloc = CounterBloc();
          final cubit = CounterCubit();
          addTearDown(() async {
            await bloc.close();
            await cubit.close();
          });

          // Missing event parameter.
          final resMissing = await DevToolsService.instance.handleDispatch(
            'ext.bloc_signal.dispatch',
            {'hashCode': bloc.hashCode.toString()},
          );
          expect(resMissing.errorCode, equals(-32602));

          // Empty event parameter.
          final resEmpty = await DevToolsService.instance.handleDispatch(
            'ext.bloc_signal.dispatch',
            {'hashCode': bloc.hashCode.toString(), 'event': ''},
          );
          expect(resEmpty.errorCode, equals(-32602));

          // Oversized payload (> 65536 bytes).
          final resOversized = await DevToolsService.instance.handleDispatch(
            'ext.bloc_signal.dispatch',
            {
              'hashCode': bloc.hashCode.toString(),
              'event': 'a' * (DevToolsService.kMaxDispatchPayloadLength + 1),
            },
          );
          expect(resOversized.errorCode, equals(-32602));
          expect(DevToolsService.kMaxDispatchPayloadLength, equals(65536));

          // Target is a CubitSignal (not BlocSignalMixin).
          final resCubit = await DevToolsService.instance.handleDispatch(
            'ext.bloc_signal.dispatch',
            {
              'hashCode': cubit.hashCode.toString(),
              'event': 'inc',
            },
          );
          expect(resCubit.errorCode, equals(-32602));
        },
      );

      test(
        '(Issue #429) isEnabled = false disables history retention and '
        'extension registration',
        () async {
          DevToolsService.instance.isEnabled = false;
          addTearDown(() => DevToolsService.instance.isEnabled = true);

          final bloc = CounterBloc()..add('inc');
          addTearDown(bloc.close);

          expect(
            DevToolsService.instance.getHistoryForTest(identityHashCode(bloc)),
            isNull,
          );
        },
      );

      test(
        '(Issue #429) reset detaches finalizers and clears containers, '
        'history, and deserializers',
        () async {
          final bloc = CounterBloc()..add('inc');
          addTearDown(bloc.close);
          final id = identityHashCode(bloc);

          DevToolsService.instance.registerEventDeserializer<CounterBloc>(
            (raw) => 'inc',
            eventName: 'scopedOnly',
          );
          expect(DevToolsService.instance.getHistoryForTest(id), isNotNull);

          DevToolsService.instance.reset();

          expect(DevToolsService.instance.getHistoryForTest(id), isNull);
          expect(
            DevToolsService.instance
                .unregisterEventDeserializer<CounterBloc>('scopedOnly'),
            isFalse,
          );
        },
      );

      test(
        '(Issue #429) handleDispatch decodes JSON payloads with leading '
        'whitespace',
        () async {
          final bloc = JsonBloc();
          addTearDown(bloc.close);

          final response = await DevToolsService.instance.handleDispatch(
            'ext.bloc_signal.dispatch',
            {
              'hashCode': bloc.hashCode.toString(),
              'event': '  \n\t {"name":"bob"}',
            },
          );

          final json = jsonDecode(response.result!) as Map<String, dynamic>;
          expect(json['success'], isTrue);
          expect(bloc.stateValue, equals('bob'));
        },
      );

      test(
        '(Issue #429) registerEventDeserializer asserts when neither explicit '
        'type nor eventName is provided',
        () {
          expect(
            () => DevToolsService.instance.registerEventDeserializer(
              (raw) => raw,
            ),
            throwsA(isA<AssertionError>()),
          );
        },
      );
    });
  });
}
