import 'package:bloc_signals_devtools/bloc_signals_devtools.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final sampleInstances = [
    {
      'hashCode': 1001,
      'type': 'CounterCubit',
      'stateValue': '42',
      'isClosed': false,
    },
    {
      'hashCode': 1002,
      'type': 'AuthBloc',
      'stateValue': 'Authenticated',
      'isClosed': false,
    },
    {
      'hashCode': 1003,
      'type': 'LegacyBloc',
      'stateValue': '0',
      'isClosed': true,
    },
  ];

  final sampleHistory = [
    {
      'hashCode': 1001,
      'type': 'transition',
      'timestamp': '2026-07-23T12:00:00.000',
      'data': {'event': 'increment', 'nextState': '42'},
    },
    {
      'hashCode': 1002,
      'type': 'error',
      'timestamp': '2026-07-23T12:01:00.000',
      'data': {'error': 'NetworkException'},
    },
  ];

  group('DevTools Extension UI Components', () {
    testWidgets('InstanceTreeView filters items by search query',
        (tester) async {
      Map<String, dynamic>? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InstanceTreeView(
              instances: sampleInstances,
              onSelectInstance: (item) => selected = item,
            ),
          ),
        ),
      );

      expect(find.text('CounterCubit'), findsOneWidget);
      expect(find.text('AuthBloc'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('instance_search_field')),
        'Counter',
      );
      await tester.pump();

      expect(find.text('CounterCubit'), findsOneWidget);
      expect(find.text('AuthBloc'), findsNothing);

      await tester.tap(find.text('CounterCubit'));
      expect(selected?['hashCode'], equals(1001));
    });

    testWidgets('TimelineTracePanel renders history entries', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TimelineTracePanel(history: sampleHistory),
          ),
        ),
      );

      expect(find.text('TRANSITION'), findsOneWidget);
      expect(find.text('ERROR'), findsOneWidget);
      expect(find.text('Event: increment'), findsOneWidget);
      expect(find.text('Error: NetworkException'), findsOneWidget);
    });

    testWidgets('StateDiffInspector highlights mutated state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StateDiffInspector(
              currentState: '0',
              nextState: '1',
            ),
          ),
        ),
      );

      expect(find.text('State Transition Diff'), findsOneWidget);
      expect(find.text('Mutated'), findsOneWidget);
      expect(find.text('Current State (-)'), findsOneWidget);
      expect(find.text('Next State (+)'), findsOneWidget);
    });

    testWidgets('LeakDetectorBadge displays active and closed counts',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LeakDetectorBadge(instances: sampleInstances),
          ),
        ),
      );

      expect(find.text('Active: 2 | Closed: 1'), findsOneWidget);
    });

    testWidgets(
        'BlocSignalsDevToolsExtension filters history by selected container',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocSignalsDevToolsExtension(
            instances: sampleInstances,
            history: sampleHistory,
          ),
        ),
      );

      // Select CounterCubit (hashCode 1001)
      await tester.tap(find.text('CounterCubit'));
      await tester.pump();

      // Only transition for 1001 should be displayed
      expect(find.text('Event: increment'), findsOneWidget);
      expect(find.text('Error: NetworkException'), findsNothing);
    });

    testWidgets(
        'tapping history entry in TimelineTracePanel updates '
        'StateDiffInspector', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlocSignalsDevToolsExtension(
            instances: sampleInstances,
            history: const [
              {
                'hashCode': 1001,
                'type': 'transition',
                'timestamp': '2026-07-23T12:00:00.000',
                'data': {
                  'event': 'increment',
                  'currentState': '41',
                  'nextState': '42',
                },
              },
            ],
          ),
        ),
      );

      // Select container
      await tester.tap(find.text('CounterCubit'));
      await tester.pump();

      // Tap history entry
      await tester.tap(find.byKey(const Key('history_entry_0')));
      await tester.pump();

      expect(find.text('41'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('BlocSignalsDevToolsExtension displays progress when isLoading',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BlocSignalsDevToolsExtension(
            isLoading: true,
          ),
        ),
      );

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets(
        'BlocSignalsDevToolsExtension displays error banner and handles RETRY',
        (tester) async {
      var refreshed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: BlocSignalsDevToolsExtension(
            errorMessage: 'Connection lost to VM Service',
            onRefresh: () => refreshed = true,
          ),
        ),
      );

      expect(find.text('Connection lost to VM Service'), findsOneWidget);
      expect(find.text('RETRY'), findsOneWidget);

      await tester.tap(find.text('RETRY'));
      await tester.pump();

      expect(refreshed, isTrue);
    });

    testWidgets('BlocSignalsDevToolsExtension displays empty container message',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: BlocSignalsDevToolsExtension(),
        ),
      );

      expect(
        find.textContaining('No active BlocSignal containers detected.'),
        findsOneWidget,
      );
    });

    testWidgets(
        'BlocSignalsDevToolsExtension triggers onRefresh and onSelectInstance',
        (tester) async {
      var refreshed = false;
      Map<String, dynamic>? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: BlocSignalsDevToolsExtension(
            instances: sampleInstances,
            onRefresh: () => refreshed = true,
            onSelectInstance: (item) => selected = item,
          ),
        ),
      );

      expect(find.byTooltip('Refresh Containers'), findsOneWidget);
      await tester.tap(find.byTooltip('Refresh Containers'));
      await tester.pump();
      expect(refreshed, isTrue);

      await tester.tap(find.text('CounterCubit'));
      await tester.pump();
      expect(selected?['hashCode'], equals(1001));
    });
  });
}
