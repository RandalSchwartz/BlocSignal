import 'dart:async';

import 'package:bloc_signals_genui/bloc_signals_genui.dart';
import 'package:test/test.dart';

void main() {
  const minimalCatalogId =
      'https://a2ui.org/specification/v0_9/catalogs/minimal/minimal_catalog.json';

  group('Adversarial Reproduction Tests', () {
    test(
        'Reproduction Blocker 4: Updating an existing form field must trigger a new state emission',
        () {
      final bloc = A2uiSurfaceBloc();
      final states = <A2uiSurfaceState>[];
      bloc.state.subscribe(states.add);

      // Create surface
      bloc.add(
        const ProcessJsonMessage({
          'version': 'v0.9',
          'createSurface': {
            'surfaceId': 'form_surf',
            'catalogId': minimalCatalogId,
          },
        }),
      );

      // Add initial field
      bloc.add(
        const UpdateFormField(
          path: '/destination',
          value: 'Tokyo',
          surfaceId: 'form_surf',
        ),
      );

      final stateCountAfterFirstField = states.length;

      // Update the SAME field with a different value (same map length!)
      bloc.add(
        const UpdateFormField(
          path: '/destination',
          value: 'Kyoto',
          surfaceId: 'form_surf',
        ),
      );

      // If equality only checks length, this fails because states.length doesn't increase!
      expect(
        states.length,
        greaterThan(stateCountAfterFirstField),
        reason:
            'Modifying an existing form key must emit a distinct state transition',
      );
      final latest = bloc.value as SurfaceReady;
      expect(latest.formValues['destination'], equals('Kyoto'));
    });

    test(
        'Reproduction Blocker 2: Stream-level error must emit SurfaceError without crashing isolate',
        () async {
      final bloc = A2uiSurfaceBloc();
      final streamController = StreamController<dynamic>();

      bloc.add(IngestStream(streamController.stream));

      // Emit a stream error (not a chunk error)
      streamController.addError(Exception('Network socket broken'));
      await streamController.close();

      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(bloc.value, isA<SurfaceError>());
      final err = bloc.value as SurfaceError;
      expect(err.error.toString(), contains('Network socket broken'));

      await bloc.close();
    });

    test(
        'Reproduction Blocker 3: Closing bloc cancels active stream subscription immediately',
        () async {
      final bloc = A2uiSurfaceBloc();
      var cancelled = false;
      final streamController = StreamController<dynamic>(
        onCancel: () {
          cancelled = true;
        },
      );

      bloc.add(IngestStream(streamController.stream));
      await Future<void>.delayed(Duration.zero);

      await bloc.close();
      await Future<void>.delayed(Duration.zero);

      expect(
        cancelled,
        isTrue,
        reason: 'bloc.close() must cancel active stream subscription',
      );
      await streamController.close();
    });

    test(
        'Reproduction Blocker 1 (Iteration 3): UpdateComponentsMessage must increment version and emit distinct SurfaceReady',
        () {
      final bloc = A2uiSurfaceBloc();
      final states = <A2uiSurfaceState>[];
      bloc.state.subscribe(states.add);

      bloc.add(
        const ProcessJsonMessage({
          'version': 'v0.9',
          'createSurface': {
            'surfaceId': 'dynamic_surf',
            'catalogId': minimalCatalogId,
          },
        }),
      );

      final stateCountAfterCreate = states.length;

      // Add a component to existing surface
      bloc.add(
        const ProcessJsonMessage({
          'version': 'v0.9',
          'updateComponents': {
            'surfaceId': 'dynamic_surf',
            'components': [
              {
                'id': 'txt1',
                'component': 'Text',
                'properties': {'text': 'Dynamic Message'},
              },
            ],
          },
        }),
      );

      expect(
        states.length,
        greaterThan(stateCountAfterCreate),
        reason:
            'Updating components must emit a distinct state transition via version increment',
      );
      final ready = bloc.value as SurfaceReady;
      expect(ready.version, greaterThan(0));
      expect(
        ready.surface.componentsModel.all.any((c) => c.id == 'txt1'),
        isTrue,
      );
    });

    test(
        'Reproduction Blocker 2 (Iteration 3): Preempting an in-flight stream resolves the previous handler future',
        () async {
      final bloc = A2uiSurfaceBloc();
      final firstStreamController = StreamController<dynamic>();
      final secondStreamController = StreamController<dynamic>();

      // Start first stream
      bloc.add(IngestStream(firstStreamController.stream));
      await Future<void>.delayed(Duration.zero);

      // Preempt with second stream
      bloc.add(IngestStream(secondStreamController.stream));
      await Future<void>.delayed(Duration.zero);

      // Second stream completes cleanly
      await secondStreamController.close();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(bloc.isClosed, isFalse);
      await bloc.close();
      await firstStreamController.close();
    });
  });
}
