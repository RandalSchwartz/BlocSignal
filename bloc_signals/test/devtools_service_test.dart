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

void main() {
  BlocSignalObserver? originalObserver;

  setUp(() {
    originalObserver = BlocSignalObserver.observer;
    BlocSignalObserver.observer = DevToolsBlocSignalObserver();
  });

  tearDown(() {
    BlocSignalObserver.observer = originalObserver;
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
  });
}
