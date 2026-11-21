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

    test(
      '(Issue #340, Issue #474: F07) fetchInstances catches RPC errors '
      'gracefully and resets isLoading and reentrancy lock via finally',
      () async {
        final controller = BlocSignalsDevToolsController(
          callExtensionRpc: (method, [args]) async {
            throw StateError('Fatal programmer invariant in RPC handler');
          },
        );
        addTearDown(controller.dispose);

        await controller.fetchInstances();
        expect(controller.isLoading, isFalse);
        expect(controller.errorMessage, isNotNull);
      },
    );

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

    test(
      '(Issue #340, Issue #474: F07) fetchHistoryForInstance handles '
      'Exception, StateError, and malformed history payloads gracefully',
      () async {
        var callMode = 'exception';
        final controller = BlocSignalsDevToolsController(
          callExtensionRpc: (method, [args]) async {
            if (callMode == 'exception') {
              throw Exception('RPC network timeout');
            }
            if (callMode == 'state_error') {
              throw StateError('fatal state bug');
            }
            // Returns malformed 'history' value
            return {'history': 42};
          },
        );
        addTearDown(controller.dispose);

        // 1. Recoverable Exception is caught and falls back gracefully
        await controller.fetchHistoryForInstance(9001);
        expect(controller.history, isEmpty);

        // 2. StateError is caught without wedging controller
        callMode = 'state_error';
        await controller.fetchHistoryForInstance(9001);
        expect(controller.history, isEmpty);

        // 3. Malformed JSON value is safely ignored without throwing TypeError
        callMode = 'type_error';
        await controller.fetchHistoryForInstance(9001);
        expect(controller.history, isEmpty);
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

    test(
      '(Issue #474: F07) malformed instances, history, and event payloads '
      'do not throw TypeError and reset isLoading == false',
      () async {
        final controller = BlocSignalsDevToolsController(
          callExtensionRpc: (method, [args]) async {
            if (method == 'ext.bloc_signal.getInstances') {
              return {
                'instances': [
                  'bad_entry',
                  {'hashCode': 1, 'type': 'TestCubit', 'stateValue': '0'},
                ],
              };
            }
            return {
              'history': [
                123,
                {
                  'hashCode': 1,
                  'type': 'transition',
                  'timestamp': '2026-11-20T00:00:00.000Z',
                  'data': {'event': 'inc'},
                },
              ],
            };
          },
        );
        addTearDown(controller.dispose);

        await controller.fetchInstances();
        expect(controller.isLoading, isFalse);
        expect(controller.instances.length, equals(1));

        // Non-List 'instances' payload resets to empty list without throwing.
        final nonListController = BlocSignalsDevToolsController(
          callExtensionRpc: (method, [args]) async => {'instances': 42},
        );
        addTearDown(nonListController.dispose);
        await nonListController.fetchInstances();
        expect(nonListController.isLoading, isFalse);
        expect(nonListController.instances, isEmpty);

        await controller.fetchHistoryForInstance(1);
        expect(controller.history.length, equals(1));

        // Malformed vm.Event fields (non-int hashCode, non-num timestamp)
        expect(
          () => controller.handleEvent(
            vm.Event(
              kind: 'Extension',
              extensionKind: 'bloc_signal.onTransition',
              extensionData: vm.ExtensionData()
                ..data.addAll({
                  'hashCode': 'not-an-int',
                  'timestamp': 'not-a-num',
                  'event': 'inc',
                  'nextState': '1',
                }),
            ),
          ),
          returnsNormally,
        );
        expect(
          () => controller.handleEvent(
            vm.Event(
              kind: 'Extension',
              extensionKind: 'bloc_signal.onError',
              extensionData: vm.ExtensionData()
                ..data.addAll({
                  'hashCode': 'not-an-int',
                  'timestamp': 'bad',
                  'error': 'err',
                }),
            ),
          ),
          returnsNormally,
        );
        expect(
          () => controller.handleEvent(
            vm.Event(
              kind: 'Extension',
              extensionKind: 'bloc_signal.onTelemetry',
              extensionData: vm.ExtensionData()
                ..data.addAll({
                  'hashCode': 'not-an-int',
                  'timestamp': 'bad',
                  'name': 'metric',
                }),
            ),
          ),
          returnsNormally,
        );
      },
    );

    test(
      '(Issue #474: F08) disposing controller mid-await or during stream '
      'errors does not call notifyListeners() after dispose',
      () async {
        final rpcCompleter = Completer<Map<String, dynamic>>();
        final controller = BlocSignalsDevToolsController(
          callExtensionRpc: (method, [args]) => rpcCompleter.future,
        );

        var notifications = 0;
        controller.addListener(() {
          notifications++;
        });

        final streamController = StreamController<vm.Event>();
        addTearDown(streamController.close);
        controller.attachEventStream(streamController.stream);

        // Trigger stream error — must be handled by onError without crashing
        streamController.addError(Exception('stream failure'));
        await Future<void>.delayed(Duration.zero);

        final fetchFuture = controller.fetchInstances();
        final notificationsBeforeDispose = notifications;
        controller.dispose();

        rpcCompleter.complete({'instances': <dynamic>[]});
        await fetchFuture;

        expect(notifications, equals(notificationsBeforeDispose));

        // Every post-dispose early-return branch:
        controller
          ..attachEventStream(streamController.stream)
          ..reset()
          ..handleEvent(
            vm.Event(
              kind: 'Extension',
              extensionKind: 'bloc_signal.onTransition',
            ),
          );
        await controller.fetchHistoryForInstance(1);
      },
    );

    test(
      '(Issue #474: BLOCKER-2, BLOCKER-5) _parseTimestamp rejects NaN, '
      'Infinity, and out-of-range timestamps, and post-dispose async '
      'errors/completions do not notifyListeners',
      () async {
        final historyCompleter = Completer<Map<String, dynamic>>();
        final errorCompleter = Completer<Map<String, dynamic>>();
        var mode = 'history';

        final controller = BlocSignalsDevToolsController(
          callExtensionRpc: (method, [args]) {
            if (mode == 'history') return historyCompleter.future;
            return errorCompleter.future;
          },
        );
        var notifications = 0;
        controller.addListener(() => notifications++);

        // Non-finite and out-of-range timestamps
        final before = DateTime.now().subtract(const Duration(seconds: 5));
        for (final badTs in <dynamic>[
          double.nan,
          double.infinity,
          double.negativeInfinity,
          1e25,
          -1e25,
        ]) {
          controller.handleEvent(
            vm.Event(
              kind: 'Extension',
              extensionKind: 'bloc_signal.onTransition',
              extensionData: vm.ExtensionData()
                ..data.addAll({
                  'hashCode': 1,
                  'timestamp': badTs,
                  'event': 'ev',
                  'nextState': '1',
                }),
            ),
          );
        }
        final after = DateTime.now().add(const Duration(seconds: 5));
        expect(controller.history.length, equals(5));
        for (final entry in controller.history) {
          final parsed = DateTime.parse(entry['timestamp'] as String);
          expect(parsed.isAfter(before), isTrue);
          expect(parsed.isBefore(after), isTrue);
        }

        // Dispose while fetchHistoryForInstance is in flight
        final histFut = controller.fetchHistoryForInstance(1);
        mode = 'error';
        final fetchErrFut = controller.fetchInstances();
        final beforeDispose = notifications;
        controller.dispose();

        // Calling fetchInstances after dispose is a safe no-op
        await controller.fetchInstances();

        historyCompleter.complete({'history': <dynamic>[]});
        errorCompleter.completeError(StateError('late error'));
        await histFut;
        await fetchErrFut;
        expect(notifications, equals(beforeDispose));
      },
    );

    test(
      '(Issue #474: BLOCKER-1) stream onError after dispose does not call '
      'notifyListeners',
      () async {
        final controller = BlocSignalsDevToolsController(
          callExtensionRpc: (method, [args]) async =>
              {'instances': <dynamic>[]},
        );
        var notifications = 0;
        controller.addListener(() => notifications++);

        late StreamController<vm.Event> sc;
        sc = StreamController<vm.Event>(
          onCancel: () async {
            // Delay cancel slightly so error arrives while _isDisposed is true
            await Future<void>.delayed(const Duration(milliseconds: 10));
          },
        );
        addTearDown(sc.close);
        controller.attachEventStream(sc.stream);

        final beforeDispose = notifications;
        controller.dispose();
        sc.addError(Exception('late stream error'));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(notifications, equals(beforeDispose));
      },
    );

    test(
      '(Issue #474: BLOCKER-2) reconnect fetchInstances and stale '
      'fetchHistoryForInstance across reset() discard stale responses without '
      'clearing new fetch state',
      () async {
        final rpc1 = Completer<Map<String, dynamic>>();
        final rpc2 = Completer<Map<String, dynamic>>();
        final histRpc = Completer<Map<String, dynamic>>();
        var callIndex = 0;

        final controller = BlocSignalsDevToolsController(
          callExtensionRpc: (method, [args]) {
            if (method == 'ext.bloc_signal.getHistory') return histRpc.future;
            callIndex++;
            return callIndex == 1 ? rpc1.future : rpc2.future;
          },
        );
        addTearDown(controller.dispose);

        // Start fetch 1 and history fetch, then reset() mid-flight
        final f1 = controller.fetchInstances();
        final h1 = controller.fetchHistoryForInstance(1);
        controller.reset();

        // Reconnect: start fetch 2 immediately after reset()
        final f2 = controller.fetchInstances();
        expect(controller.isLoading, isTrue);

        // Stale fetch 1 and stale history complete first — must NOT clear
        // fetch 2's isLoading or populate stale data!
        rpc1.complete({
          'instances': [
            {'hashCode': 1, 'type': 'StaleCubit', 'stateValue': '0'},
          ],
        });
        histRpc.complete({
          'history': [
            {
              'hashCode': 1,
              'type': 'transition',
              'timestamp': '2026-11-20T00:00:00.000Z',
              'data': {'event': 'stale'},
            },
          ],
        });
        await f1;
        await h1;

        expect(controller.isLoading, isTrue);
        expect(controller.instances, isEmpty);
        expect(controller.history, isEmpty);

        // Fetch 2 completes — populates fresh instances and clears isLoading
        rpc2.complete({
          'instances': [
            {'hashCode': 2, 'type': 'FreshCubit', 'stateValue': '1'},
          ],
        });
        await f2;

        expect(controller.isLoading, isFalse);
        expect(controller.instances.length, equals(1));
        expect(controller.instances.first['type'], equals('FreshCubit'));
      },
    );

    test(
      '(Issue #474: NBO-3) fetchInstances discards stale in-flight responses '
      'after reset()',
      () async {
        final completer = Completer<Map<String, dynamic>>();
        final controller = BlocSignalsDevToolsController(
          callExtensionRpc: (method, [args]) => completer.future,
        );
        addTearDown(controller.dispose);

        final fetchFuture = controller.fetchInstances();
        controller.reset();
        completer.complete({
          'instances': [
            {'hashCode': 99, 'type': 'StaleCubit', 'stateValue': '0'},
          ],
        });
        await fetchFuture;

        expect(controller.instances, isEmpty);
        expect(controller.isLoading, isFalse);
      },
    );
  });
}
