import 'dart:async';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:bloc_signals_genui/bloc_signals_genui.dart';
import 'package:bloc_signals_test/bloc_signals_test.dart';
import 'package:test/test.dart';

void main() {
  const minimalCatalogId =
      'https://a2ui.org/specification/v0_9/catalogs/minimal/minimal_catalog.json';

  group('A2uiSurfaceBloc', () {
    test('initial state is SurfaceInitial', () {
      final bloc = A2uiSurfaceBloc();
      expect(bloc.stateValue, isA<SurfaceInitial>());
      expect(bloc.value, isA<SurfaceInitial>());
      expect(bloc.state.value, isA<SurfaceInitial>());
    });

    test('exposes catalogs and processor', () {
      final catalog = MinimalCatalog();
      final bloc = A2uiSurfaceBloc(catalogs: [catalog]);
      expect(bloc.catalogs, contains(catalog));
      expect(bloc.processor, isNotNull);
    });

    blocSignalTest<A2uiSurfaceBloc, A2uiSurfaceState>(
      'processes CreateSurfaceMessage and transitions to SurfaceReady',
      build: A2uiSurfaceBloc.new,
      act: (bloc) => bloc.add(
        ProcessMessage(
          CreateSurfaceMessage(
            surfaceId: 'surf_1',
            catalogId: minimalCatalogId,
          ),
        ),
      ),
      expect: () => [
        isA<SurfaceReady>().having((s) => s.surfaceId, 'surfaceId', 'surf_1'),
      ],
    );

    blocSignalTest<A2uiSurfaceBloc, A2uiSurfaceState>(
      'processes raw JSON message and updates components',
      build: A2uiSurfaceBloc.new,
      act: (bloc) {
        bloc.add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 'surf_json',
              'catalogId': minimalCatalogId,
            },
          }),
        );
        bloc.add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateComponents': {
              'surfaceId': 'surf_json',
              'components': [
                {
                  'id': 'txt_title',
                  'component': 'Text',
                  'text': 'Hello Generative UI',
                },
              ],
            },
          }),
        );
      },
      expect: () => [
        isA<SurfaceReady>()
            .having((s) => s.surfaceId, 'surfaceId', 'surf_json'),
        isA<SurfaceReady>()
            .having((s) => s.surfaceId, 'surfaceId', 'surf_json'),
      ],
      verify: (bloc) {
        final state = bloc.value as SurfaceReady;
        expect(state.surface.componentsModel.get('txt_title'), isNotNull);
        expect(
          state.surface.componentsModel.get('txt_title')!.properties['text'],
          equals('Hello Generative UI'),
        );
      },
    );

    blocSignalTest<A2uiSurfaceBloc, A2uiSurfaceState>(
      'processes batch messages via ProcessMessages',
      build: A2uiSurfaceBloc.new,
      act: (bloc) => bloc.add(
        ProcessMessages([
          CreateSurfaceMessage(
            surfaceId: 'surf_batch',
            catalogId: minimalCatalogId,
          ),
          UpdateComponentsMessage(
            surfaceId: 'surf_batch',
            components: [
              {
                'id': 'col_root',
                'component': 'Column',
                'children': <dynamic>[],
              },
            ],
          ),
        ]),
      ),
      expect: () => [
        isA<SurfaceReady>()
            .having((s) => s.surfaceId, 'surfaceId', 'surf_batch'),
      ],
    );

    blocSignalTest<A2uiSurfaceBloc, A2uiSurfaceState>(
      'emits SurfaceError on malformed JSON or unknown catalog',
      build: A2uiSurfaceBloc.new,
      act: (bloc) => bloc.add(
        const ProcessJsonMessage({
          'version': 'v0.9',
          'createSurface': {
            'surfaceId': 'surf_err',
            'catalogId': 'https://unknown.catalog.invalid',
          },
        }),
      ),
      expect: () => [
        isA<SurfaceError>(),
      ],
    );

    blocSignalTest<A2uiSurfaceBloc, A2uiSurfaceState>(
      'emits SurfaceError when ProcessMessage encounters schema error',
      build: A2uiSurfaceBloc.new,
      act: (bloc) => bloc.add(
        ProcessMessage(
          CreateSurfaceMessage(
            surfaceId: 'surf_bad_cat',
            catalogId: 'https://bad.catalog.url',
          ),
        ),
      ),
      expect: () => [
        isA<SurfaceError>(),
      ],
    );

    blocSignalTest<A2uiSurfaceBloc, A2uiSurfaceState>(
      'emits SurfaceError when ProcessMessages encounters error',
      build: A2uiSurfaceBloc.new,
      act: (bloc) => bloc.add(
        ProcessMessages([
          CreateSurfaceMessage(
            surfaceId: 'surf_batch_err',
            catalogId: 'https://bad.catalog.url',
          ),
        ]),
      ),
      expect: () => [
        isA<SurfaceError>(),
      ],
    );

    blocSignalTest<A2uiSurfaceBloc, A2uiSurfaceState>(
      'UpdateFormField synchronously mutates data model without async gaps',
      build: A2uiSurfaceBloc.new,
      act: (bloc) {
        bloc.add(
          ProcessMessage(
            CreateSurfaceMessage(
              surfaceId: 'surf_form',
              catalogId: minimalCatalogId,
            ),
          ),
        );
        bloc.add(
          const UpdateFormField(
            path: '/booking/destination',
            value: 'Tokyo',
            surfaceId: 'surf_form',
          ),
        );
      },
      verify: (bloc) {
        final ready = bloc.value as SurfaceReady;
        expect(ready.formValues['booking'], equals({'destination': 'Tokyo'}));
      },
    );

    test('UpdateFormField with null or non-existent surface is safely ignored',
        () {
      final bloc = A2uiSurfaceBloc();
      bloc.add(const UpdateFormField(path: '/key', value: 'val'));
      expect(bloc.value, isA<SurfaceInitial>());

      bloc.add(
        const UpdateFormField(
          path: '/key',
          value: 'val',
          surfaceId: 'missing',
        ),
      );
      expect(bloc.value, isA<SurfaceInitial>());
    });

    test(
        'SubmitAction emits SurfaceSubmitting and publishes A2uiActionResponse',
        () async {
      final bloc = A2uiSurfaceBloc();
      final responses = <A2uiActionResponse>[];
      final sub = bloc.actionResponses.listen(responses.add);

      bloc.add(
        ProcessMessage(
          CreateSurfaceMessage(
            surfaceId: 'surf_sub',
            catalogId: minimalCatalogId,
          ),
        ),
      );
      bloc.add(
        const UpdateFormField(
          path: '/flightId',
          value: 'NH106',
          surfaceId: 'surf_sub',
        ),
      );
      bloc.add(
        const SubmitAction(
          actionName: 'bookFlight',
          sourceComponentId: 'btn_book',
          surfaceId: 'surf_sub',
          context: {'step': 1},
        ),
      );

      await Future<void>.delayed(Duration.zero);

      expect(bloc.value, isA<SurfaceSubmitting>());
      final submitting = bloc.value as SurfaceSubmitting;
      expect(submitting.actionName, equals('bookFlight'));
      expect(submitting.surfaceId, equals('surf_sub'));
      expect(submitting.sourceComponentId, equals('btn_book'));

      expect(responses.length, equals(1));
      final response = responses.first;
      expect(response.actionName, equals('bookFlight'));
      expect(response.formData['flightId'], equals('NH106'));
      expect(response.context['step'], equals(1));

      final toolResult = response.toToolResult();
      expect(toolResult['actionName'], equals('bookFlight'));
      expect(toolResult['formData'], equals({'flightId': 'NH106'}));

      await sub.cancel();
      await bloc.close();
    });

    test('SubmitAction on non-existent surface emits SurfaceError', () {
      final bloc = A2uiSurfaceBloc();
      bloc.add(
        const SubmitAction(
          actionName: 'testAction',
          sourceComponentId: 'btn_test',
          surfaceId: 'does_not_exist',
        ),
      );
      expect(bloc.value, isA<SurfaceError>());
    });

    test('SubmitAction with no active surface emits SurfaceError', () {
      final bloc = A2uiSurfaceBloc();
      bloc.add(
        const SubmitAction(
          actionName: 'testAction',
          sourceComponentId: 'btn_test',
        ),
      );
      expect(bloc.value, isA<SurfaceError>());
    });

    blocSignalTest<A2uiSurfaceBloc, A2uiSurfaceState>(
      'ResetSurface removes surface and transitions to SurfaceInitial',
      build: A2uiSurfaceBloc.new,
      act: (bloc) {
        bloc.add(
          ProcessMessage(
            CreateSurfaceMessage(
              surfaceId: 'surf_reset',
              catalogId: minimalCatalogId,
            ),
          ),
        );
        bloc.add(const ResetSurface(surfaceId: 'surf_reset'));
        bloc.add(const ResetSurface());
      },
      expect: () => [
        isA<SurfaceReady>(),
        isA<SurfaceInitial>(),
      ],
    );

    test('IngestStream streams typed, map, and list chunks', () async {
      final bloc = A2uiSurfaceBloc();
      final streamController = StreamController<dynamic>();

      bloc.add(IngestStream(streamController.stream));
      expect(bloc.value, isA<SurfaceStreaming>());

      // Typed message chunk
      streamController.add(
        CreateSurfaceMessage(
          surfaceId: 'surf_stream',
          catalogId: minimalCatalogId,
        ),
      );

      // JSON list string chunk
      streamController.add(
        '[{"version": "v0.9", "updateComponents": {"surfaceId": "surf_stream", "components": [{"id": "txt1", "component": "Text", "text": "Streamed text"}]}}]',
      );

      // Whitespace chunk (should be ignored safely)
      streamController.add('   \n');

      // Invalid chunk type (should be ignored safely)
      streamController.add(42);

      await streamController.close();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(bloc.value, isA<SurfaceReady>());
      final ready = bloc.value as SurfaceReady;
      expect(ready.surfaceId, equals('surf_stream'));
      expect(
        ready.surface.componentsModel.get('txt1')!.properties['text'],
        equals('Streamed text'),
      );

      await bloc.close();
    });

    test('IngestStream emits SurfaceError when parse or validation fails',
        () async {
      final bloc = A2uiSurfaceBloc();
      final streamController = StreamController<dynamic>();

      bloc.add(IngestStream(streamController.stream));

      streamController.add('not valid json {');
      await streamController.close();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(bloc.value, isA<SurfaceError>());
      await bloc.close();
    });

    test(
        'restartable() aborts previous in-flight stream when new stream arrives',
        () async {
      final bloc = A2uiSurfaceBloc();
      final firstStream = StreamController<dynamic>();
      final secondStream = StreamController<dynamic>();

      bloc.add(IngestStream(firstStream.stream));
      expect(bloc.value, isA<SurfaceStreaming>());

      // Dispatch a second stream to preempt the first
      bloc.add(IngestStream(secondStream.stream));

      secondStream.add({
        'version': 'v0.9',
        'createSurface': {
          'surfaceId': 'surf_second',
          'catalogId': minimalCatalogId,
        },
      });

      await secondStream.close();
      await firstStream.close();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(bloc.value, isA<SurfaceReady>());
      expect((bloc.value as SurfaceReady).surfaceId, equals('surf_second'));

      await bloc.close();
    });

    test('StreamCompleted explicitly finalizes stream', () {
      final bloc = A2uiSurfaceBloc();
      bloc.add(
        ProcessMessage(
          CreateSurfaceMessage(
            surfaceId: 'surf_complete',
            catalogId: minimalCatalogId,
          ),
        ),
      );
      bloc.add(const StreamCompleted(surfaceId: 'surf_complete'));
      expect(bloc.value, isA<SurfaceReady>());

      bloc.add(const StreamCompleted());
      expect(bloc.value, isA<SurfaceReady>());
    });

    test('recovers first surface if activeSurfaceId is not set directly', () {
      final bloc = A2uiSurfaceBloc();
      bloc.processor.processMessages([
        CreateSurfaceMessage(
          surfaceId: 'surf_auto',
          catalogId: minimalCatalogId,
        ),
      ]);
      bloc.add(const StreamCompleted());
      expect(bloc.value, isA<SurfaceReady>());
      expect((bloc.value as SurfaceReady).surfaceId, equals('surf_auto'));
    });

    test('state model equality and toString coverage', () {
      const initial = SurfaceInitial();
      expect(initial == const SurfaceInitial(), isTrue);
      expect(initial == Object(), isFalse);
      expect(initial.hashCode, equals(const SurfaceInitial().hashCode));
      expect(initial.toString(), equals('SurfaceInitial()'));

      const streaming1 =
          SurfaceStreaming(surfaceId: 's1', messageCount: 2, progress: 0.5);
      const streaming2 =
          SurfaceStreaming(surfaceId: 's1', messageCount: 2, progress: 0.5);
      const streamingDiff = SurfaceStreaming(surfaceId: 's2', messageCount: 1);
      expect(streaming1 == streaming2, isTrue);
      expect(streaming1 == streamingDiff, isFalse);
      expect(streaming1 == Object(), isFalse);
      expect(streaming1.hashCode, equals(streaming2.hashCode));
      expect(streaming1.toString(), contains('s1'));

      const submitting1 = SurfaceSubmitting(
        surfaceId: 's1',
        actionName: 'act1',
        sourceComponentId: 'btn1',
      );
      const submitting2 = SurfaceSubmitting(
        surfaceId: 's1',
        actionName: 'act1',
        sourceComponentId: 'btn1',
      );
      const submittingDiff = SurfaceSubmitting(
        surfaceId: 's2',
        actionName: 'act2',
        sourceComponentId: 'btn2',
      );
      expect(submitting1 == submitting2, isTrue);
      expect(submitting1 == submittingDiff, isFalse);
      expect(submitting1 == Object(), isFalse);
      expect(submitting1.hashCode, equals(submitting2.hashCode));
      expect(submitting1.toString(), contains('act1'));

      const err1 = SurfaceError(error: 'err', surfaceId: 's1');
      const err2 = SurfaceError(error: 'err', surfaceId: 's1');
      const errDiff = SurfaceError(error: 'err2', surfaceId: 's2');
      expect(err1 == err2, isTrue);
      expect(err1 == errDiff, isFalse);
      expect(err1 == Object(), isFalse);
      expect(err1.hashCode, equals(err2.hashCode));
      expect(err1.toString(), contains('err'));

      final now = DateTime.now();
      final resp1 = A2uiActionResponse(
        actionName: 'a',
        surfaceId: 's',
        sourceComponentId: 'c',
        timestamp: now,
      );
      final resp2 = A2uiActionResponse(
        actionName: 'a',
        surfaceId: 's',
        sourceComponentId: 'c',
        timestamp: now,
      );
      final respDiff = A2uiActionResponse(
        actionName: 'b',
        surfaceId: 's',
        sourceComponentId: 'c',
        timestamp: now,
      );
      expect(resp1 == resp2, isTrue);
      expect(resp1 == respDiff, isFalse);
      expect(resp1 == Object(), isFalse);
      expect(resp1.hashCode, equals(resp2.hashCode));
      expect(resp1.toString(), contains('a'));
    });
  });
}
