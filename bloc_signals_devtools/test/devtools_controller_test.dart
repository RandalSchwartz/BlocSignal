import 'dart:async';

import 'package:bloc_signals_devtools/bloc_signals_devtools.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vm_service/vm_service.dart' as vm;

void main() {
  group('BlocSignalsDevToolsController', () {
    test('initial state is clean and empty', () {
      final controller = BlocSignalsDevToolsController(
        callExtensionRpc: (method, [args]) async => {},
      );

      expect(controller.instances, isEmpty);
      expect(controller.history, isEmpty);
      expect(controller.isLoading, isFalse);
      expect(controller.errorMessage, isNull);

      controller.dispose();
    });

    test('fetchInstances successfully populates instances', () async {
      final controller = BlocSignalsDevToolsController(
        callExtensionRpc: (method, [args]) async {
          expect(method, equals('ext.bloc_signal.getInstances'));
          return {
            'instances': [
              {
                'hashCode': 1001,
                'name': 'CounterCubit',
                'stateValue': '0',
                'isClosed': false,
              },
            ],
          };
        },
      );

      final states = <bool>[];
      controller.addListener(() => states.add(controller.isLoading));

      await controller.fetchInstances();

      expect(controller.instances.length, equals(1));
      expect(controller.instances.first['name'], equals('CounterCubit'));
      expect(controller.isLoading, isFalse);
      expect(controller.errorMessage, isNull);
      expect(states, containsAllInOrder([true, false]));

      controller.dispose();
    });

    test('fetchInstances handles RPC exceptions gracefully', () async {
      final controller = BlocSignalsDevToolsController(
        callExtensionRpc: (method, [args]) async {
          throw Exception('RPC timeout');
        },
      );

      await controller.fetchInstances();

      expect(controller.instances, isEmpty);
      expect(controller.isLoading, isFalse);
      expect(
        controller.errorMessage,
        contains(
          'Could not fetch containers. Ensure DevToolsBlocSignalObserver is '
          'registered',
        ),
      );

      controller.dispose();
    });

    test('fetchInstances enforces reentrancy guard', () async {
      var callCount = 0;
      final completer = Completer<Map<String, dynamic>>();

      final controller = BlocSignalsDevToolsController(
        callExtensionRpc: (method, [args]) {
          callCount++;
          return completer.future;
        },
      );

      // Trigger two simultaneous calls
      final future1 = controller.fetchInstances();
      final future2 = controller.fetchInstances();

      completer.complete({'instances': <dynamic>[]});
      await Future.wait([future1, future2]);

      expect(callCount, equals(1));
      controller.dispose();
    });

    test('onCreate coalesces rapid events via debounce timer', () async {
      var callCount = 0;
      final controller = BlocSignalsDevToolsController(
        callExtensionRpc: (method, [args]) async {
          callCount++;
          return {'instances': <dynamic>[]};
        },
        debounceDuration: const Duration(milliseconds: 20),
      );

      final eventStream = StreamController<vm.Event>.broadcast();
      controller.attachEventStream(eventStream.stream);

      // Dispatch 5 rapid onCreate events
      for (var i = 0; i < 5; i++) {
        eventStream.add(
          vm.Event(
            kind: vm.EventKind.kExtension,
            extensionKind: 'bloc_signal.onCreate',
            extensionData: vm.ExtensionData()
              ..data.addAll({'hashCode': 1000 + i}),
            timestamp: 1000,
          ),
        );
      }

      // Wait past debounce duration
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(callCount, equals(1));

      await eventStream.close();
      controller.dispose();
    });

    test('handleEvent processes onClose and marks matching instance', () async {
      final controller = BlocSignalsDevToolsController(
        callExtensionRpc: (method, [args]) async => {
          'instances': [
            {
              'hashCode': 2001,
              'name': 'CounterCubit',
              'stateValue': '5',
              'isClosed': false,
            },
          ],
        },
      );

      await controller.fetchInstances();
      expect(controller.instances.first['isClosed'], isFalse);

      controller.handleEvent(
        vm.Event(
          kind: vm.EventKind.kExtension,
          extensionKind: 'bloc_signal.onClose',
          extensionData: vm.ExtensionData()..data.addAll({'hashCode': 2001}),
          timestamp: 2000,
        ),
      );

      expect(controller.instances.first['isClosed'], isTrue);
      controller.dispose();
    });

    test(
      'handleEvent processes onTransition and updates state and history',
      () async {
        final controller = BlocSignalsDevToolsController(
          callExtensionRpc: (method, [args]) async => {
            'instances': [
              {
                'hashCode': 3001,
                'name': 'CounterCubit',
                'stateValue': '0',
                'isClosed': false,
              },
            ],
          },
        );

        await controller.fetchInstances();

        controller.handleEvent(
          vm.Event(
            kind: vm.EventKind.kExtension,
            extensionKind: 'bloc_signal.onTransition',
            extensionData: vm.ExtensionData()
              ..data.addAll({
                'hashCode': 3001,
                'event': 'Increment',
                'currentState': '0',
                'nextState': '1',
                'timestamp': 1000000,
              }),
            timestamp: 1000,
          ),
        );

        expect(controller.instances.first['stateValue'], equals('1'));
        expect(controller.history.length, equals(1));
        expect(controller.history.first['type'], equals('transition'));
        final data = controller.history.first['data'] as Map<String, dynamic>;
        expect(data['event'], equals('Increment'));

        controller.dispose();
      },
    );

    test('handleEvent processes onChange and updates state', () async {
      final controller = BlocSignalsDevToolsController(
        callExtensionRpc: (method, [args]) async => {
          'instances': [
            {
              'hashCode': 4001,
              'name': 'ValueCubit',
              'stateValue': 'A',
              'isClosed': false,
            },
          ],
        },
      );

      await controller.fetchInstances();

      controller.handleEvent(
        vm.Event(
          kind: vm.EventKind.kExtension,
          extensionKind: 'bloc_signal.onChange',
          extensionData: vm.ExtensionData()
            ..data.addAll({
              'hashCode': 4001,
              'currentState': 'A',
              'nextState': 'B',
            }),
          timestamp: 1000,
        ),
      );

      expect(controller.instances.first['stateValue'], equals('B'));
      controller.dispose();
    });

    test('handleEvent processes onError and records in history', () {
      final controller = BlocSignalsDevToolsController(
        callExtensionRpc: (method, [args]) async => {},
      )
        ..handleEvent(
          vm.Event(
            kind: vm.EventKind.kExtension,
            extensionKind: 'bloc_signal.onError',
            extensionData: vm.ExtensionData()
              ..data.addAll({
                'hashCode': 5001,
                'error': 'StateError: Invalid transition',
                'stackTrace': 'trace line 1\ntrace line 2',
              }),
            timestamp: 1000,
          ),
        )
        ..handleEvent(
          vm.Event(
            kind: vm.EventKind.kExtension,
            extensionKind: 'bloc_signal.onError',
            extensionData: vm.ExtensionData()
              ..data.addAll({
                'hashCode': 5001,
                'timestamp': 1000000,
                'error': 'StateError: Timestamped transition',
                'stackTrace': 'trace line 3',
              }),
            timestamp: 2000,
          ),
        );

      expect(controller.history.length, equals(2));
      expect(controller.history.first['type'], equals('error'));
      final data = controller.history.first['data'] as Map<String, dynamic>;
      expect(
        data['error'],
        equals('StateError: Timestamped transition'),
      );

      controller.dispose();
    });

    test('handleEvent processes onTelemetry and records in history', () {
      final controller = BlocSignalsDevToolsController(
        callExtensionRpc: (method, [args]) async => {},
      )
        ..handleEvent(
          vm.Event(
            kind: vm.EventKind.kExtension,
            extensionKind: 'bloc_signal.onTelemetry',
            extensionData: vm.ExtensionData()
              ..data.addAll({
                'hashCode': 6001,
                'name': 'bloc.event',
                'event': 'AddCartItem',
                'metadata': {'itemId': '123'},
              }),
            timestamp: 1000,
          ),
        )
        ..handleEvent(
          vm.Event(
            kind: vm.EventKind.kExtension,
            extensionKind: 'bloc_signal.onTelemetry',
            extensionData: vm.ExtensionData()
              ..data.addAll({
                'hashCode': 6001,
                'timestamp': 1000000,
                'name': 'bloc.transition',
                'event': 'Checkout',
                'metadata': {'total': 99},
              }),
            timestamp: 2000,
          ),
        );

      expect(controller.history.length, equals(2));
      expect(controller.history.first['type'], equals('telemetry'));
      final data = controller.history.first['data'] as Map<String, dynamic>;
      expect(data['name'], equals('bloc.transition'));

      controller.dispose();
    });

    test('handleEvent ignores non-bloc_signal and null events', () {
      final controller = BlocSignalsDevToolsController(
        callExtensionRpc: (method, [args]) async => {},
      )
        ..handleEvent(
          vm.Event(
            kind: vm.EventKind.kExtension,
            extensionKind: 'flutter.frame',
            timestamp: 1000,
          ),
        )
        ..handleEvent(
          vm.Event(
            kind: vm.EventKind.kExtension,
            timestamp: 1000,
          ),
        );

      expect(controller.history, isEmpty);
      controller.dispose();
    });

    test(
      'strictly enforces maxHistory bound on live and bulk historical fetches',
      () async {
        const maxHistory = 5;
        final controller = BlocSignalsDevToolsController(
          callExtensionRpc: (method, [args]) async {
            // Bulk return 10 historical items
            return {
              'history': List.generate(
                10,
                (i) => {
                  'hashCode': 7001,
                  'type': 'transition',
                  'timestamp': '2026-09-24T12:00:0$i.000Z',
                  'data': {'event': 'Event$i'},
                },
              ),
            };
          },
          maxHistory: maxHistory,
        );

        // Bulk fetch 10 items
        await controller.fetchHistoryForInstance(7001);

        // Must be strictly capped at maxHistory
        expect(controller.history.length, equals(maxHistory));

        // Adding live events also keeps history strictly capped at maxHistory
        for (var i = 0; i < 5; i++) {
          controller.handleEvent(
            vm.Event(
              kind: vm.EventKind.kExtension,
              extensionKind: 'bloc_signal.onTransition',
              extensionData: vm.ExtensionData()
                ..data.addAll({
                  'hashCode': 7001,
                  'event': 'LiveEvent$i',
                  'nextState': '$i',
                }),
              timestamp: 2000 + i,
            ),
          );
        }

        expect(controller.history.length, equals(maxHistory));
        controller.dispose();
      },
    );

    test(
      'fetchHistoryForInstance deduplicates and handles RPC failures',
      () async {
        var callIndex = 0;
        final controller = BlocSignalsDevToolsController(
          callExtensionRpc: (method, [args]) async {
            callIndex++;
            if (callIndex == 1) {
              return {
                'history': [
                  {
                    'hashCode': 9001,
                    'type': 'transition',
                    'timestamp': '2026-09-24T12:00:00.000Z',
                    'data': {'event': 'Initial'},
                  },
                  {
                    'hashCode': 9002, // Different hashCode, same timestamp
                    'type': 'transition',
                    'timestamp': '2026-09-24T12:00:00.000Z',
                    'data': {'event': 'OtherInstance'},
                  },
                ],
              };
            } else if (callIndex == 2) {
              // Returns duplicate of 9001
              return {
                'history': [
                  {
                    'hashCode': 9001,
                    'type': 'transition',
                    'timestamp': '2026-09-24T12:00:00.000Z',
                    'data': {'event': 'Initial'},
                  },
                ],
              };
            } else {
              throw Exception('Network disconnected');
            }
          },
        );

        await controller.fetchHistoryForInstance(9001);
        expect(controller.history.length, equals(2));

        // Second call has duplicate entry, length remains 2
        await controller.fetchHistoryForInstance(9001);
        expect(controller.history.length, equals(2));

        // Third call throws exception, gracefully caught
        await controller.fetchHistoryForInstance(9001);
        expect(controller.history.length, equals(2));

        controller.dispose();
      },
    );

    test('reset clears buffers and state cleanly', () async {
      final controller = BlocSignalsDevToolsController(
        callExtensionRpc: (method, [args]) async => {
          'instances': [
            {'hashCode': 8001, 'name': 'Cubit'},
          ],
        },
      );

      await controller.fetchInstances();
      expect(controller.instances, isNotEmpty);

      controller.reset();

      expect(controller.instances, isEmpty);
      expect(controller.history, isEmpty);
      expect(controller.isLoading, isFalse);
      expect(controller.errorMessage, isNull);

      controller.dispose();
    });
  });
}
