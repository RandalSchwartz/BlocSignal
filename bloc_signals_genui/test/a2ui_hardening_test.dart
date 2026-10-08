import 'dart:async';

import 'package:bloc_signals_genui/bloc_signals_genui.dart';
import 'package:test/test.dart';

class _TrackingA2uiSurfaceBloc extends A2uiSurfaceBloc {
  _TrackingA2uiSurfaceBloc();

  final List<Object> caughtErrors = [];

  @override
  void onError(Object error, StackTrace stackTrace) {
    caughtErrors.add(error);
    super.onError(error, stackTrace);
  }
}

void main() {
  const minimalCatalogId =
      'https://a2ui.org/specification/v0_9/catalogs/minimal/minimal_catalog.json';

  group('A2UI Hardening & Observability (Issue #269)', () {
    test('[F-11] stream parse errors notify onError and fatal Errors rethrow',
        () async {
      final bloc = _TrackingA2uiSurfaceBloc();
      final streamController = StreamController<dynamic>();

      bloc.add(IngestStream(streamController.stream));
      await Future<void>.delayed(Duration.zero);

      // Send invalid JSON chunk that triggers a FormatException
      streamController.add('{ invalid json ');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(bloc.caughtErrors, isNotEmpty);
      expect(bloc.caughtErrors.first, isA<FormatException>());
      expect(bloc.stateValue, isA<SurfaceError>());

      await bloc.close();
      await streamController.close();
    });

    test('[F-11] ProcessMessage notifies onError when parse/schema fails', () {
      final bloc = _TrackingA2uiSurfaceBloc();

      // Process a message with invalid catalog ID to trigger an Exception
      bloc.add(
        ProcessMessage(
          CreateSurfaceMessage(
            surfaceId: 'invalid_surf',
            catalogId: 'https://invalid.catalog/schema.json',
          ),
        ),
      );

      expect(bloc.caughtErrors, isNotEmpty);
      expect(bloc.stateValue, isA<SurfaceError>());
    });

    test('[F-16] action responses emitted before subscription are not lost',
        () async {
      final bloc = A2uiSurfaceBloc();

      bloc.add(
        const ProcessJsonMessage({
          'version': 'v0.9',
          'createSurface': {
            'surfaceId': 'surf_action',
            'catalogId': minimalCatalogId,
          },
        }),
      );

      // Dispatch action BEFORE subscribing
      bloc.add(
        const SubmitAction(
          actionName: 'early_action',
          sourceComponentId: 'btn_1',
          surfaceId: 'surf_action',
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Now attach subscriber
      final received = <A2uiActionResponse>[];
      final sub = bloc.actionResponses.listen(received.add);

      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(received, hasLength(1));
      expect(received.first.actionName, equals('early_action'));

      await sub.cancel();
      await bloc.close();
    });

    test('[F-16] SurfaceSubmitting equality includes payload', () {
      const s1 = SurfaceSubmitting(
        surfaceId: 'surf',
        actionName: 'submit',
        sourceComponentId: 'btn',
        payload: {'val': 1},
      );
      const s2 = SurfaceSubmitting(
        surfaceId: 'surf',
        actionName: 'submit',
        sourceComponentId: 'btn',
        payload: {'val': 2},
      );

      expect(
        s1 == s2,
        isFalse,
        reason: 'SurfaceSubmitting with differing payload must not be equal',
      );
    });

    test('[F-15] stateValue.surfaceId is accessible polymorphically on state',
        () {
      const sInit = SurfaceInitial();
      expect(sInit.surfaceId, isNull);

      const sStream = SurfaceStreaming(surfaceId: 's1');
      expect(sStream.surfaceId, equals('s1'));

      const sSubmit = SurfaceSubmitting(
        surfaceId: 's2',
        actionName: 'act',
        sourceComponentId: 'c1',
      );
      expect(sSubmit.surfaceId, equals('s2'));

      final sErr = SurfaceError(error: Exception(), surfaceId: 's3');
      expect(sErr.surfaceId, equals('s3'));
    });

    test(
        '[F-14] Form validation enforces required fields and blocks submission',
        () async {
      final bloc = A2uiSurfaceBloc();

      bloc.add(
        const ProcessJsonMessage({
          'version': 'v0.9',
          'createSurface': {
            'surfaceId': 'form_surf',
            'catalogId': minimalCatalogId,
          },
        }),
      );

      // Add a required field component
      bloc.add(
        const ProcessJsonMessage({
          'version': 'v0.9',
          'updateComponents': {
            'surfaceId': 'form_surf',
            'components': [
              {
                'id': 'input_email',
                'component': 'TextField',
                'required': true,
                'label': 'Email Address',
                'value': {'path': '/email'},
              },
            ],
          },
        }),
      );

      final readyState = bloc.stateValue as SurfaceReady;
      expect(readyState.isValid, isFalse);
      expect(readyState.validationErrors, isNotEmpty);
      expect(
        readyState.validationErrors.first,
        contains('"Email Address" is required'),
      );

      // Attempt to submit unvalidated form
      final receivedActions = <A2uiActionResponse>[];
      final sub = bloc.actionResponses.listen(receivedActions.add);

      bloc.add(
        const SubmitAction(
          actionName: 'submit_unvalidated',
          sourceComponentId: 'btn_submit',
          surfaceId: 'form_surf',
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Submission must be blocked!
      expect(receivedActions, isEmpty);
      expect(bloc.stateValue, isA<SurfaceReady>());
      final afterAttempt = bloc.stateValue as SurfaceReady;
      expect(afterAttempt.isValid, isFalse);

      // Now fill the field
      bloc.add(
        const UpdateFormField(
          path: '/email',
          value: 'test@example.com',
          surfaceId: 'form_surf',
        ),
      );

      final validState = bloc.stateValue as SurfaceReady;
      expect(validState.isValid, isTrue);
      expect(validState.validationErrors, isEmpty);

      // Submit valid form
      bloc.add(
        const SubmitAction(
          actionName: 'submit_valid',
          sourceComponentId: 'btn_submit',
          surfaceId: 'form_surf',
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(receivedActions, hasLength(1));
      expect(receivedActions.first.actionName, equals('submit_valid'));
      expect(
        receivedActions.first.formData['email'],
        equals('test@example.com'),
      );

      await sub.cancel();
      await bloc.close();
    });

    test('[F-17] bloc_signals_genui re-exports core A2UI types', () {
      // If re-export works, these types are accessible directly from bloc_signals_genui
      expect(SurfaceModel, isNotNull);
      expect(ComponentApi, isNotNull);
      expect(Catalog, isNotNull);
      expect(MinimalCatalog, isNotNull);
      expect(MessageProcessor, isNotNull);
    });

    test('[F-13] normalizes complex child, children, and action shorthand',
        () async {
      final bloc = A2uiSurfaceBloc();
      bloc.add(
        const ProcessJsonMessage({
          'version': 'v0.9',
          'createSurface': {
            'surfaceId': 'norm_surf',
            'catalogId': minimalCatalogId,
          },
        }),
      );

      // Ingest components with shorthand child, children, and action formats
      bloc.add(
        const ProcessJsonMessage({
          'version': 'v0.9',
          'updateComponents': {
            'surfaceId': 'norm_surf',
            'components': [
              {
                'id': 'root_col',
                'component': 'Column',
                'children': [
                  {'id': 'card_1'},
                  {'id': 'btn_1'},
                ],
              },
              {
                'id': 'card_1',
                'component': 'Card',
                'child': {'id': 'txt_1'},
              },
              {
                'id': 'txt_1',
                'component': 'Text',
                'text': 'Normalized child test',
              },
              {
                'id': 'btn_1',
                'component': 'Button',
                'child': {'id': 'txt_1'},
                'action': 'quick_submit',
              },
            ],
          },
        }),
      );

      expect(bloc.stateValue, isA<SurfaceReady>());
      final ready = bloc.stateValue as SurfaceReady;
      expect(ready.surfaceId, equals('norm_surf'));
      expect(bloc.activeSurfaceId.value, equals('norm_surf'));

      final col = ready.surface.componentsModel.get('root_col');
      expect(col, isNotNull);
      expect(col!.properties['children'], equals(['card_1', 'btn_1']));

      final card = ready.surface.componentsModel.get('card_1');
      expect(card, isNotNull);
      expect(card!.properties['child'], equals('txt_1'));

      final btn = ready.surface.componentsModel.get('btn_1');
      expect(btn, isNotNull);
      expect(btn!.properties['child'], equals('txt_1'));
      expect(btn.properties['action'], isNotNull);

      await bloc.close();
    });

    test('[F-14] Form validation enforces pattern, minLength, and maxLength',
        () async {
      final bloc = A2uiSurfaceBloc();
      bloc.add(
        const ProcessJsonMessage({
          'version': 'v0.9',
          'createSurface': {
            'surfaceId': 'rules_surf',
            'catalogId': minimalCatalogId,
          },
        }),
      );

      bloc.add(
        const ProcessJsonMessage({
          'version': 'v0.9',
          'updateComponents': {
            'surfaceId': 'rules_surf',
            'components': [
              {
                'id': 'pin_input',
                'component': 'TextField',
                'label': 'Security PIN',
                'value': {'path': '/pin'},
                'pattern': r'^\d{4}$',
                'minLength': 4,
                'maxLength': 4,
              },
            ],
          },
        }),
      );

      // 1. Initially empty
      var ready = bloc.stateValue as SurfaceReady;
      expect(ready.isValid, isTrue);

      // 2. Too short
      bloc.add(
        const UpdateFormField(
          path: '/pin',
          value: '12',
          surfaceId: 'rules_surf',
        ),
      );
      ready = bloc.stateValue as SurfaceReady;
      expect(ready.isValid, isFalse);
      expect(
        ready.validationErrors.any((e) => e.contains('at least 4 characters')),
        isTrue,
      );

      // 3. Too long
      bloc.add(
        const UpdateFormField(
          path: '/pin',
          value: '12345',
          surfaceId: 'rules_surf',
        ),
      );
      ready = bloc.stateValue as SurfaceReady;
      expect(ready.isValid, isFalse);
      expect(
        ready.validationErrors.any((e) => e.contains('at most 4 characters')),
        isTrue,
      );

      // 4. Invalid pattern (non-digits)
      bloc.add(
        const UpdateFormField(
          path: '/pin',
          value: 'abcd',
          surfaceId: 'rules_surf',
        ),
      );
      ready = bloc.stateValue as SurfaceReady;
      expect(ready.isValid, isFalse);
      expect(
        ready.validationErrors
            .any((e) => e.contains('does not match the required pattern')),
        isTrue,
      );

      // 5. Valid 4-digit PIN
      bloc.add(
        const UpdateFormField(
          path: '/pin',
          value: '1234',
          surfaceId: 'rules_surf',
        ),
      );
      ready = bloc.stateValue as SurfaceReady;
      expect(ready.isValid, isTrue);
      expect(ready.validationErrors, isEmpty);

      await bloc.close();
    });

    test('State hierarchy and ActionResponse string diagnostics and equality',
        () async {
      const initial = SurfaceInitial();
      expect(initial.surfaceId, isNull);
      expect(initial.toString(), equals('SurfaceInitial()'));

      final bloc = A2uiSurfaceBloc();
      bloc.add(
        const ProcessJsonMessage({
          'version': 'v0.9',
          'createSurface': {
            'surfaceId': 'test_diag',
            'catalogId': minimalCatalogId,
          },
        }),
      );
      bloc.add(
        const ProcessJsonMessage({
          'version': 'v0.9',
          'updateComponents': {
            'surfaceId': 'test_diag',
            'components': [
              {
                'id': 'txt_diag',
                'component': 'Text',
                'text': 'Diag',
              },
            ],
          },
        }),
      );

      final ready = bloc.stateValue as SurfaceReady;
      expect(ready.surfaceId, equals('test_diag'));
      expect(ready.toString(), contains('SurfaceReady'));
      expect(ready.hashCode, isA<int>());

      const submitting = SurfaceSubmitting(
        surfaceId: 'test_diag',
        actionName: 'act',
        sourceComponentId: 'comp',
        payload: {'k': 'v'},
      );
      expect(submitting.surfaceId, equals('test_diag'));
      expect(submitting.toString(), contains('SurfaceSubmitting'));
      expect(
        submitting,
        equals(
          const SurfaceSubmitting(
            surfaceId: 'test_diag',
            actionName: 'act',
            sourceComponentId: 'comp',
            payload: {'k': 'v'},
          ),
        ),
      );

      const error = SurfaceError(
        error: 'fatal test',
        surfaceId: 'test_diag',
      );
      expect(error.surfaceId, equals('test_diag'));
      expect(error.toString(), contains('SurfaceError'));
      expect(
        error,
        equals(
          const SurfaceError(
            error: 'fatal test',
            surfaceId: 'test_diag',
          ),
        ),
      );

      final now = DateTime.now();
      final resp1 = A2uiActionResponse(
        actionName: 'test_action',
        surfaceId: 's1',
        sourceComponentId: 'c1',
        timestamp: now,
        formData: const {
          'nested': {'k': 'v'},
        },
      );
      final resp2 = A2uiActionResponse(
        actionName: 'test_action',
        surfaceId: 's1',
        sourceComponentId: 'c1',
        timestamp: now,
        formData: const {
          'nested': {'k': 'v'},
        },
      );
      expect(resp1, equals(resp2));
      expect(resp1.toString(), contains('A2uiActionResponse'));

      await bloc.close();
    });

    test(
        'recreating an existing surfaceId safely resets and replaces surface without state error',
        () async {
      final bloc = A2uiSurfaceBloc();
      const minimalCatalogId =
          'https://a2ui.org/specification/v0_9/catalogs/minimal/minimal_catalog.json';

      // First creation
      bloc.add(
        ProcessMessages([
          CreateSurfaceMessage(
            surfaceId: 'surf_recreate',
            catalogId: minimalCatalogId,
          ),
          UpdateComponentsMessage(
            surfaceId: 'surf_recreate',
            components: [
              {
                'id': 'txt_first',
                'component': 'Text',
                'text': 'First version',
              },
            ],
          ),
        ]),
      );

      expect(bloc.stateValue, isA<SurfaceReady>());
      expect(bloc.stateValue.surfaceId, equals('surf_recreate'));

      // Re-create same surfaceId (for example on stream re-prompting or retry)
      bloc.add(
        ProcessMessages([
          CreateSurfaceMessage(
            surfaceId: 'surf_recreate',
            catalogId: minimalCatalogId,
          ),
          UpdateComponentsMessage(
            surfaceId: 'surf_recreate',
            components: [
              {
                'id': 'txt_second',
                'component': 'Text',
                'text': 'Recreated version',
              },
            ],
          ),
        ]),
      );

      expect(bloc.stateValue, isA<SurfaceReady>());
      expect(bloc.stateValue.surfaceId, equals('surf_recreate'));
      final ready = bloc.stateValue as SurfaceReady;
      expect(
        ready.surface.componentsModel.all.any((c) => c.id == 'txt_second'),
        isTrue,
      );

      await bloc.close();
    });

    group(
        '(Issue #321: R7) Recursive Deep Equality & Content-Derived HashCodes',
        () {
      test(
          '(Issue #321: R7) A2uiActionResponse deep equality and hashCode '
          'handle nested Lists, uncast Maps, and same-length differing collections',
          () {
        final ts = DateTime.utc(2026, 10, 8);
        final a = A2uiActionResponse(
          actionName: 'submit',
          surfaceId: 's1',
          sourceComponentId: 'btn1',
          timestamp: ts,
          formData: const <String, dynamic>{
            'tags': <String>['a', 'b'],
            'nested': <dynamic>[
              <dynamic, dynamic>{
                'k': 1,
                'set': <int>{10, 20},
              },
            ],
            'uncastMap': <dynamic, dynamic>{
              'inner': <int>[1, 2, 3],
            },
          },
          context: const <String, dynamic>{
            'meta': <dynamic>['x', 'y'],
          },
        );
        final b = A2uiActionResponse(
          actionName: 'submit',
          surfaceId: 's1',
          sourceComponentId: 'btn1',
          timestamp: ts,
          formData: const <String, dynamic>{
            'tags': <String>['a', 'b'],
            'nested': <dynamic>[
              <String, dynamic>{
                'k': 1,
                'set': <int>{20, 10},
              },
            ],
            'uncastMap': <String, dynamic>{
              'inner': <int>[1, 2, 3],
            },
          },
          context: const <String, dynamic>{
            'meta': <String>['x', 'y'],
          },
        );

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));

        // Same length, different list element in formData
        final diffList = A2uiActionResponse(
          actionName: 'submit',
          surfaceId: 's1',
          sourceComponentId: 'btn1',
          timestamp: ts,
          formData: const <String, dynamic>{
            'tags': <String>['a', 'c'],
            'nested': <dynamic>[
              <String, dynamic>{
                'k': 1,
                'set': <int>{10, 20},
              },
            ],
            'uncastMap': <String, dynamic>{
              'inner': <int>[1, 2, 3],
            },
          },
          context: const <String, dynamic>{
            'meta': <String>['x', 'y'],
          },
        );
        expect(a, isNot(equals(diffList)));
        expect(a.hashCode, isNot(equals(diffList.hashCode)));

        // Same length, different nested map value in context
        final diffContext = A2uiActionResponse(
          actionName: 'submit',
          surfaceId: 's1',
          sourceComponentId: 'btn1',
          timestamp: ts,
          formData: a.formData,
          context: const <String, dynamic>{
            'meta': <String>['x', 'z'],
          },
        );
        expect(a, isNot(equals(diffContext)));
        expect(a.hashCode, isNot(equals(diffContext.hashCode)));
      });

      test(
          '(Issue #321: R7) SurfaceReady and SurfaceSubmitting deep equality '
          'and hashCode handle nested Lists/Maps and distinguish same-length collections',
          () async {
        final bloc = A2uiSurfaceBloc();
        addTearDown(bloc.close);

        bloc.add(
          ProcessMessages([
            CreateSurfaceMessage(
              surfaceId: 's_eq',
              catalogId: minimalCatalogId,
            ),
            UpdateComponentsMessage(
              surfaceId: 's_eq',
              components: const [
                {'id': 't1', 'component': 'Text', 'text': 'Hello'},
              ],
            ),
          ]),
        );

        final surface = bloc.processor.groupModel.getSurface('s_eq')!;

        final ready1 = SurfaceReady(
          surfaceId: 's_eq',
          surface: surface,
          availableSurfaceIds: const <String>['s_eq', 's_other'],
          formValues: const <String, dynamic>{
            'items': <dynamic>[
              <String, dynamic>{
                'id': 1,
                'flags': <bool>[true, false],
              },
            ],
          },
          validationErrors: const <String>['err_1'],
          version: 1,
        );
        final ready2 = SurfaceReady(
          surfaceId: 's_eq',
          surface: surface,
          availableSurfaceIds: const <String>['s_eq', 's_other'],
          formValues: const <String, dynamic>{
            'items': <dynamic>[
              <dynamic, dynamic>{
                'id': 1,
                'flags': <bool>[true, false],
              },
            ],
          },
          validationErrors: const <String>['err_1'],
          version: 1,
        );
        final readyDiffNested = SurfaceReady(
          surfaceId: 's_eq',
          surface: surface,
          availableSurfaceIds: const <String>['s_eq', 's_other'],
          formValues: const <String, dynamic>{
            'items': <dynamic>[
              <String, dynamic>{
                'id': 1,
                'flags': <bool>[true, true],
              },
            ],
          },
          validationErrors: const <String>['err_1'],
          version: 1,
        );
        final readyDiffErrors = SurfaceReady(
          surfaceId: 's_eq',
          surface: surface,
          availableSurfaceIds: const <String>['s_eq', 's_other'],
          formValues: ready1.formValues,
          validationErrors: const <String>['err_2'],
          version: 1,
        );

        expect(ready1, equals(ready2));
        expect(ready1.hashCode, equals(ready2.hashCode));
        expect(ready1, isNot(equals(readyDiffNested)));
        expect(ready1.hashCode, isNot(equals(readyDiffNested.hashCode)));
        expect(ready1, isNot(equals(readyDiffErrors)));
        expect(ready1.hashCode, isNot(equals(readyDiffErrors.hashCode)));

        const sub1 = SurfaceSubmitting(
          surfaceId: 's_eq',
          actionName: 'act',
          sourceComponentId: 'btn',
          payload: <String, dynamic>{
            'nestedList': <dynamic>[
              <String, dynamic>{
                'k': <int>[1, 2],
              },
            ],
          },
        );
        const sub2 = SurfaceSubmitting(
          surfaceId: 's_eq',
          actionName: 'act',
          sourceComponentId: 'btn',
          payload: <String, dynamic>{
            'nestedList': <dynamic>[
              <dynamic, dynamic>{
                'k': <int>[1, 2],
              },
            ],
          },
        );
        const subDiff = SurfaceSubmitting(
          surfaceId: 's_eq',
          actionName: 'act',
          sourceComponentId: 'btn',
          payload: <String, dynamic>{
            'nestedList': <dynamic>[
              <String, dynamic>{
                'k': <int>[1, 9],
              },
            ],
          },
        );

        expect(sub1, equals(sub2));
        expect(sub1.hashCode, equals(sub2.hashCode));
        expect(sub1, isNot(equals(subDiff)));
        expect(sub1.hashCode, isNot(equals(subDiff.hashCode)));
      });

      test(
          '(Issue #321: R7) deep equality and hashCode cover Sets of nested '
          'collections, non-List Iterables, and self-referential cycles', () {
        final ts = DateTime.utc(2026, 10, 8);

        // Sets containing nested maps/lists (where b.contains(elementA) is false
        // by identity, requiring deep structural element matching)
        final setResp1 = A2uiActionResponse(
          actionName: 'set_act',
          surfaceId: 's1',
          sourceComponentId: 'c1',
          timestamp: ts,
          formData: <String, dynamic>{
            'setOfMaps': const <Map<String, int>>{
              <String, int>{'a': 1},
              <String, int>{'b': 2},
            },
            'iterable': <int>[10, 20, 30].where((x) => x > 0),
          },
        );
        final setResp2 = A2uiActionResponse(
          actionName: 'set_act',
          surfaceId: 's1',
          sourceComponentId: 'c1',
          timestamp: ts,
          formData: <String, dynamic>{
            'setOfMaps': const <Map<String, int>>{
              <String, int>{'b': 2},
              <String, int>{'a': 1},
            },
            'iterable': <int>[10, 20, 30].map((x) => x),
          },
        );
        final setRespDiff = A2uiActionResponse(
          actionName: 'set_act',
          surfaceId: 's1',
          sourceComponentId: 'c1',
          timestamp: ts,
          formData: <String, dynamic>{
            'setOfMaps': const <Map<String, int>>{
              <String, int>{'a': 1},
              <String, int>{'b': 99},
            },
            'iterable': <int>[10, 20, 30].map((x) => x),
          },
        );
        final setRespDiffLen = A2uiActionResponse(
          actionName: 'set_act',
          surfaceId: 's1',
          sourceComponentId: 'c1',
          timestamp: ts,
          formData: <String, dynamic>{
            'setOfMaps': const <Map<String, int>>{
              <String, int>{'a': 1},
            },
            'iterable': <int>[10, 20].map((x) => x),
          },
        );
        final iterDiffElem = A2uiActionResponse(
          actionName: 'set_act',
          surfaceId: 's1',
          sourceComponentId: 'c1',
          timestamp: ts,
          formData: <String, dynamic>{
            'setOfMaps': setResp1.formData['setOfMaps'],
            'iterable': <int>[10, 99, 30].where((x) => x > 0),
          },
        );
        final iterDiffLen = A2uiActionResponse(
          actionName: 'set_act',
          surfaceId: 's1',
          sourceComponentId: 'c1',
          timestamp: ts,
          formData: <String, dynamic>{
            'setOfMaps': setResp1.formData['setOfMaps'],
            'iterable': <int>[10, 20].where((x) => x > 0),
          },
        );

        expect(setResp1, equals(setResp2));
        expect(setResp1.hashCode, equals(setResp2.hashCode));
        expect(setResp1, isNot(equals(setRespDiff)));
        expect(setResp1, isNot(equals(setRespDiffLen)));
        expect(setResp1, isNot(equals(iterDiffElem)));
        expect(setResp1, isNot(equals(iterDiffLen)));

        // Self-referential cycle defense in Map, List, and Set
        final cyclicMapA = <String, dynamic>{'k': 1};
        cyclicMapA['self'] = cyclicMapA;
        final cyclicMapB = <String, dynamic>{'k': 1};
        cyclicMapB['self'] = cyclicMapB;

        final cyclicListA = <dynamic>[1];
        cyclicListA.add(cyclicListA);
        final cyclicListB = <dynamic>[1];
        cyclicListB.add(cyclicListB);

        final cyclicSetA = <dynamic>{};
        cyclicSetA.add(cyclicSetA);
        final cyclicSetB = <dynamic>{};
        cyclicSetB.add(cyclicSetB);

        final cyc1 = A2uiActionResponse(
          actionName: 'cyc',
          surfaceId: 's1',
          sourceComponentId: 'c1',
          timestamp: ts,
          formData: <String, dynamic>{
            'map': cyclicMapA,
            'list': cyclicListA,
            'set': cyclicSetA,
          },
        );
        final cyc2 = A2uiActionResponse(
          actionName: 'cyc',
          surfaceId: 's1',
          sourceComponentId: 'c1',
          timestamp: ts,
          formData: <String, dynamic>{
            'map': cyclicMapB,
            'list': cyclicListB,
            'set': cyclicSetB,
          },
        );

        expect(cyc1, equals(cyc2));
        expect(cyc1.hashCode, equals(cyc2.hashCode));
      });
    });
  });
}
