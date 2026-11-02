import 'dart:async';
import 'dart:convert';

import 'package:bloc_signals_genui/bloc_signals_genui.dart';
import 'package:blocsignal_website/src/components/playground/playground_cubit.dart';
import 'package:blocsignal_website/src/components/playground/playground_editor.dart';
import 'package:blocsignal_website/src/components/playground/playground_inspector.dart';
import 'package:blocsignal_website/src/components/playground/playground_scenarios.dart';
import 'package:blocsignal_website/src/pages/playground_page.dart';
import 'package:test/test.dart';

void main() {
  group('(Issue #398) Preloaded Playground Scenarios', () {
    test(
      'contains all 4 expected preloaded scenarios with non-empty metadata',
      () {
        final scenarios = PlaygroundScenarios.all;
        expect(scenarios.length, equals(4));

        final ids = scenarios.map((s) => s.id).toList();
        expect(
          ids,
          containsAll([
            'flight-booking',
            'survey-form',
            'counter-card',
            'multi-surface',
          ]),
        );

        for (final scenario in scenarios) {
          expect(scenario.id, isNotEmpty);
          expect(scenario.name, isNotEmpty);
          expect(scenario.description, isNotEmpty);
          expect(scenario.jsonPayload, isNotEmpty);
        }
      },
    );

    test('all 4 scenarios parse into valid JSON lists of A2UI messages', () {
      for (final scenario in PlaygroundScenarios.all) {
        final decoded = jsonDecode(scenario.jsonPayload);
        expect(
          decoded,
          isA<List<dynamic>>(),
          reason: 'Scenario ${scenario.id} must be a JSON array of messages',
        );

        final messageList = (decoded as List<dynamic>)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();

        expect(
          messageList,
          isNotEmpty,
          reason: 'Scenario ${scenario.id} must contain at least one message',
        );

        // Verify each message has an A2UI version tag
        for (final msg in messageList) {
          expect(
            msg['version'],
            isNotNull,
            reason: 'Message in ${scenario.id} missing version property',
          );
        }
      }
    });

    test('all 4 scenarios ingest into A2uiSurfaceBloc without crashing', () async {
      for (final scenario in PlaygroundScenarios.all) {
        final bloc = A2uiSurfaceBloc();
        final decoded = jsonDecode(scenario.jsonPayload) as List<dynamic>;

        for (final item in decoded) {
          final msgMap = Map<String, dynamic>.from(item as Map);
          bloc.add(ProcessJsonMessage(msgMap));
        }

        // Wait for event loop to settle
        await Future<void>.delayed(const Duration(milliseconds: 20));

        // Surface state should be ready or streaming, not error
        expect(
          bloc.stateValue,
          isNot(isA<SurfaceError>()),
          reason:
              'Scenario ${scenario.id} resulted in SurfaceError: ${bloc.stateValue}',
        );

        bloc.close();
      }
    });
  });

  group('(Issue #398) PlaygroundCubit State Machine', () {
    late PlaygroundCubit cubit;

    setUp(() {
      cubit = PlaygroundCubit();
    });

    tearDown(() {
      cubit.close();
    });

    test(
      'initializes with default scenario, valid rawJson, and empty action log',
      () {
        final state = cubit.stateValue;
        expect(state.selectedScenario.id, equals('flight-booking'));
        expect(state.rawJson, equals(state.selectedScenario.jsonPayload));
        expect(state.isStreaming, isFalse);
        expect(state.parseError, isNull);
        expect(state.actionLog, isEmpty);
        expect(cubit.surfaceBloc.isClosed, isFalse);
      },
    );

    test('selecting a scenario updates selectedScenario, rawJson, and resets state', () {
      final surveyScenario = PlaygroundScenarios.all.firstWhere(
        (s) => s.id == 'survey-form',
      );

      cubit.selectScenario(surveyScenario);

      final state = cubit.stateValue;
      expect(state.selectedScenario.id, equals('survey-form'));
      expect(state.rawJson, equals(surveyScenario.jsonPayload));
      expect(state.parseError, isNull);
      expect(state.actionLog, isEmpty);
    });

    test('updating rawJson detects syntax errors and clears them upon fix', () {
      cubit.updateJson('{"invalid json": ');
      expect(cubit.stateValue.parseError, isNotNull);

      // Restore valid JSON
      cubit.updateJson(PlaygroundScenarios.counterCard.jsonPayload);
      expect(cubit.stateValue.parseError, isNull);
      expect(
        cubit.stateValue.rawJson,
        equals(PlaygroundScenarios.counterCard.jsonPayload),
      );
    });

    test(
      'renderInstant parses valid JSON and populates surfaceBloc synchronously',
      () async {
        cubit.selectScenario(PlaygroundScenarios.counterCard);
        await cubit.renderInstant();

        expect(cubit.stateValue.parseError, isNull);
        expect(cubit.surfaceBloc.stateValue, isA<SurfaceReady>());
        final ready = cubit.surfaceBloc.stateValue as SurfaceReady;
        expect(ready.surfaceId, equals('counter-card'));
      },
    );

    test(
      'renderInstant sets parseError when invalid JSON is supplied',
      () async {
        cubit.updateJson('{bad json}');
        await cubit.renderInstant();

        expect(cubit.stateValue.parseError, isNotNull);
      },
    );

    test(
      'startStreaming simulates progressive chunk ingestion and completes',
      () async {
        cubit.selectScenario(PlaygroundScenarios.counterCard);
        final streamFuture = cubit.startStreaming(
          chunkDelay: const Duration(milliseconds: 5),
        );

        expect(cubit.stateValue.isStreaming, isTrue);

        await streamFuture;

        expect(cubit.stateValue.isStreaming, isFalse);
        expect(cubit.surfaceBloc.stateValue, isA<SurfaceReady>());
      },
    );

    test('cancelStreaming halts active streaming emulation', () async {
      cubit.selectScenario(PlaygroundScenarios.flightBooking);
      // Fire without awaiting
      unawaited(
        cubit.startStreaming(chunkDelay: const Duration(milliseconds: 100)),
      );

      expect(cubit.stateValue.isStreaming, isTrue);

      cubit.cancelStreaming();
      expect(cubit.stateValue.isStreaming, isFalse);
    });

    test('recordAction appends action entries to actionLog', () {
      expect(cubit.stateValue.actionLog, isEmpty);

      cubit.recordAction(
        const PlaygroundActionEntry(
          actionName: 'confirm_booking',
          surfaceId: 'flight-booking',
          sourceComponentId: 'btn-confirm',
          payload: {'flight': 'PR-774'},
        ),
      );

      expect(cubit.stateValue.actionLog.length, equals(1));
      final entry = cubit.stateValue.actionLog.first;
      expect(entry.actionName, equals('confirm_booking'));
      expect(entry.surfaceId, equals('flight-booking'));
      expect(entry.sourceComponentId, equals('btn-confirm'));
      expect(entry.payload['flight'], equals('PR-774'));
    });

    test('reset clears actionLog and reloads current scenario', () async {
      cubit.recordAction(
        const PlaygroundActionEntry(actionName: 'test', surfaceId: 'test'),
      );
      expect(cubit.stateValue.actionLog, isNotEmpty);

      await cubit.reset();

      expect(cubit.stateValue.actionLog, isEmpty);
      expect(cubit.stateValue.parseError, isNull);
      expect(cubit.stateValue.isStreaming, isFalse);
    });

    test('startStreaming sets parseError on invalid JSON', () async {
      cubit.updateJson('{invalid json');
      await cubit.startStreaming();

      expect(cubit.stateValue.parseError, isNotNull);
      expect(cubit.stateValue.isStreaming, isFalse);
    });
  });

  group('(Issue #398) Playground Components Instantiation', () {
    test('PlaygroundPage, PlaygroundInspector, and PlaygroundEditor instantiate cleanly', () {
      const page = PlaygroundPage();
      expect(page, isNotNull);

      final cubit = PlaygroundCubit();
      final inspector = PlaygroundInspector(cubit: cubit);
      expect(inspector, isNotNull);

      final editor = PlaygroundEditor(cubit: cubit, state: cubit.stateValue);
      expect(editor, isNotNull);

      cubit.close();
    });
  });
}
