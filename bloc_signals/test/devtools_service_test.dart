import 'dart:convert';

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
  });
}
