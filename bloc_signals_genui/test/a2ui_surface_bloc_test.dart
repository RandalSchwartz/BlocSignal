import 'dart:async';

import 'package:bloc_signals_genui/bloc_signals_genui.dart';
import 'package:bloc_signals_test/bloc_signals_test.dart';
import 'package:test/test.dart';

class _TrackingMultiSurfaceBloc extends A2uiSurfaceBloc {
  _TrackingMultiSurfaceBloc({this.onErrorCallback});

  final void Function(Object error)? onErrorCallback;

  @override
  void onError(Object error, StackTrace stackTrace) {
    onErrorCallback?.call(error);
    super.onError(error, stackTrace);
  }
}

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
      'processes CreateSurfaceMessage and transitions to SurfaceStreaming until components arrive',
      build: A2uiSurfaceBloc.new,
      act: (bloc) => bloc
        ..add(
          ProcessMessage(
            CreateSurfaceMessage(
              surfaceId: 'surf_1',
              catalogId: minimalCatalogId,
            ),
          ),
        )
        ..add(
          ProcessMessage(
            UpdateComponentsMessage(
              surfaceId: 'surf_1',
              components: const [
                {
                  'id': 'txt_1',
                  'component': 'Text',
                  'text': 'Hello Surface',
                },
              ],
            ),
          ),
        ),
      expect: () => [
        isA<SurfaceStreaming>()
            .having((s) => s.surfaceId, 'surfaceId', 'surf_1'),
        isA<SurfaceReady>().having((s) => s.surfaceId, 'surfaceId', 'surf_1'),
      ],
    );

    test(
        '(Issue #301: F19) bare createSurface produces identical '
        'SurfaceStreaming state across ProcessMessage and IngestStream',
        () async {
      final blocMsg = A2uiSurfaceBloc();
      final blocStream = A2uiSurfaceBloc();
      addTearDown(blocMsg.close);
      addTearDown(blocStream.close);

      final msgStates = <A2uiSurfaceState>[];
      final streamStates = <A2uiSurfaceState>[];

      blocMsg.state.subscribe(msgStates.add);
      blocStream.state.subscribe(streamStates.add);

      final streamCompleter = Completer<void>();
      final unsubscribe = blocStream.state.subscribe((s) {
        if (s is SurfaceStreaming &&
            s.surfaceId == 'surf_parity' &&
            !streamCompleter.isCompleted) {
          streamCompleter.complete();
        }
      });
      addTearDown(unsubscribe);

      blocMsg.add(
        ProcessMessage(
          CreateSurfaceMessage(
            surfaceId: 'surf_parity',
            catalogId: minimalCatalogId,
          ),
        ),
      );

      blocStream.add(
        IngestStream(
          Stream.value({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 'surf_parity',
              'catalogId': minimalCatalogId,
            },
          }),
        ),
      );

      await streamCompleter.future.timeout(const Duration(seconds: 2));

      expect(blocMsg.value, isA<SurfaceStreaming>());
      expect(blocStream.value, isA<SurfaceStreaming>());
      expect(
        (blocMsg.value as SurfaceStreaming).surfaceId,
        equals('surf_parity'),
      );
      expect(
        (blocStream.value as SurfaceStreaming).surfaceId,
        equals('surf_parity'),
      );
    });

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
        isA<SurfaceStreaming>()
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
          ProcessMessage(
            UpdateComponentsMessage(
              surfaceId: 'surf_form',
              components: const [
                {
                  'id': 'tf_dest',
                  'component': 'TextField',
                  'label': 'Destination',
                  'value': {'path': '/booking/destination'},
                },
              ],
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
          ProcessMessages([
            CreateSurfaceMessage(
              surfaceId: 'surf_reset',
              catalogId: minimalCatalogId,
            ),
            UpdateComponentsMessage(
              surfaceId: 'surf_reset',
              components: const [
                {
                  'id': 'txt_reset',
                  'component': 'Text',
                  'text': 'To be reset',
                },
              ],
            ),
          ]),
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
      secondStream.add({
        'version': 'v0.9',
        'updateComponents': {
          'surfaceId': 'surf_second',
          'components': [
            {'id': 'txt2', 'component': 'Text', 'text': 'Second stream text'},
          ],
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
        ProcessMessages([
          CreateSurfaceMessage(
            surfaceId: 'surf_complete',
            catalogId: minimalCatalogId,
          ),
          UpdateComponentsMessage(
            surfaceId: 'surf_complete',
            components: const [
              {'id': 'txt_comp', 'component': 'Text', 'text': 'Complete'},
            ],
          ),
        ]),
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
        UpdateComponentsMessage(
          surfaceId: 'surf_auto',
          components: const [
            {'id': 'txt_auto', 'component': 'Text', 'text': 'Auto'},
          ],
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

    test('A2uiActionResponse.getFormValue retrieves flat and nested values',
        () {
      final now = DateTime.now();
      final resp = A2uiActionResponse(
        actionName: 'submit',
        surfaceId: 'surf',
        sourceComponentId: 'btn',
        timestamp: now,
        formData: const {
          'directKey': 'hello',
          '/flat/slash': 42,
          'nested': {
            'inner': 'world',
            'deep': {
              'count': 100,
            },
          },
        },
      );

      // Direct key
      expect(resp.getFormValue<String>('directKey'), equals('hello'));
      expect(resp.getFormValue<int>('directKey'), isNull);

      // Flat slash key
      expect(resp.getFormValue<int>('/flat/slash'), equals(42));

      // Nested via slash
      expect(resp.getFormValue<String>('/nested/inner'), equals('world'));
      expect(resp.getFormValue<String>('nested/inner'), equals('world'));
      expect(resp.getFormValue<int>('/nested/deep/count'), equals(100));

      // Nested via dot
      expect(resp.getFormValue<String>('nested.inner'), equals('world'));
      expect(resp.getFormValue<int>('nested.deep.count'), equals(100));

      // Non-existent
      expect(resp.getFormValue<String>('/nested/missing'), isNull);
      expect(resp.getFormValue<String>('/unknown'), isNull);
      expect(resp.getFormValue<String>(''), isNull);
    });

    group('Submission Recovery & Lifecycle (Issue #284)', () {
      test('CancelSubmission restores SurfaceReady and preserves form values',
          () {
        final bloc = A2uiSurfaceBloc();
        bloc.add(
          ProcessMessage(
            CreateSurfaceMessage(
              surfaceId: 'surf_recover',
              catalogId: minimalCatalogId,
            ),
          ),
        );
        bloc.add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateComponents': {
              'surfaceId': 'surf_recover',
              'components': [
                {
                  'id': 'txt_name',
                  'component': 'Text',
                  'text': 'Name',
                },
              ],
            },
          }),
        );
        bloc.add(
          const UpdateFormField(
            surfaceId: 'surf_recover',
            path: '/username',
            value: 'Alice',
          ),
        );
        expect(bloc.stateValue, isA<SurfaceReady>());
        expect(
          (bloc.stateValue as SurfaceReady).formValues['username'],
          equals('Alice'),
        );

        // Submit action transitions to SurfaceSubmitting
        bloc.add(
          const SubmitAction(
            actionName: 'saveProfile',
            sourceComponentId: 'btn_save',
            surfaceId: 'surf_recover',
          ),
        );
        expect(bloc.stateValue, isA<SurfaceSubmitting>());

        // Cancel submission with error
        bloc.add(
          const CancelSubmission(
            surfaceId: 'surf_recover',
            error: 'Network timeout contacting profile service',
          ),
        );

        expect(bloc.stateValue, isA<SurfaceReady>());
        final recovered = bloc.stateValue as SurfaceReady;
        expect(recovered.surfaceId, equals('surf_recover'));
        expect(recovered.isValid, isFalse);
        expect(
          recovered.validationErrors,
          contains('Network timeout contacting profile service'),
        );
        expect(recovered.formValues['username'], equals('Alice'));
      });

      test('CancelSubmission without error restores SurfaceReady as valid', () {
        final bloc = A2uiSurfaceBloc();
        bloc.add(
          ProcessMessage(
            CreateSurfaceMessage(
              surfaceId: 'surf_cancel_no_err',
              catalogId: minimalCatalogId,
            ),
          ),
        );
        bloc.add(
          const SubmitAction(
            actionName: 'doSomething',
            sourceComponentId: 'btn1',
            surfaceId: 'surf_cancel_no_err',
          ),
        );
        expect(bloc.stateValue, isA<SurfaceSubmitting>());

        bloc.add(const CancelSubmission());
        expect(bloc.stateValue, isA<SurfaceReady>());
        final ready = bloc.stateValue as SurfaceReady;
        expect(ready.surfaceId, equals('surf_cancel_no_err'));
        expect(ready.isValid, isTrue);
        expect(ready.validationErrors, isEmpty);
      });

      test('CompleteAction restores SurfaceReady on success or failure', () {
        final bloc = A2uiSurfaceBloc();
        bloc.add(
          ProcessMessage(
            CreateSurfaceMessage(
              surfaceId: 'surf_complete',
              catalogId: minimalCatalogId,
            ),
          ),
        );

        // Successful completion without streaming new UI
        bloc.add(
          const SubmitAction(
            actionName: 'syncData',
            sourceComponentId: 'btn_sync',
            surfaceId: 'surf_complete',
          ),
        );
        expect(bloc.stateValue, isA<SurfaceSubmitting>());

        bloc.add(const CompleteAction());
        expect(bloc.stateValue, isA<SurfaceReady>());
        final successReady = bloc.stateValue as SurfaceReady;
        expect(successReady.isValid, isTrue);
        expect(successReady.validationErrors, isEmpty);

        // Failed completion with error
        bloc.add(
          const SubmitAction(
            actionName: 'syncData',
            sourceComponentId: 'btn_sync',
            surfaceId: 'surf_complete',
          ),
        );
        expect(bloc.stateValue, isA<SurfaceSubmitting>());

        bloc.add(
          const CompleteAction(
            surfaceId: 'surf_complete',
            error: 'Backend transaction rejected',
          ),
        );
        expect(bloc.stateValue, isA<SurfaceReady>());
        final failedReady = bloc.stateValue as SurfaceReady;
        expect(failedReady.isValid, isFalse);
        expect(
          failedReady.validationErrors,
          contains('Backend transaction rejected'),
        );
      });

      test('CancelSubmission and CompleteAction value equality and toString',
          () {
        const cancel1 = CancelSubmission(surfaceId: 's1', error: 'err1');
        const cancel2 = CancelSubmission(surfaceId: 's1', error: 'err1');
        const cancelDiff = CancelSubmission(surfaceId: 's2', error: 'err2');
        const cancelDiffSurface =
            CancelSubmission(surfaceId: 's2', error: 'err1');

        expect(cancel1 == cancel2, isTrue);
        expect(cancel1 == cancelDiff, isFalse);
        expect(cancel1 == cancelDiffSurface, isFalse);
        expect(cancel1 == Object(), isFalse);
        expect(cancel1.hashCode, equals(cancel2.hashCode));
        expect(cancel1.toString(), contains('CancelSubmission'));

        const complete1 = CompleteAction(surfaceId: 's1', error: 'err1');
        const complete2 = CompleteAction(surfaceId: 's1', error: 'err1');
        const completeDiff = CompleteAction(surfaceId: 's2', error: 'err2');
        const completeDiffSurface =
            CompleteAction(surfaceId: 's2', error: 'err1');

        expect(complete1 == complete2, isTrue);
        expect(complete1 == completeDiff, isFalse);
        expect(complete1 == completeDiffSurface, isFalse);
        expect(complete1 == Object(), isFalse);
        expect(complete1.hashCode, equals(complete2.hashCode));
        expect(complete1.toString(), contains('CompleteAction'));
      });
    });

    group('Multi-surface navigation & discovery (Issue #283)', () {
      test('SelectSurface switches active surface and emits SurfaceReady', () {
        final bloc = A2uiSurfaceBloc();
        bloc.add(
          ProcessMessages([
            CreateSurfaceMessage(
              surfaceId: 'surf_1',
              catalogId: minimalCatalogId,
            ),
            UpdateComponentsMessage(
              surfaceId: 'surf_1',
              components: const [
                {'id': 'txt_1', 'component': 'Text', 'text': 'Surface 1'},
              ],
            ),
            CreateSurfaceMessage(
              surfaceId: 'surf_2',
              catalogId: minimalCatalogId,
            ),
            UpdateComponentsMessage(
              surfaceId: 'surf_2',
              components: const [
                {'id': 'txt_2', 'component': 'Text', 'text': 'Surface 2'},
              ],
            ),
          ]),
        );

        // After batch, surf_2 is latest
        expect(bloc.stateValue, isA<SurfaceReady>());
        expect((bloc.stateValue as SurfaceReady).surfaceId, equals('surf_2'));
        expect(
          (bloc.stateValue as SurfaceReady).availableSurfaceIds,
          containsAll(['surf_1', 'surf_2']),
        );
        expect(bloc.availableSurfaceIds, containsAll(['surf_1', 'surf_2']));

        // Select surf_1
        bloc.add(const SelectSurface(surfaceId: 'surf_1'));
        expect(bloc.stateValue, isA<SurfaceReady>());
        final ready1 = bloc.stateValue as SurfaceReady;
        expect(ready1.surfaceId, equals('surf_1'));
        expect(ready1.availableSurfaceIds, containsAll(['surf_1', 'surf_2']));
        expect(bloc.activeSurfaceId.value, equals('surf_1'));
        expect(bloc.activeSurfaceIdValue, equals('surf_1'));
      });

      test(
          'SelectSurface emits SurfaceError and notifies onError for unknown surface',
          () {
        final errors = <Object>[];
        final bloc = _TrackingMultiSurfaceBloc(onErrorCallback: errors.add);

        bloc.add(
          ProcessMessage(
            CreateSurfaceMessage(
              surfaceId: 'surf_known',
              catalogId: minimalCatalogId,
            ),
          ),
        );

        bloc.add(const SelectSurface(surfaceId: 'surf_unknown'));
        expect(bloc.stateValue, isA<SurfaceError>());
        final errorState = bloc.stateValue as SurfaceError;
        expect(errorState.surfaceId, equals('surf_unknown'));
        expect(errors, isNotEmpty);
        expect(errors.first, isA<ArgumentError>());
      });

      test('availableSurfaceIds is unmodifiable and prevents mutation', () {
        final bloc = A2uiSurfaceBloc();
        bloc.add(
          ProcessMessages([
            CreateSurfaceMessage(
              surfaceId: 'surf_immut',
              catalogId: minimalCatalogId,
            ),
            UpdateComponentsMessage(
              surfaceId: 'surf_immut',
              components: const [
                {'id': 'txt_immut', 'component': 'Text', 'text': 'Immutable'},
              ],
            ),
          ]),
        );

        final ready = bloc.stateValue as SurfaceReady;
        expect(
          () => ready.availableSurfaceIds.add('surf_illegal'),
          throwsUnsupportedError,
        );
        expect(
          () => bloc.availableSurfaceIds.add('surf_illegal'),
          throwsUnsupportedError,
        );
      });

      test('getSurfaceReady returns snapshot for existing surface or null', () {
        final bloc = A2uiSurfaceBloc();
        bloc.add(
          ProcessMessages([
            CreateSurfaceMessage(
              surfaceId: 'surf_a',
              catalogId: minimalCatalogId,
            ),
            CreateSurfaceMessage(
              surfaceId: 'surf_b',
              catalogId: minimalCatalogId,
            ),
          ]),
        );

        final readyA = bloc.getSurfaceReady('surf_a');
        expect(readyA, isNotNull);
        expect(readyA!.surfaceId, equals('surf_a'));
        expect(readyA.availableSurfaceIds, containsAll(['surf_a', 'surf_b']));

        final readyUnknown = bloc.getSurfaceReady('surf_missing');
        expect(readyUnknown, isNull);
      });

      test('SelectSurface value equality, hashCode, and toString', () {
        const s1 = SelectSurface(surfaceId: 'surf_1');
        const s2 = SelectSurface(surfaceId: 'surf_1');
        const s3 = SelectSurface(surfaceId: 'surf_2');

        expect(s1 == s2, isTrue);
        expect(s1 == s3, isFalse);
        expect(s1 == Object(), isFalse);
        expect(s1.hashCode, equals(s2.hashCode));
        expect(s1.toString(), contains('SelectSurface(surfaceId: surf_1)'));
      });
    });

    group(
        '(Issue #292) Reactive activeSurfaceId, Per-Surface Versions, '
        'CloseSurface, DeleteSurfaceMessage, and Bounded LRU Eviction', () {
      test(
          '(Issue #292) activeSurfaceId is a ReadonlySignal<String?> and '
          'activeSurfaceIdValue updates synchronously in 0ms', () {
        final bloc = A2uiSurfaceBloc();
        addTearDown(bloc.close);

        final observedActiveIds = <String?>[];
        final unsub = bloc.activeSurfaceId.subscribe(observedActiveIds.add);
        addTearDown(unsub);

        expect(bloc.activeSurfaceId.value, isNull);
        expect(bloc.activeSurfaceIdValue, isNull);
        expect(observedActiveIds, equals([null]));

        // CreateSurfaceMessage updates activeSurfaceId synchronously
        bloc.add(
          ProcessMessage(
            CreateSurfaceMessage(
              surfaceId: 'surf_a',
              catalogId: minimalCatalogId,
            ),
          ),
        );
        expect(bloc.activeSurfaceId.value, equals('surf_a'));
        expect(bloc.activeSurfaceIdValue, equals('surf_a'));
        expect(observedActiveIds.last, equals('surf_a'));

        // Create second surface
        bloc.add(
          ProcessMessage(
            CreateSurfaceMessage(
              surfaceId: 'surf_b',
              catalogId: minimalCatalogId,
            ),
          ),
        );
        expect(bloc.activeSurfaceId.value, equals('surf_b'));
        expect(bloc.activeSurfaceIdValue, equals('surf_b'));

        // SelectSurface updates activeSurfaceId synchronously
        bloc.add(const SelectSurface(surfaceId: 'surf_a'));
        expect(bloc.activeSurfaceId.value, equals('surf_a'));
        expect(bloc.activeSurfaceIdValue, equals('surf_a'));

        // Direct emit() transitions sync activeSurfaceId
        bloc.emit(
          const SurfaceStreaming(surfaceId: 'surf_direct', messageCount: 1),
        );
        expect(bloc.activeSurfaceId.value, equals('surf_direct'));
        expect(bloc.activeSurfaceIdValue, equals('surf_direct'));

        // Direct emit(SurfaceInitial()) resets activeSurfaceId to null
        bloc.emit(const SurfaceInitial());
        expect(bloc.activeSurfaceId.value, isNull);
        expect(bloc.activeSurfaceIdValue, isNull);
      });

      test(
          '(Issue #292) SelectSurface switching A -> B -> A does NOT increment '
          'version on either surface', () {
        final bloc = A2uiSurfaceBloc();
        addTearDown(bloc.close);

        bloc.add(
          ProcessMessages([
            CreateSurfaceMessage(
              surfaceId: 'A',
              catalogId: minimalCatalogId,
            ),
            UpdateComponentsMessage(
              surfaceId: 'A',
              components: const [
                {'id': 'txt_a', 'component': 'Text', 'text': 'Surface A'},
              ],
            ),
            CreateSurfaceMessage(
              surfaceId: 'B',
              catalogId: minimalCatalogId,
            ),
            UpdateComponentsMessage(
              surfaceId: 'B',
              components: const [
                {'id': 'txt_b', 'component': 'Text', 'text': 'Surface B'},
              ],
            ),
          ]),
        );

        final initialVersionA = bloc.getSurfaceReady('A')!.version;
        final initialVersionB = bloc.getSurfaceReady('B')!.version;
        expect(bloc.activeSurfaceIdValue, equals('B'));

        // Switch B -> A
        bloc.add(const SelectSurface(surfaceId: 'A'));
        expect(bloc.activeSurfaceIdValue, equals('A'));
        expect((bloc.value as SurfaceReady).surfaceId, equals('A'));
        expect((bloc.value as SurfaceReady).version, equals(initialVersionA));
        expect(bloc.getSurfaceReady('A')!.version, equals(initialVersionA));
        expect(bloc.getSurfaceReady('B')!.version, equals(initialVersionB));

        // Switch A -> B
        bloc.add(const SelectSurface(surfaceId: 'B'));
        expect(bloc.activeSurfaceIdValue, equals('B'));
        expect((bloc.value as SurfaceReady).surfaceId, equals('B'));
        expect((bloc.value as SurfaceReady).version, equals(initialVersionB));
        expect(bloc.getSurfaceReady('A')!.version, equals(initialVersionA));
        expect(bloc.getSurfaceReady('B')!.version, equals(initialVersionB));

        // Switch B -> A again
        bloc.add(const SelectSurface(surfaceId: 'A'));
        expect(bloc.activeSurfaceIdValue, equals('A'));
        expect((bloc.value as SurfaceReady).surfaceId, equals('A'));
        expect((bloc.value as SurfaceReady).version, equals(initialVersionA));
      });

      test(
          '(Issue #292) per-surface version tracking isolates mutations to the '
          'targeted surface without incrementing sibling surface versions', () {
        final bloc = A2uiSurfaceBloc();
        addTearDown(bloc.close);

        bloc.add(
          ProcessMessages([
            CreateSurfaceMessage(
              surfaceId: 'A',
              catalogId: minimalCatalogId,
            ),
            UpdateComponentsMessage(
              surfaceId: 'A',
              components: const [
                {'id': 'txt_a', 'component': 'Text', 'text': 'Surface A'},
              ],
            ),
            CreateSurfaceMessage(
              surfaceId: 'B',
              catalogId: minimalCatalogId,
            ),
            UpdateComponentsMessage(
              surfaceId: 'B',
              components: const [
                {
                  'id': 'tf_b',
                  'component': 'TextField',
                  'label': 'Name',
                  'required': true,
                  'value': {'path': '/name'},
                },
              ],
            ),
          ]),
        );

        final versionA = bloc.getSurfaceReady('A')!.version;
        var versionB = bloc.getSurfaceReady('B')!.version;

        // 1. UpdateComponentsMessage on B
        bloc.add(
          ProcessMessage(
            UpdateComponentsMessage(
              surfaceId: 'B',
              components: const [
                {
                  'id': 'tf_b',
                  'component': 'TextField',
                  'label': 'Name Updated',
                  'required': true,
                  'value': {'path': '/name'},
                },
              ],
            ),
          ),
        );
        expect(bloc.getSurfaceReady('B')!.version, greaterThan(versionB));
        expect(bloc.getSurfaceReady('A')!.version, equals(versionA));
        versionB = bloc.getSurfaceReady('B')!.version;

        // 2. UpdateDataModelMessage on B
        bloc.add(
          ProcessMessage(
            UpdateDataModelMessage(
              surfaceId: 'B',
              path: '/extra',
              value: 'data',
            ),
          ),
        );
        expect(bloc.getSurfaceReady('B')!.version, greaterThan(versionB));
        expect(bloc.getSurfaceReady('A')!.version, equals(versionA));
        versionB = bloc.getSurfaceReady('B')!.version;

        // 3. SubmitAction validation failure on B (since /name is empty)
        bloc.add(
          const SubmitAction(
            actionName: 'submitB',
            sourceComponentId: 'tf_b',
            surfaceId: 'B',
          ),
        );
        expect(bloc.getSurfaceReady('B')!.version, greaterThan(versionB));
        expect(bloc.getSurfaceReady('A')!.version, equals(versionA));
        versionB = bloc.getSurfaceReady('B')!.version;

        // 4. UpdateFormField on B
        bloc.add(
          const UpdateFormField(
            surfaceId: 'B',
            path: '/name',
            value: 'Alice',
          ),
        );
        expect(bloc.getSurfaceReady('B')!.version, greaterThan(versionB));
        expect(bloc.getSurfaceReady('A')!.version, equals(versionA));
        versionB = bloc.getSurfaceReady('B')!.version;

        // 5. SubmitAction valid + CancelSubmission on B
        bloc.add(
          const SubmitAction(
            actionName: 'submitB',
            sourceComponentId: 'tf_b',
            surfaceId: 'B',
          ),
        );
        bloc.add(
          const CancelSubmission(
            surfaceId: 'B',
            error: 'Cancelled',
          ),
        );
        expect(bloc.getSurfaceReady('B')!.version, greaterThan(versionB));
        expect(bloc.getSurfaceReady('A')!.version, equals(versionA));
        versionB = bloc.getSurfaceReady('B')!.version;

        // 6. CompleteAction on B
        bloc.add(
          const CompleteAction(
            surfaceId: 'B',
          ),
        );
        expect(bloc.getSurfaceReady('B')!.version, greaterThan(versionB));
        expect(bloc.getSurfaceReady('A')!.version, equals(versionA));
      });

      test('(Issue #292) CloseSurface value equality, hashCode, and toString',
          () {
        const c1 = CloseSurface(surfaceId: 'surf_1');
        const c2 = CloseSurface(surfaceId: 'surf_1');
        const c3 = CloseSurface(surfaceId: 'surf_2');

        expect(c1 == c2, isTrue);
        expect(c1 == c3, isFalse);
        expect(c1 == Object(), isFalse);
        expect(c1.hashCode, equals(c2.hashCode));
        expect(c1.toString(), equals('CloseSurface(surfaceId: surf_1)'));
      });

      test(
          '(Issue #292) CloseSurface evicts surface, prunes history/version, '
          'and promotes most-recently-accessed survivor without bumping its version',
          () async {
        final bloc = A2uiSurfaceBloc();
        addTearDown(bloc.close);

        bloc.add(
          ProcessMessages([
            CreateSurfaceMessage(
              surfaceId: 'A',
              catalogId: minimalCatalogId,
            ),
            UpdateComponentsMessage(
              surfaceId: 'A',
              components: const [
                {'id': 'txt_a', 'component': 'Text', 'text': 'Surface A'},
              ],
            ),
            CreateSurfaceMessage(
              surfaceId: 'B',
              catalogId: minimalCatalogId,
            ),
            UpdateComponentsMessage(
              surfaceId: 'B',
              components: const [
                {'id': 'txt_b', 'component': 'Text', 'text': 'Surface B'},
              ],
            ),
            CreateSurfaceMessage(
              surfaceId: 'C',
              catalogId: minimalCatalogId,
            ),
            UpdateComponentsMessage(
              surfaceId: 'C',
              components: const [
                {'id': 'txt_c', 'component': 'Text', 'text': 'Surface C'},
              ],
            ),
          ]),
        );

        // Submit actions on B and C
        bloc
          ..add(
            const SubmitAction(
              actionName: 'act_b',
              sourceComponentId: 'txt_b',
              surfaceId: 'B',
            ),
          )
          ..add(const CompleteAction(surfaceId: 'B'))
          ..add(
            const SubmitAction(
              actionName: 'act_c',
              sourceComponentId: 'txt_c',
              surfaceId: 'C',
            ),
          )
          ..add(const CompleteAction(surfaceId: 'C'));

        // Select A, then Select C so LRU order is [B, A, C] (most recent = C, second = A)
        bloc
          ..add(const SelectSurface(surfaceId: 'A'))
          ..add(const SelectSurface(surfaceId: 'C'));

        final versionA = bloc.getSurfaceReady('A')!.version;
        final versionB = bloc.getSurfaceReady('B')!.version;

        // Close inactive surface B while C is active
        final versionC = (bloc.value as SurfaceReady).version;
        bloc.add(const CloseSurface(surfaceId: 'B'));

        expect(bloc.availableSurfaceIds, equals(['A', 'C']));
        expect(bloc.activeSurfaceIdValue, equals('C'));
        final readyAfterCloseB = bloc.value as SurfaceReady;
        expect(readyAfterCloseB.surfaceId, equals('C'));
        expect(readyAfterCloseB.availableSurfaceIds, equals(['A', 'C']));
        // Closing inactive B must NOT bump active C's version!
        expect(readyAfterCloseB.version, equals(versionC));
        expect(bloc.getSurfaceReady('A')!.version, equals(versionA));
        expect(bloc.getSurfaceReady('B'), isNull);

        // Close active surface C -> should promote most-recently-accessed survivor A
        bloc.add(const CloseSurface(surfaceId: 'C'));
        expect(bloc.availableSurfaceIds, equals(['A']));
        expect(bloc.activeSurfaceIdValue, equals('A'));
        final readyAfterCloseC = bloc.value as SurfaceReady;
        expect(readyAfterCloseC.surfaceId, equals('A'));
        expect(readyAfterCloseC.version, equals(versionA));

        // Verify B and C action responses were pruned
        final responses = <A2uiActionResponse>[];
        final sub = bloc.actionResponses.listen(responses.add);
        await Future<void>.microtask(() {});
        await sub.cancel();
        expect(responses, isEmpty);

        // Close last remaining surface A -> transitions to SurfaceInitial and activeSurfaceId == null
        bloc.add(const CloseSurface(surfaceId: 'A'));
        expect(bloc.availableSurfaceIds, isEmpty);
        expect(bloc.activeSurfaceIdValue, isNull);
        expect(bloc.value, isA<SurfaceInitial>());
        // Suppress unused variable warning check
        expect(versionB, isPositive);
      });

      test(
          '(Issue #292) CloseSurface cancels active stream when closing active '
          'surface and handles non-existent or phantom surfaces gracefully',
          () async {
        final bloc = A2uiSurfaceBloc();
        addTearDown(bloc.close);

        var streamCancelled = false;
        final controller = StreamController<dynamic>(
          onCancel: () {
            streamCancelled = true;
          },
        );

        bloc.add(IngestStream(controller.stream));
        await Future<void>.microtask(() {});

        controller.add(
          CreateSurfaceMessage(
            surfaceId: 'stream_surf',
            catalogId: minimalCatalogId,
          ),
        );
        await Future<void>.microtask(() {});
        expect(bloc.activeSurfaceIdValue, equals('stream_surf'));

        // Closing active surface cancels the in-flight stream
        bloc.add(const CloseSurface(surfaceId: 'stream_surf'));
        await Future<void>.microtask(() {});

        expect(streamCancelled, isTrue);
        expect(bloc.activeSurfaceIdValue, isNull);
        expect(bloc.value, isA<SurfaceInitial>());

        // Closing a non-existent surface when SurfaceInitial is a safe no-op
        bloc.add(const CloseSurface(surfaceId: 'non_existent'));
        expect(bloc.value, isA<SurfaceInitial>());

        // Phantom active surface healing on CloseSurface
        bloc.add(
          ProcessMessage(
            CreateSurfaceMessage(
              surfaceId: 'phantom',
              catalogId: minimalCatalogId,
            ),
          ),
        );
        bloc.processor.groupModel.deleteSurface('phantom');
        expect(bloc.activeSurfaceIdValue, equals('phantom'));
        bloc.add(const CloseSurface(surfaceId: 'phantom'));
        expect(bloc.activeSurfaceIdValue, isNull);
        expect(bloc.value, isA<SurfaceInitial>());

        await controller.close();
      });

      test(
          '(Issue #292) Wire-level DeleteSurfaceMessage prunes history, '
          'versions, LRU order, and heals activeSurfaceId', () async {
        final bloc = A2uiSurfaceBloc();
        addTearDown(bloc.close);

        bloc.add(
          ProcessMessages([
            CreateSurfaceMessage(
              surfaceId: 'A',
              catalogId: minimalCatalogId,
            ),
            UpdateComponentsMessage(
              surfaceId: 'A',
              components: const [
                {'id': 'txt_a', 'component': 'Text', 'text': 'Surface A'},
              ],
            ),
            CreateSurfaceMessage(
              surfaceId: 'B',
              catalogId: minimalCatalogId,
            ),
            UpdateComponentsMessage(
              surfaceId: 'B',
              components: const [
                {'id': 'txt_b', 'component': 'Text', 'text': 'Surface B'},
              ],
            ),
          ]),
        );

        bloc
          ..add(
            const SubmitAction(
              actionName: 'act_b',
              sourceComponentId: 'txt_b',
              surfaceId: 'B',
            ),
          )
          ..add(const CompleteAction(surfaceId: 'B'));

        expect(bloc.activeSurfaceIdValue, equals('B'));

        // Dispatch DeleteSurfaceMessage for active surface B via ProcessMessage
        bloc.add(
          ProcessMessage(
            DeleteSurfaceMessage(surfaceId: 'B'),
          ),
        );

        expect(bloc.availableSurfaceIds, equals(['A']));
        expect(bloc.activeSurfaceIdValue, equals('A'));
        expect((bloc.value as SurfaceReady).surfaceId, equals('A'));

        // Verify B's history was pruned
        final responses = <A2uiActionResponse>[];
        final sub = bloc.actionResponses.listen(responses.add);
        await Future<void>.microtask(() {});
        await sub.cancel();
        expect(responses, isEmpty);

        // Also test DeleteSurfaceMessage via ProcessJsonMessage for A
        bloc.add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'deleteSurface': {
              'surfaceId': 'A',
            },
          }),
        );
        expect(bloc.availableSurfaceIds, isEmpty);
        expect(bloc.activeSurfaceIdValue, isNull);
        expect(bloc.value, isA<SurfaceInitial>());
      });

      test(
          '(Issue #292) A2uiSurfaceBloc(maxSurfaces: k) enforces bounded LRU '
          'surface eviction and spares recently accessed surfaces', () {
        expect(
          () => A2uiSurfaceBloc(maxSurfaces: 0),
          throwsA(isA<AssertionError>()),
        );
        expect(
          () => A2uiSurfaceBloc(maxSurfaces: -1),
          throwsA(isA<AssertionError>()),
        );

        final bloc = A2uiSurfaceBloc(maxSurfaces: 2);
        addTearDown(bloc.close);

        // Create A and B (capacity 2 reached: [A, B])
        bloc.add(
          ProcessMessages([
            CreateSurfaceMessage(
              surfaceId: 'A',
              catalogId: minimalCatalogId,
            ),
            UpdateComponentsMessage(
              surfaceId: 'A',
              components: const [
                {'id': 'txt_a', 'component': 'Text', 'text': 'Surface A'},
              ],
            ),
            CreateSurfaceMessage(
              surfaceId: 'B',
              catalogId: minimalCatalogId,
            ),
            UpdateComponentsMessage(
              surfaceId: 'B',
              components: const [
                {'id': 'txt_b', 'component': 'Text', 'text': 'Surface B'},
              ],
            ),
          ]),
        );
        expect(bloc.availableSurfaceIds, containsAll(['A', 'B']));

        // Touch A via SelectSurface so LRU order becomes [B, A] (B is oldest)
        bloc.add(const SelectSurface(surfaceId: 'A'));

        // Create C -> should evict oldest non-active surface B!
        bloc.add(
          ProcessMessages([
            CreateSurfaceMessage(
              surfaceId: 'C',
              catalogId: minimalCatalogId,
            ),
            UpdateComponentsMessage(
              surfaceId: 'C',
              components: const [
                {'id': 'txt_c', 'component': 'Text', 'text': 'Surface C'},
              ],
            ),
          ]),
        );

        expect(bloc.availableSurfaceIds, containsAll(['A', 'C']));
        expect(bloc.availableSurfaceIds, isNot(contains('B')));
        expect(bloc.getSurfaceReady('B'), isNull);
        expect(bloc.activeSurfaceIdValue, equals('C'));

        // Touch A via UpdateFormField so LRU order becomes [C, A]
        bloc.add(
          const UpdateFormField(
            surfaceId: 'A',
            path: '/touched',
            value: true,
          ),
        );

        // Create D -> C becomes inactive when D is created, and since A was
        // touched more recently than C, C is evicted!
        bloc.add(
          ProcessMessage(
            CreateSurfaceMessage(
              surfaceId: 'D',
              catalogId: minimalCatalogId,
            ),
          ),
        );
        expect(bloc.availableSurfaceIds, containsAll(['A', 'D']));
        expect(bloc.availableSurfaceIds, isNot(contains('C')));

        // Also test maxSurfaces: 1
        final blocSingle = A2uiSurfaceBloc(maxSurfaces: 1);
        addTearDown(blocSingle.close);
        blocSingle
          ..add(
            ProcessMessage(
              CreateSurfaceMessage(
                surfaceId: 'S1',
                catalogId: minimalCatalogId,
              ),
            ),
          )
          ..add(
            ProcessMessage(
              CreateSurfaceMessage(
                surfaceId: 'S2',
                catalogId: minimalCatalogId,
              ),
            ),
          );
        expect(blocSingle.availableSurfaceIds, equals(['S2']));
        expect(blocSingle.activeSurfaceIdValue, equals('S2'));

        // Also test maxSurfaces eviction fallback when surface was created
        // directly on processor.groupModel outside _surfaceAccessOrder
        final blocFallback = A2uiSurfaceBloc(maxSurfaces: 1);
        addTearDown(blocFallback.close);
        blocFallback.processor.processMessages([
          CreateSurfaceMessage(
            surfaceId: 'S_untracked',
            catalogId: minimalCatalogId,
          ),
        ]);
        blocFallback.add(
          ProcessMessage(
            CreateSurfaceMessage(
              surfaceId: 'S_tracked',
              catalogId: minimalCatalogId,
            ),
          ),
        );
        expect(blocFallback.availableSurfaceIds, equals(['S_tracked']));
      });

      test(
          '(Issue #292) covers A2uiActionResponse equality/getFormValue, '
          'SurfaceState deep equality, and processor normalization branches',
          () async {
        final ts = DateTime.utc(2026);
        final r1 = A2uiActionResponse(
          actionName: 'act',
          surfaceId: 's1',
          sourceComponentId: 'c1',
          formData: const {
            'name': 'Alice',
            'nested': {'k': 1},
          },
          context: const {'ctx': 'v1'},
          timestamp: ts,
        );
        final r2 = A2uiActionResponse(
          actionName: 'act',
          surfaceId: 's1',
          sourceComponentId: 'c1',
          formData: const {
            'name': 'Alice',
            'nested': {'k': 1},
          },
          context: const {'ctx': 'v1'},
          timestamp: ts,
        );
        final rDiffLen = A2uiActionResponse(
          actionName: 'act',
          surfaceId: 's1',
          sourceComponentId: 'c1',
          formData: const {'name': 'Alice'},
          timestamp: ts,
        );
        final rDiffKey = A2uiActionResponse(
          actionName: 'act',
          surfaceId: 's1',
          sourceComponentId: 'c1',
          formData: const {
            'name': 'Alice',
            'other': {'k': 1},
          },
          timestamp: ts,
        );
        final rDiffNested = A2uiActionResponse(
          actionName: 'act',
          surfaceId: 's1',
          sourceComponentId: 'c1',
          formData: const {
            'name': 'Alice',
            'nested': {'k': 2},
          },
          timestamp: ts,
        );
        final rDiffVal = A2uiActionResponse(
          actionName: 'act',
          surfaceId: 's1',
          sourceComponentId: 'c1',
          formData: const {
            'name': 'Bob',
            'nested': {'k': 1},
          },
          timestamp: ts,
        );

        expect(r1, equals(r2));
        expect(r1, isNot(equals(rDiffLen)));
        expect(r1, isNot(equals(rDiffKey)));
        expect(r1, isNot(equals(rDiffNested)));
        expect(r1, isNot(equals(rDiffVal)));
        expect(r1.getFormValue<String>('/name'), equals('Alice'));
        expect(r1.getFormValue<int>('/name'), isNull);

        // SurfaceError equality and SurfaceSubmitting nested map/list equality
        const err1 = SurfaceError(error: 'boom', surfaceId: 's1');
        const err2 = SurfaceError(error: 'boom', surfaceId: 's1');
        const err3 = SurfaceError(error: 'boom', surfaceId: 's2');
        expect(err1, equals(err2));
        expect(err1, isNot(equals(err3)));

        const sub1 = SurfaceSubmitting(
          surfaceId: 's1',
          actionName: 'go',
          sourceComponentId: 'c1',
          payload: {
            'map': {'a': 1},
            'list': [1, 2],
          },
        );
        const sub2 = SurfaceSubmitting(
          surfaceId: 's1',
          actionName: 'go',
          sourceComponentId: 'c1',
          payload: {
            'map': {'a': 1},
            'list': [1, 2],
          },
        );
        const subDiffMap = SurfaceSubmitting(
          surfaceId: 's1',
          actionName: 'go',
          sourceComponentId: 'c1',
          payload: {
            'map': {'a': 2},
            'list': [1, 2],
          },
        );
        const subDiffList = SurfaceSubmitting(
          surfaceId: 's1',
          actionName: 'go',
          sourceComponentId: 'c1',
          payload: {
            'map': {'a': 1},
            'list': [1, 3],
          },
        );
        expect(sub1, equals(sub2));
        expect(sub1, isNot(equals(subDiffMap)));
        expect(sub1, isNot(equals(subDiffList)));

        // Normalization & validation branches on A2uiSurfaceBloc
        final bloc = A2uiSurfaceBloc();
        addTearDown(bloc.close);

        // Untyped Map in components list & un-wrapped action map
        bloc
          ..add(
            const ProcessJsonMessage({
              'version': 'v0.9',
              'createSurface': {
                'surfaceId': 's_norm',
                'catalogId': minimalCatalogId,
              },
            }),
          )
          ..add(
            const ProcessJsonMessage({
              'version': 'v0.9',
              'updateComponents': {
                'surfaceId': 's_norm',
                'components': <Object>[
                  <dynamic, dynamic>{
                    'id': 'btn_unwrapped',
                    'component': 'Button',
                    'action': <String, dynamic>{'name': 'do_it'},
                  },
                ],
              },
            }),
          );

        // Add component with 'name' property and literal key in dataModel
        final surface = bloc.processor.groupModel.getSurface('s_norm')!;
        surface.componentsModel.addComponent(
          ComponentModel('tf_named', 'TextField', const {
            'name': 'namedField',
            'required': true,
          }),
        );
        surface.dataModel.set(
          '/',
          <dynamic, dynamic>{
            'namedField': 'has_value',
          },
        );
        final snap = bloc.getSurfaceReady('s_norm')!;
        expect(snap.isValid, isTrue);

        // DeleteSurfaceMessage when all surfaces are removed while a stream is active
        final streamCtrl = StreamController<dynamic>();
        addTearDown(streamCtrl.close);
        bloc.add(IngestStream(streamCtrl.stream));
        await Future<void>.delayed(Duration.zero);

        // Emit snapshot when no surfaces exist but stream subscription is active
        streamCtrl.add(DeleteSurfaceMessage(surfaceId: 's_norm'));
        await Future<void>.delayed(Duration.zero);
        expect(bloc.value, isA<SurfaceStreaming>());
      });
    });

    group('(Issue #321: R7) Bounded Validation Regex Cache', () {
      setUp(A2uiSurfaceBloc.clearRegexCache);
      tearDown(A2uiSurfaceBloc.clearRegexCache);

      test(
          '(Issue #321: R7) caches compiled RegExp instances, caches malformed '
          'patterns as null without throwing, and evicts beyond 100 entries',
          () {
        final bloc = A2uiSurfaceBloc();
        addTearDown(bloc.close);

        expect(A2uiSurfaceBloc.debugRegexCacheSize, equals(0));

        bloc.add(
          ProcessMessages([
            CreateSurfaceMessage(
              surfaceId: 'surf_regex',
              catalogId: minimalCatalogId,
            ),
            UpdateComponentsMessage(
              surfaceId: 'surf_regex',
              components: const [
                {
                  'id': 'tf_valid',
                  'component': 'TextField',
                  'label': 'Code',
                  'value': {'path': '/code'},
                  'pattern': r'^[A-Z]{3}-\d{2}$',
                },
                {
                  'id': 'tf_malformed',
                  'component': 'TextField',
                  'label': 'Broken',
                  'value': {'path': '/broken'},
                  'validationRegexp': '[unclosed',
                },
              ],
            ),
          ]),
        );

        // Update both fields to non-empty strings so regex validation runs
        bloc
          ..add(
            const UpdateFormField(
              surfaceId: 'surf_regex',
              path: '/code',
              value: 'bad',
            ),
          )
          ..add(
            const UpdateFormField(
              surfaceId: 'surf_regex',
              path: '/broken',
              value: 'anything',
            ),
          );

        expect(A2uiSurfaceBloc.debugRegexCacheSize, equals(2));
        var ready = bloc.value as SurfaceReady;
        expect(ready.isValid, isFalse);
        expect(
          ready.validationErrors,
          equals(['Field "Code" does not match the required pattern.']),
        );

        // Subsequent validation reuses cached entries (size remains 2) and validates accurately
        bloc.add(
          const UpdateFormField(
            surfaceId: 'surf_regex',
            path: '/code',
            value: 'ABC-42',
          ),
        );
        expect(A2uiSurfaceBloc.debugRegexCacheSize, equals(2));
        ready = bloc.value as SurfaceReady;
        expect(ready.isValid, isTrue);
        expect(ready.validationErrors, isEmpty);

        // Populate 105 distinct patterns and verify capacity is bounded at 100
        final manyComponents = <Map<String, dynamic>>[
          for (var i = 0; i < 105; i++)
            {
              'id': 'tf_$i',
              'component': 'TextField',
              'label': 'Field $i',
              'value': {'path': '/f_$i'},
              'pattern': '^val_$i\$',
            },
        ];
        final surface = bloc.processor.groupModel.getSurface('surf_regex')!;
        for (var i = 0; i < 105; i++) {
          surface.dataModel.set('/f_$i', 'val_$i');
        }
        bloc.add(
          ProcessJsonMessage({
            'version': 'v0.9',
            'updateComponents': {
              'surfaceId': 'surf_regex',
              'components': manyComponents,
            },
          }),
        );

        expect(A2uiSurfaceBloc.debugRegexCacheSize, equals(100));
      });
    });

    group('(Issue #332: R18) maxResponseHistory', () {
      test('(Issue #332: R18) default maxResponseHistory is 100', () {
        final bloc = A2uiSurfaceBloc();
        addTearDown(bloc.close);

        expect(bloc.maxResponseHistory, equals(100));
      });

      test(
          '(Issue #332: R18) maxResponseHistory: 2 bounds _responseHistory '
          'to 2 most recent responses in FIFO order while live listeners '
          'receive all 3', () async {
        final bloc = A2uiSurfaceBloc(maxResponseHistory: 2);
        addTearDown(bloc.close);

        expect(bloc.maxResponseHistory, equals(2));

        bloc.add(
          ProcessMessages([
            CreateSurfaceMessage(
              surfaceId: 'surf_hist',
              catalogId: minimalCatalogId,
            ),
            UpdateComponentsMessage(
              surfaceId: 'surf_hist',
              components: const [
                {'id': 'btn_1', 'component': 'Text', 'text': 'Submit'},
              ],
            ),
          ]),
        );

        final liveResponses = <A2uiActionResponse>[];
        final liveSub = bloc.actionResponses.listen(liveResponses.add);
        addTearDown(liveSub.cancel);
        await Future<void>.microtask(() {});

        for (final name in ['act_1', 'act_2', 'act_3']) {
          bloc
            ..add(
              SubmitAction(
                actionName: name,
                sourceComponentId: 'btn_1',
                surfaceId: 'surf_hist',
              ),
            )
            ..add(const CompleteAction(surfaceId: 'surf_hist'));
          await Future<void>.microtask(() {});
          await Future<void>.microtask(() {});
        }

        expect(
          liveResponses.map((r) => r.actionName).toList(),
          equals(['act_1', 'act_2', 'act_3']),
        );

        final replayedResponses = <A2uiActionResponse>[];
        final lateSub = bloc.actionResponses.listen(replayedResponses.add);
        addTearDown(lateSub.cancel);
        await Future<void>.microtask(() {});
        await Future<void>.microtask(() {});

        expect(
          replayedResponses.map((r) => r.actionName).toList(),
          equals(['act_2', 'act_3']),
        );
      });

      test(
          '(Issue #332: R18) maxResponseHistory: 0 disables replay buffering '
          'for late subscribers while delivering live broadcast events',
          () async {
        final bloc = A2uiSurfaceBloc(maxResponseHistory: 0);
        addTearDown(bloc.close);

        expect(bloc.maxResponseHistory, equals(0));

        bloc.add(
          ProcessMessages([
            CreateSurfaceMessage(
              surfaceId: 'surf_zero',
              catalogId: minimalCatalogId,
            ),
            UpdateComponentsMessage(
              surfaceId: 'surf_zero',
              components: const [
                {'id': 'btn_1', 'component': 'Text', 'text': 'Submit'},
              ],
            ),
          ]),
        );

        final liveResponses = <A2uiActionResponse>[];
        final liveSub = bloc.actionResponses.listen(liveResponses.add);
        addTearDown(liveSub.cancel);
        await Future<void>.microtask(() {});

        bloc
          ..add(
            const SubmitAction(
              actionName: 'live_act',
              sourceComponentId: 'btn_1',
              surfaceId: 'surf_zero',
            ),
          )
          ..add(const CompleteAction(surfaceId: 'surf_zero'));
        await Future<void>.microtask(() {});
        await Future<void>.microtask(() {});

        expect(
          liveResponses.map((r) => r.actionName).toList(),
          equals(['live_act']),
        );

        final replayedResponses = <A2uiActionResponse>[];
        final lateSub = bloc.actionResponses.listen(replayedResponses.add);
        addTearDown(lateSub.cancel);
        await Future<void>.microtask(() {});

        expect(replayedResponses, isEmpty);
      });

      test('(Issue #332: R18) maxResponseHistory: -1 throws AssertionError',
          () {
        expect(
          () => A2uiSurfaceBloc(maxResponseHistory: -1),
          throwsA(isA<AssertionError>()),
        );
      });
    });
  });
}
