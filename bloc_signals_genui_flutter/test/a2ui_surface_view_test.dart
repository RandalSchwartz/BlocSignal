import 'package:bloc_signals_genui/bloc_signals_genui.dart';
import 'package:bloc_signals_genui_flutter/bloc_signals_genui_flutter.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/safe_prop_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

class _CustomComponentApi implements ComponentApi {
  _CustomComponentApi({required this.name, required this.schema});

  @override
  final String name;

  @override
  final Schema schema;
}

final _cardCatalog = Catalog<ComponentApi, FunctionImplementation>(
  id: 'https://custom.catalog/card.json',
  components: [
    ...MinimalCatalog().components.values,
    _CustomComponentApi(
      name: 'Card',
      schema: Schema.fromMap(const <String, Object?>{
        'properties': <String, Object?>{
          'child': <String, Object?>{},
          'children': <String, Object?>{
            'type': 'array',
          },
          'title': <String, Object?>{'type': 'string'},
        },
      }),
    ),
  ],
);

void main() {
  const minimalCatalogId =
      'https://a2ui.org/specification/v0_9/catalogs/minimal/minimal_catalog.json';

  group('A2uiSurfaceView', () {
    testWidgets('renders placeholder on SurfaceInitial', (tester) async {
      final bloc = A2uiSurfaceBloc();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: A2uiSurfaceView(
              bloc: bloc,
              placeholderBuilder: (context) =>
                  const Text('Initial Placeholder'),
            ),
          ),
        ),
      );

      expect(find.text('Initial Placeholder'), findsOneWidget);
      await bloc.close();
    });

    testWidgets('renders default placeholder when none provided',
        (tester) async {
      final bloc = A2uiSurfaceBloc();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: A2uiSurfaceView(
              bloc: bloc,
            ),
          ),
        ),
      );

      expect(find.byType(SizedBox), findsWidgets);
      await bloc.close();
    });

    testWidgets('renders custom streaming indicator on SurfaceStreaming',
        (tester) async {
      final bloc = A2uiSurfaceBloc();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: A2uiSurfaceView(
              bloc: bloc,
              streamingBuilder: (context, streaming) => Text(
                'Streaming: ${streaming.messageCount}',
              ),
            ),
          ),
        ),
      );

      bloc.emitForTest(const SurfaceStreaming(messageCount: 5));
      await tester.pump();

      expect(find.text('Streaming: 5'), findsOneWidget);
      await bloc.close();
    });

    testWidgets('renders default streaming indicator on SurfaceStreaming',
        (tester) async {
      final bloc = A2uiSurfaceBloc();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: A2uiSurfaceView(
              bloc: bloc,
            ),
          ),
        ),
      );

      bloc.emitForTest(const SurfaceStreaming(messageCount: 3));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Generating UI (3 chunks)...'), findsOneWidget);
      await bloc.close();
    });

    testWidgets('renders submitting view on SurfaceSubmitting', (tester) async {
      final bloc = A2uiSurfaceBloc();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: A2uiSurfaceView(
              bloc: bloc,
              submittingBuilder: (context, submitting) => Text(
                'Submitting: ${submitting.actionName}',
              ),
            ),
          ),
        ),
      );

      bloc.emitForTest(
        const SurfaceSubmitting(
          surfaceId: 'surf-1',
          actionName: 'order_pizza',
          sourceComponentId: 'btn-1',
        ),
      );
      await tester.pump();

      expect(find.text('Submitting: order_pizza'), findsOneWidget);
      await bloc.close();
    });

    testWidgets('renders default submitting barrier on SurfaceSubmitting',
        (tester) async {
      final bloc = A2uiSurfaceBloc();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: A2uiSurfaceView(
              bloc: bloc,
            ),
          ),
        ),
      );

      bloc.emitForTest(
        const SurfaceSubmitting(
          surfaceId: 'surf-1',
          actionName: 'process_payment',
          sourceComponentId: 'btn-pay',
        ),
      );
      await tester.pump();

      expect(find.byType(ModalBarrier), findsWidgets);
      expect(find.text('Submitting process_payment...'), findsOneWidget);
      await bloc.close();
    });

    testWidgets('renders error view on SurfaceError', (tester) async {
      final bloc = A2uiSurfaceBloc();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: A2uiSurfaceView(
              bloc: bloc,
              errorBuilder: (context, error) => Text(
                'Error: ${error.error}',
              ),
            ),
          ),
        ),
      );

      bloc.emitForTest(
        const SurfaceError(
          error: 'Something went wrong',
          surfaceId: 'surf-1',
        ),
      );
      await tester.pump();

      expect(find.text('Error: Something went wrong'), findsOneWidget);
      await bloc.close();
    });

    testWidgets('renders default error card on SurfaceError', (tester) async {
      final bloc = A2uiSurfaceBloc();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: A2uiSurfaceView(
              bloc: bloc,
            ),
          ),
        ),
      );

      bloc.emitForTest(
        const SurfaceError(
          error: 'Connection timeout',
          surfaceId: 'surf-1',
        ),
      );
      await tester.pump();

      expect(find.text('Generative UI Error'), findsOneWidget);
      expect(find.text('Connection timeout'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      await bloc.close();
    });

    testWidgets('renders empty surface when componentsModel has no components',
        (tester) async {
      final bloc = A2uiSurfaceBloc()
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 'surf-empty',
              'catalogId': minimalCatalogId,
            },
          }),
        );

      final surface = bloc.processor.groupModel.getSurface('surf-empty')!;
      bloc.emitForTest(
        SurfaceReady(
          surfaceId: 'surf-empty',
          surface: surface,
          availableSurfaceIds: const ['surf-empty'],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: A2uiSurfaceView(
              bloc: bloc,
            ),
          ),
        ),
      );

      await tester.pump();
      expect(bloc.value, isA<SurfaceReady>());
      expect(find.byType(SizedBox), findsWidgets);
      await bloc.close();
    });

    testWidgets('updates tree when didUpdateWidget is called with new surface',
        (tester) async {
      final bloc = A2uiSurfaceBloc()
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 'surf-update',
              'catalogId': minimalCatalogId,
            },
          }),
        )
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateComponents': {
              'surfaceId': 'surf-update',
              'components': [
                {
                  'id': 'txt-1',
                  'component': 'Text',
                  'text': 'First Version',
                },
              ],
            },
          }),
        );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: A2uiSurfaceView(
              bloc: bloc,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('First Version'), findsOneWidget);

      // Re-pump widget tree after emitting new state
      bloc.add(
        const ProcessJsonMessage({
          'version': 'v0.9',
          'updateComponents': {
            'surfaceId': 'surf-update',
            'components': [
              {
                'id': 'txt-1',
                'component': 'Text',
                'text': 'Second Version',
              },
            ],
          },
        }),
      );
      await tester.pump();
      expect(find.text('Second Version'), findsOneWidget);

      await bloc.close();
    });

    testWidgets('handles cyclic or mutual child references gracefully',
        (tester) async {
      final bloc = A2uiSurfaceBloc()
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 'surf-cycle',
              'catalogId': minimalCatalogId,
            },
          }),
        )
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateComponents': {
              'surfaceId': 'surf-cycle',
              'components': [
                {
                  'id': 'node-a',
                  'component': 'Text',
                  'text': 'Node A',
                  'child': 'node-b',
                },
                {
                  'id': 'node-b',
                  'component': 'Text',
                  'text': 'Node B',
                  'child': 'node-a',
                },
              ],
            },
          }),
        );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: A2uiSurfaceView(
              bloc: bloc,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Node A'), findsOneWidget);
      expect(find.text('Node B'), findsOneWidget);

      await bloc.close();
    });

    testWidgets('handles missing child component ID gracefully',
        (tester) async {
      final bloc = A2uiSurfaceBloc()
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 'surf-missing-child',
              'catalogId': minimalCatalogId,
            },
          }),
        );

      await tester.pump();
      final surface =
          bloc.processor.groupModel.getSurface('surf-missing-child')!;
      surface.componentsModel.addComponent(
        ComponentModel('row-missing', 'Row', {
          'children': ['ghost-child'],
        }),
      );
      bloc.emitForTest(
        SurfaceReady(
          surfaceId: 'surf-missing-child',
          surface: surface,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: A2uiSurfaceView(
              bloc: bloc,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('missing_ghost-child')), findsOneWidget);

      await bloc.close();
    });

    testWidgets('renders multiple root components in a Column', (tester) async {
      final bloc = A2uiSurfaceBloc()
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 'surf-roots',
              'catalogId': minimalCatalogId,
            },
          }),
        )
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateComponents': {
              'surfaceId': 'surf-roots',
              'components': [
                {
                  'id': 'root-1',
                  'component': 'Text',
                  'text': 'Root One',
                },
                {
                  'id': 'root-2',
                  'component': 'Text',
                  'text': 'Root Two',
                },
              ],
            },
          }),
        );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: A2uiSurfaceView(
              bloc: bloc,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Root One'), findsOneWidget);
      expect(find.text('Root Two'), findsOneWidget);

      await bloc.close();
    });

    testWidgets(
      're-initializes binders when didUpdateWidget has different surface'
      ' but same version',
      (tester) async {
        final bloc = A2uiSurfaceBloc()
          ..add(
            const ProcessJsonMessage({
              'version': 'v0.9',
              'createSurface': {
                'surfaceId': 'surf-identical-check',
                'catalogId': minimalCatalogId,
              },
            }),
          )
          ..add(
            const ProcessJsonMessage({
              'version': 'v0.9',
              'updateComponents': {
                'surfaceId': 'surf-identical-check',
                'components': [
                  {
                    'id': 'txt-check',
                    'component': 'Text',
                    'text': 'Initial Surface Text',
                  },
                ],
              },
            }),
          );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: A2uiSurfaceView(
                bloc: bloc,
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.text('Initial Surface Text'), findsOneWidget);

        final ready = bloc.value as SurfaceReady;
        // Construct a new SurfaceModel with same version but different instance
        final newSurface = SurfaceModel(
          ready.surface.id,
          catalog: ready.surface.catalog,
        );
        newSurface.componentsModel.addComponent(
          ComponentModel(
            'txt-check',
            'Text',
            {'text': 'Updated Surface Text'},
          ),
        );
        bloc.emitForTest(
          SurfaceReady(
            surfaceId: ready.surfaceId,
            surface: newSurface,
            version: ready.version,
          ),
        );
        await tester.pump();
        expect(find.text('Updated Surface Text'), findsOneWidget);

        // Construct a surface with txt-check removed to test binder pruning
        final emptySurface = SurfaceModel(
          ready.surface.id,
          catalog: ready.surface.catalog,
        );
        bloc.emitForTest(
          SurfaceReady(
            surfaceId: ready.surfaceId,
            surface: emptySurface,
            version: ready.version,
          ),
        );
        await tester.pump();
        expect(find.text('Updated Surface Text'), findsNothing);

        await bloc.close();
      },
    );

    testWidgets(
      'resolves children when items are Maps with id or ChildNode references',
      (tester) async {
        final bloc = A2uiSurfaceBloc(catalogs: [_cardCatalog])
          ..add(
            const ProcessJsonMessage({
              'version': 'v0.9',
              'createSurface': {
                'surfaceId': 'surf-map-children',
                'catalogId': 'https://custom.catalog/card.json',
              },
            }),
          )
          ..add(
            const ProcessJsonMessage({
              'version': 'v0.9',
              'updateComponents': {
                'surfaceId': 'surf-map-children',
                'components': [
                  {
                    'id': 'root-card',
                    'component': 'Card',
                    'child': {'id': 'child-txt'},
                    'children': [
                      {'id': 'child-txt'},
                      'raw-child-id',
                    ],
                  },
                  {
                    'id': 'child-txt',
                    'component': 'Text',
                    'text': 'Map Child Text',
                  },
                ],
              },
            }),
          );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: A2uiSurfaceView(
                bloc: bloc,
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.text('Map Child Text'), findsOneWidget);

        // Also test ChildNode resolution in child property
        bloc.add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateComponents': {
              'surfaceId': 'surf-map-children',
              'components': [
                {
                  'id': 'card-node',
                  'component': 'Card',
                  'child': {'id': 'child-txt'},
                },
              ],
            },
          }),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: A2uiSurfaceView(
                bloc: bloc,
              ),
            ),
          ),
        );
        await tester.pump();

        // Also test replacing a component model instance in didUpdateWidget
        // which triggers existingBinder?.dispose() in _reconcileBinders
        bloc.add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateComponents': {
              'surfaceId': 'surf-map-children',
              'components': [
                {
                  'id': 'card-node',
                  'component': 'Card',
                  'child': {'id': 'child-txt'},
                  'title': 'New Title',
                },
              ],
            },
          }),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: A2uiSurfaceView(
                bloc: bloc,
              ),
            ),
          ),
        );
        await tester.pump();

        await bloc.close();
      },
    );

    testWidgets(
      'reproduction blocker 1: TextField does not clobber user typing with '
      'stale external emission',
      (tester) async {
        final bloc = A2uiSurfaceBloc()
          ..add(
            const ProcessJsonMessage({
              'version': 'v0.9',
              'createSurface': {
                'surfaceId': 'surf-tf-race',
                'catalogId': minimalCatalogId,
              },
            }),
          )
          ..add(
            const ProcessJsonMessage({
              'version': 'v0.9',
              'updateComponents': {
                'surfaceId': 'surf-tf-race',
                'components': [
                  {
                    'id': 'tf-input',
                    'component': 'TextField',
                    'label': 'Query',
                    'value': {'path': '/query'},
                  },
                ],
              },
            }),
          );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: A2uiSurfaceView(
                bloc: bloc,
              ),
            ),
          ),
        );
        await tester.pump();

        final tfFinder = find.byType(TextField);
        await tester.enterText(tfFinder, 'hel');
        await tester.pump();

        // Simulate user typing more while focus is active
        await tester.enterText(tfFinder, 'hello world');
        await tester.pump();

        // Simulate an older external emission with stale value 'hel'
        bloc.add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateDataModel': {
              'surfaceId': 'surf-tf-race',
              'path': '/query',
              'value': 'hel',
            },
          }),
        );
        await tester.pump();

        // While focused, local typing 'hello world' must not be clobbered
        // by stale 'hel'
        expect(
          tester.widget<TextField>(tfFinder).controller!.text,
          equals('hello world'),
        );

        await bloc.close();
      },
    );

    testWidgets(
      'reproduction blocker 2: dynamic child resolution via resolvedProps '
      'avoids duplicate root renders',
      (tester) async {
        final bloc = A2uiSurfaceBloc(catalogs: [_cardCatalog])
          ..add(
            const ProcessJsonMessage({
              'version': 'v0.9',
              'createSurface': {
                'surfaceId': 'surf-dynamic-child',
                'catalogId': 'https://custom.catalog/card.json',
              },
            }),
          )
          ..add(
            const ProcessJsonMessage({
              'version': 'v0.9',
              'updateDataModel': {
                'surfaceId': 'surf-dynamic-child',
                'path': '/activeChild',
                'value': 'child-txt',
              },
            }),
          )
          ..add(
            const ProcessJsonMessage({
              'version': 'v0.9',
              'updateComponents': {
                'surfaceId': 'surf-dynamic-child',
                'components': [
                  {
                    'id': 'root-card',
                    'component': 'Card',
                    'child': {'path': '/activeChild'},
                  },
                  {
                    'id': 'child-txt',
                    'component': 'Text',
                    'text': 'Dynamic Child Text',
                  },
                ],
              },
            }),
          );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: A2uiSurfaceView(
                bloc: bloc,
              ),
            ),
          ),
        );
        await tester.pump();

        // 'Dynamic Child Text' should be rendered exactly once inside Card
        expect(find.text('Dynamic Child Text'), findsOneWidget);

        await bloc.close();
      },
    );

    testWidgets(
      'reproduction blocker 3: dynamic components are wrapped in KeyedSubtree '
      'with stable keys',
      (tester) async {
        final bloc = A2uiSurfaceBloc()
          ..add(
            const ProcessJsonMessage({
              'version': 'v0.9',
              'createSurface': {
                'surfaceId': 'surf-keyed-subtree',
                'catalogId': minimalCatalogId,
              },
            }),
          )
          ..add(
            const ProcessJsonMessage({
              'version': 'v0.9',
              'updateComponents': {
                'surfaceId': 'surf-keyed-subtree',
                'components': [
                  {
                    'id': 'col-1',
                    'component': 'Column',
                    'children': ['item-a', 'item-b'],
                  },
                  {
                    'id': 'item-a',
                    'component': 'Text',
                    'text': 'Alpha',
                  },
                  {
                    'id': 'item-b',
                    'component': 'Text',
                    'text': 'Beta',
                  },
                ],
              },
            }),
          );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: A2uiSurfaceView(
                bloc: bloc,
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byKey(const ValueKey('a2ui_item-a')), findsOneWidget);
        expect(find.byKey(const ValueKey('a2ui_item-b')), findsOneWidget);

        await bloc.close();
      },
    );

    testWidgets(
      'reproduction blocker 4: incremental binder reconciliation preserves '
      'unmodified binders across versions',
      (tester) async {
        final bloc = A2uiSurfaceBloc()
          ..add(
            const ProcessJsonMessage({
              'version': 'v0.9',
              'createSurface': {
                'surfaceId': 'surf-binder-reuse',
                'catalogId': minimalCatalogId,
              },
            }),
          )
          ..add(
            const ProcessJsonMessage({
              'version': 'v0.9',
              'updateDataModel': {
                'surfaceId': 'surf-binder-reuse',
                'path': '/val',
                'value': 'Initial',
              },
            }),
          )
          ..add(
            const ProcessJsonMessage({
              'version': 'v0.9',
              'updateComponents': {
                'surfaceId': 'surf-binder-reuse',
                'components': [
                  {
                    'id': 'txt-1',
                    'component': 'Text',
                    'text': {'path': '/val'},
                  },
                ],
              },
            }),
          );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: A2uiSurfaceView(
                bloc: bloc,
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Initial'), findsOneWidget);

        // Update data only (increments version)
        bloc.add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateDataModel': {
              'surfaceId': 'surf-binder-reuse',
              'path': '/val',
              'value': 'Updated',
            },
          }),
        );
        await tester.pump();

        expect(find.text('Updated'), findsOneWidget);

        await bloc.close();
      },
    );

    testWidgets(
      'reproduction blocker 5: recursive circular child references do not '
      'crash with stack overflow',
      (tester) async {
        final bloc = A2uiSurfaceBloc()
          ..add(
            const ProcessJsonMessage({
              'version': 'v0.9',
              'createSurface': {
                'surfaceId': 'surf-circular',
                'catalogId': minimalCatalogId,
              },
            }),
          );

        await tester.pump();
        final surface = bloc.processor.groupModel.getSurface('surf-circular')!;
        surface.componentsModel.addComponent(
          ComponentModel('col-a', 'Column', {
            'children': ['col-b'],
          }),
        );
        surface.componentsModel.addComponent(
          ComponentModel('col-b', 'Column', {
            'children': ['col-a'],
          }),
        );
        bloc.emitForTest(
          SurfaceReady(
            surfaceId: 'surf-circular',
            surface: surface,
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: A2uiSurfaceView(
                bloc: bloc,
              ),
            ),
          ),
        );
        await tester.pump();

        // Must render circular reference guard placeholder instead of throwing
        // StackOverflowError
        expect(
          find.byKey(const ValueKey('circular_ref_col-a')),
          findsOneWidget,
        );

        await bloc.close();
      },
    );

    testWidgets(
      'dismisses submitting barrier and renders error banner on '
      'CancelSubmission',
      (tester) async {
        final bloc = A2uiSurfaceBloc()
          ..add(
            const ProcessJsonMessage({
              'version': 'v0.9',
              'createSurface': {
                'surfaceId': 'surf-cancel-ui',
                'catalogId': minimalCatalogId,
              },
            }),
          )
          ..add(
            const ProcessJsonMessage({
              'version': 'v0.9',
              'updateComponents': {
                'surfaceId': 'surf-cancel-ui',
                'components': [
                  {
                    'id': 'field_user',
                    'component': 'TextField',
                    'label': 'Username',
                    'value': {'path': '/username'},
                  },
                  {
                    'id': 'btn_submit',
                    'component': 'Button',
                    'child': 'txt_submit',
                    'action': 'save_user',
                  },
                  {
                    'id': 'txt_submit',
                    'component': 'Text',
                    'text': 'Submit',
                  },
                ],
              },
            }),
          );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: A2uiSurfaceView(
                bloc: bloc,
              ),
            ),
          ),
        );
        await tester.pump();

        // Enter text into the TextField
        await tester.enterText(find.byType(TextField), 'John Doe');
        await tester.pump();

        // Tap submit button to trigger SubmitAction -> transitions to
        // SurfaceSubmitting.
        await tester.tap(find.text('Submit'));
        await tester.pump();

        expect(bloc.value, isA<SurfaceSubmitting>());
        expect(
          find.byKey(const ValueKey('a2ui_submitting_barrier')),
          findsOneWidget,
        );
        expect(find.text('Submitting save_user...'), findsOneWidget);

        // Now cancel submission with error
        bloc.add(
          const CancelSubmission(
            surfaceId: 'surf-cancel-ui',
            error: 'Database transaction aborted',
          ),
        );
        await tester.pump();

        // Verify barrier is dismissed
        expect(
          find.byKey(const ValueKey('a2ui_submitting_barrier')),
          findsNothing,
        );
        expect(find.text('Submitting save_user...'), findsNothing);

        // Verify validation error banner is displayed
        expect(find.text('Database transaction aborted'), findsOneWidget);

        // Verify entered text is preserved
        expect(find.text('John Doe'), findsOneWidget);

        await bloc.close();
      },
    );

    testWidgets(
      'renders custom validationErrorsBuilder when provided',
      (tester) async {
        final bloc = A2uiSurfaceBloc()
          ..add(
            const ProcessJsonMessage({
              'version': 'v0.9',
              'createSurface': {
                'surfaceId': 'surf-custom-err',
                'catalogId': minimalCatalogId,
              },
            }),
          )
          ..add(
            const ProcessJsonMessage({
              'version': 'v0.9',
              'updateComponents': {
                'surfaceId': 'surf-custom-err',
                'components': [
                  {
                    'id': 'txt_item',
                    'component': 'Text',
                    'text': 'Item',
                  },
                ],
              },
            }),
          );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: A2uiSurfaceView(
                bloc: bloc,
                validationErrorsBuilder: (context, errors) => Container(
                  key: const ValueKey('custom_error_box'),
                  child: Text('Custom Error Count: ${errors.length}'),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        // Initially valid, no errors
        expect(find.byKey(const ValueKey('custom_error_box')), findsNothing);

        // Emit recovery with errors
        bloc.add(
          const CancelSubmission(
            surfaceId: 'surf-custom-err',
            error: 'Invalid token',
          ),
        );
        await tester.pump();

        expect(find.byKey(const ValueKey('custom_error_box')), findsOneWidget);
        expect(find.text('Custom Error Count: 1'), findsOneWidget);

        await bloc.close();
      },
    );

    testWidgets(
      'A2uiComponentContext cancelSubmission and completeAction '
      'dispatch events',
      (tester) async {
        final bloc = A2uiSurfaceBloc();
        final component = ComponentModel(
          'comp-1',
          'Text',
          const {},
        );

        A2uiComponentContext(
          component: component,
          props: const {},
          surfaceBloc: bloc,
          buildChildCallback: (id) => const SizedBox(),
          buildChildrenCallback: (ids) => const [],
          surfaceId: 'surf-ctx',
        )
          ..cancelSubmission(error: 'User cancelled')
          ..completeAction();

        // Verify bloc handles them without crash
        await bloc.close();
      },
    );

    testWidgets(
      'renders targeted surface when surfaceId is specified, even if another '
      'surface is active',
      (tester) async {
        final bloc = A2uiSurfaceBloc()
          ..add(
            const ProcessJsonMessage({
              'version': 'v0.9',
              'createSurface': {
                'surfaceId': 'surf-1',
                'catalogId': minimalCatalogId,
              },
            }),
          )
          ..add(
            const ProcessJsonMessage({
              'version': 'v0.9',
              'updateComponents': {
                'surfaceId': 'surf-1',
                'components': [
                  {
                    'id': 'txt-1',
                    'component': 'Text',
                    'text': 'Surface 1 Content',
                  },
                ],
              },
            }),
          )
          ..add(
            const ProcessJsonMessage({
              'version': 'v0.9',
              'createSurface': {
                'surfaceId': 'surf-2',
                'catalogId': minimalCatalogId,
              },
            }),
          )
          ..add(
            const ProcessJsonMessage({
              'version': 'v0.9',
              'updateComponents': {
                'surfaceId': 'surf-2',
                'components': [
                  {
                    'id': 'txt-2',
                    'component': 'Text',
                    'text': 'Surface 2 Content',
                  },
                ],
              },
            }),
          );

        // Global active surface is surf-2
        expect(bloc.value.surfaceId, equals('surf-2'));

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: A2uiSurfaceView(
                bloc: bloc,
                surfaceId: 'surf-1',
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Surface 1 Content'), findsOneWidget);
        expect(find.text('Surface 2 Content'), findsNothing);

        await bloc.close();
      },
    );

    testWidgets(
      'renders initial placeholder when targeted surfaceId does not exist',
      (tester) async {
        final bloc = A2uiSurfaceBloc()
          ..add(
            const ProcessJsonMessage({
              'version': 'v0.9',
              'createSurface': {
                'surfaceId': 'surf-1',
                'catalogId': minimalCatalogId,
              },
            }),
          );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: A2uiSurfaceView(
                bloc: bloc,
                surfaceId: 'surf-nonexistent',
                placeholderBuilder: (context) =>
                    const Text('Custom Target Placeholder'),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Custom Target Placeholder'), findsOneWidget);

        await bloc.close();
      },
    );

    testWidgets(
      'renders concurrent multi-surface views side by side in a Row',
      (tester) async {
        final bloc = A2uiSurfaceBloc()
          ..add(
            const ProcessJsonMessage({
              'version': 'v0.9',
              'createSurface': {
                'surfaceId': 'surf-left',
                'catalogId': minimalCatalogId,
              },
            }),
          )
          ..add(
            const ProcessJsonMessage({
              'version': 'v0.9',
              'updateComponents': {
                'surfaceId': 'surf-left',
                'components': [
                  {
                    'id': 'left-txt',
                    'component': 'Text',
                    'text': 'Left Pane',
                  },
                ],
              },
            }),
          )
          ..add(
            const ProcessJsonMessage({
              'version': 'v0.9',
              'createSurface': {
                'surfaceId': 'surf-right',
                'catalogId': minimalCatalogId,
              },
            }),
          )
          ..add(
            const ProcessJsonMessage({
              'version': 'v0.9',
              'updateComponents': {
                'surfaceId': 'surf-right',
                'components': [
                  {
                    'id': 'right-txt',
                    'component': 'Text',
                    'text': 'Right Pane',
                  },
                ],
              },
            }),
          );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  Expanded(
                    child: A2uiSurfaceView(
                      bloc: bloc,
                      surfaceId: 'surf-left',
                    ),
                  ),
                  Expanded(
                    child: A2uiSurfaceView(
                      bloc: bloc,
                      surfaceId: 'surf-right',
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Left Pane'), findsOneWidget);
        expect(find.text('Right Pane'), findsOneWidget);

        await bloc.close();
      },
    );

    testWidgets(
      'renders targeted streaming, submitting, and error states when '
      'surfaceId matches',
      (tester) async {
        final bloc = A2uiSurfaceBloc();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: A2uiSurfaceView(
                bloc: bloc,
                surfaceId: 'surf-target',
                streamingBuilder: (context, streaming) =>
                    Text('Streaming ${streaming.surfaceId}'),
                submittingBuilder: (context, submitting) =>
                    Text('Submitting ${submitting.surfaceId}'),
                errorBuilder: (context, error) =>
                    Text('Error ${error.surfaceId}: ${error.error}'),
              ),
            ),
          ),
        );

        // Streaming for targeted surface
        bloc.emitForTest(
          const SurfaceStreaming(
            surfaceId: 'surf-target',
            messageCount: 3,
          ),
        );
        await tester.pump();
        expect(find.text('Streaming surf-target'), findsOneWidget);

        // Streaming for another surface: targeted view falls back to initial/ready
        bloc.emitForTest(
          const SurfaceStreaming(
            surfaceId: 'surf-other',
            messageCount: 1,
          ),
        );
        await tester.pump();
        expect(find.text('Streaming surf-target'), findsNothing);

        // Submitting for targeted surface
        bloc.emitForTest(
          const SurfaceSubmitting(
            surfaceId: 'surf-target',
            actionName: 'checkout',
            sourceComponentId: 'btn-1',
          ),
        );
        await tester.pump();
        expect(find.text('Submitting surf-target'), findsOneWidget);

        // Error for targeted surface
        bloc.emitForTest(
          const SurfaceError(
            surfaceId: 'surf-target',
            error: 'Failed to submit',
          ),
        );
        await tester.pump();
        expect(
          find.text('Error surf-target: Failed to submit'),
          findsOneWidget,
        );

        await bloc.close();
      },
    );

    testWidgets(
      'A2uiComponentContext selectSurface dispatches SelectSurface to bloc',
      (tester) async {
        final bloc = A2uiSurfaceBloc()
          ..add(
            const ProcessJsonMessage({
              'version': 'v0.9',
              'createSurface': {
                'surfaceId': 'surf-tab-1',
                'catalogId': minimalCatalogId,
              },
            }),
          )
          ..add(
            const ProcessJsonMessage({
              'version': 'v0.9',
              'updateComponents': {
                'surfaceId': 'surf-tab-1',
                'components': [
                  {
                    'id': 'tab-1-txt',
                    'component': 'Text',
                    'text': 'Tab 1 View',
                  },
                ],
              },
            }),
          )
          ..add(
            const ProcessJsonMessage({
              'version': 'v0.9',
              'createSurface': {
                'surfaceId': 'surf-tab-2',
                'catalogId': minimalCatalogId,
              },
            }),
          )
          ..add(
            const ProcessJsonMessage({
              'version': 'v0.9',
              'updateComponents': {
                'surfaceId': 'surf-tab-2',
                'components': [
                  {
                    'id': 'tab-2-txt',
                    'component': 'Text',
                    'text': 'Tab 2 View',
                  },
                ],
              },
            }),
          );

        // Default view renders active surface
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: A2uiSurfaceView(
                bloc: bloc,
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Tab 2 View'), findsOneWidget);
        expect(find.text('Tab 1 View'), findsNothing);

        final component = ComponentModel(
          'btn-tab',
          'Button',
          const {},
        );

        A2uiComponentContext(
          component: component,
          props: const {},
          surfaceBloc: bloc,
          buildChildCallback: (id) => const SizedBox(),
          buildChildrenCallback: (ids) => const [],
          surfaceId: 'surf-tab-2',
        ).selectSurface('surf-tab-1');
        await tester.pump();

        expect(find.text('Tab 1 View'), findsOneWidget);
        expect(find.text('Tab 2 View'), findsNothing);
        expect(bloc.value.surfaceId, equals('surf-tab-1'));

        await bloc.close();
      },
    );

    group(
        '(Issue #292) Reactive activeSurfaceId Viewport & Split-Pane Isolation',
        () {
      testWidgets(
        '(Issue #292) A2uiSurfaceView (surfaceId == null) reactively observes '
        'bloc.activeSurfaceId, switches without version bumps, and rebinds on '
        'widget.bloc swap',
        (tester) async {
          final bloc1 = A2uiSurfaceBloc()
            ..add(
              ProcessMessages([
                CreateSurfaceMessage(
                  surfaceId: 'surf-a',
                  catalogId: minimalCatalogId,
                ),
                UpdateComponentsMessage(
                  surfaceId: 'surf-a',
                  components: const [
                    {
                      'id': 'txt-a',
                      'component': 'Text',
                      'text': 'Surface A View',
                    },
                  ],
                ),
                CreateSurfaceMessage(
                  surfaceId: 'surf-b',
                  catalogId: minimalCatalogId,
                ),
                UpdateComponentsMessage(
                  surfaceId: 'surf-b',
                  components: const [
                    {
                      'id': 'txt-b',
                      'component': 'Text',
                      'text': 'Surface B View',
                    },
                  ],
                ),
              ]),
            );
          addTearDown(bloc1.close);

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: A2uiSurfaceView(
                  bloc: bloc1,
                ),
              ),
            ),
          );
          await tester.pump();

          expect(find.text('Surface B View'), findsOneWidget);
          expect(find.text('Surface A View'), findsNothing);

          final verA = bloc1.getSurfaceReady('surf-a')!.version;
          final verB = bloc1.getSurfaceReady('surf-b')!.version;

          // Switch B -> A -> B -> A via SelectSurface (no version bump)
          bloc1.add(const SelectSurface(surfaceId: 'surf-a'));
          await tester.pump();
          expect(find.text('Surface A View'), findsOneWidget);
          expect(find.text('Surface B View'), findsNothing);
          expect(bloc1.getSurfaceReady('surf-a')!.version, equals(verA));

          bloc1.add(const SelectSurface(surfaceId: 'surf-b'));
          await tester.pump();
          expect(find.text('Surface B View'), findsOneWidget);
          expect(find.text('Surface A View'), findsNothing);
          expect(bloc1.getSurfaceReady('surf-b')!.version, equals(verB));

          // Swap widget.bloc to bloc2 in didUpdateWidget
          final bloc2 = A2uiSurfaceBloc()
            ..add(
              ProcessMessages([
                CreateSurfaceMessage(
                  surfaceId: 'surf-c',
                  catalogId: minimalCatalogId,
                ),
                UpdateComponentsMessage(
                  surfaceId: 'surf-c',
                  components: const [
                    {
                      'id': 'txt-c',
                      'component': 'Text',
                      'text': 'Surface C on Bloc 2',
                    },
                  ],
                ),
                CreateSurfaceMessage(
                  surfaceId: 'surf-d',
                  catalogId: minimalCatalogId,
                ),
                UpdateComponentsMessage(
                  surfaceId: 'surf-d',
                  components: const [
                    {
                      'id': 'txt-d',
                      'component': 'Text',
                      'text': 'Surface D on Bloc 2',
                    },
                  ],
                ),
              ]),
            );
          addTearDown(bloc2.close);

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: A2uiSurfaceView(
                  bloc: bloc2,
                ),
              ),
            ),
          );
          await tester.pump();

          expect(find.text('Surface D on Bloc 2'), findsOneWidget);

          // Select surf-c on bloc2 and verify reactive update on new bloc
          bloc2.add(const SelectSurface(surfaceId: 'surf-c'));
          await tester.pump();
          expect(find.text('Surface C on Bloc 2'), findsOneWidget);
          expect(find.text('Surface D on Bloc 2'), findsNothing);
        },
      );

      testWidgets(
        '(Issue #292) split-pane A2uiSurfaceView(surfaceId: A) does not '
        'reconcile binders or increment version when Surface B mutates or '
        'when SelectSurface switches active focus',
        (tester) async {
          var buildCountA = 0;
          final trackingCatalog = A2uiFlutterCatalog.standard()
            ..register('Text', (context, componentContext) {
              if (componentContext.surfaceId == 'A') {
                buildCountA++;
              }
              final text = componentContext.props['text']?.toString() ?? '';
              return Text(text);
            });

          final bloc = A2uiSurfaceBloc()
            ..add(
              ProcessMessages([
                CreateSurfaceMessage(
                  surfaceId: 'A',
                  catalogId: minimalCatalogId,
                ),
                UpdateComponentsMessage(
                  surfaceId: 'A',
                  components: const [
                    {
                      'id': 'txt-a',
                      'component': 'Text',
                      'text': 'Pane A Content',
                    },
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
                      'id': 'txt-b',
                      'component': 'Text',
                      'text': 'Pane B Initial',
                    },
                  ],
                ),
              ]),
            );
          addTearDown(bloc.close);

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Row(
                  children: [
                    Expanded(
                      child: A2uiSurfaceView(
                        bloc: bloc,
                        surfaceId: 'A',
                        catalog: trackingCatalog,
                      ),
                    ),
                    Expanded(
                      child: A2uiSurfaceView(
                        bloc: bloc,
                        surfaceId: 'B',
                        catalog: trackingCatalog,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
          await tester.pump();

          expect(find.text('Pane A Content'), findsOneWidget);
          expect(find.text('Pane B Initial'), findsOneWidget);
          final versionABefore = bloc.getSurfaceReady('A')!.version;
          expect(buildCountA, equals(1));

          // Mutate Surface B in the background
          bloc.add(
            ProcessMessage(
              UpdateComponentsMessage(
                surfaceId: 'B',
                components: const [
                  {
                    'id': 'txt-b',
                    'component': 'Text',
                    'text': 'Pane B Updated',
                  },
                ],
              ),
            ),
          );
          await tester.pump();

          expect(find.text('Pane B Updated'), findsOneWidget);
          // Surface A's version must NOT have incremented!
          expect(bloc.getSurfaceReady('A')!.version, equals(versionABefore));
        },
      );

      testWidgets(
        '(Issue #292) A2uiComponentContext.closeSurface dispatches '
        'CloseSurface for current or target surfaceId',
        (tester) async {
          final bloc = A2uiSurfaceBloc()
            ..add(
              ProcessMessages([
                CreateSurfaceMessage(
                  surfaceId: 'surf-1',
                  catalogId: minimalCatalogId,
                ),
                UpdateComponentsMessage(
                  surfaceId: 'surf-1',
                  components: const [
                    {'id': 'txt-1', 'component': 'Text', 'text': 'One'},
                  ],
                ),
                CreateSurfaceMessage(
                  surfaceId: 'surf-2',
                  catalogId: minimalCatalogId,
                ),
                UpdateComponentsMessage(
                  surfaceId: 'surf-2',
                  components: const [
                    {'id': 'txt-2', 'component': 'Text', 'text': 'Two'},
                  ],
                ),
              ]),
            );
          addTearDown(bloc.close);

          final component = ComponentModel('btn-close', 'Button', const {});
          final ctx = A2uiComponentContext(
            component: component,
            props: const {},
            surfaceBloc: bloc,
            buildChildCallback: (id) => const SizedBox(),
            buildChildrenCallback: (ids) => const [],
            surfaceId: 'surf-2',
          )
            // Close explicit target surface 'surf-1'
            ..closeSurface('surf-1');
          expect(bloc.availableSurfaceIds, equals(['surf-2']));

          // Close current context surface ('surf-2') when omitted
          ctx.closeSurface();
          expect(bloc.availableSurfaceIds, isEmpty);
          expect(bloc.value, isA<SurfaceInitial>());
        },
      );

      testWidgets(
        '(Issue #292) covers fallback switch in A2uiSurfaceView, '
        'collectId Map branch, and safe_prop_parser asInt',
        (tester) async {
          expect(asInt(42.7), equals(42));
          expect(asInt('128'), equals(128));
          expect(asInt('invalid', 7), equals(7));
          expect(asInt(null, 9), equals(9));

          final bloc = A2uiSurfaceBloc();
          addTearDown(bloc.close);
          final catalog = A2uiFlutterCatalog.standard();

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: A2uiSurfaceView(
                  bloc: bloc,
                  catalog: catalog,
                ),
              ),
            ),
          );

          // 1. Trigger fallback switch for SurfaceSubmitting with mismatched
          // surfaceId when activeSurfaceId is non-null
          bloc
            ..emitForTest(
              const SurfaceSubmitting(
                surfaceId: 'surf-sub',
                actionName: 'act',
                sourceComponentId: 'btn-1',
              ),
            )
            ..emitForTest(
              const SurfaceStreaming(
                surfaceId: 'surf-other-nonexistent',
                messageCount: 1,
              ),
            );
          await tester.pump();

          // 2. Also test Map child with 'id' in _SurfaceTreeRenderer.collectId
          bloc.add(
            ProcessMessages([
              CreateSurfaceMessage(
                surfaceId: 'surf-map-child',
                catalogId: minimalCatalogId,
              ),
            ]),
          );
          final surface =
              bloc.processor.groupModel.getSurface('surf-map-child')!;
          surface.componentsModel
            ..addComponent(
              ComponentModel('card-1', 'Card', const {
                'child': {'id': 'txt-inside'},
              }),
            )
            ..addComponent(
              ComponentModel(
                'txt-inside',
                'Text',
                const {'text': 'Inside Card'},
              ),
            );
          bloc.emitForTest(bloc.getSurfaceReady('surf-map-child')!);
          await tester.pump();
          expect(find.text('Inside Card'), findsOneWidget);

          // 3. Fallback switch for SurfaceReady, SurfaceSubmitting, and
          // SurfaceError when targetId does not match state.surfaceId
          final readySnap = bloc.getSurfaceReady('surf-map-child')!;
          bloc.processor.groupModel.deleteSurface('surf-map-child');
          bloc
            ..emitForTest(readySnap)
            ..emitForTest(
              const SurfaceSubmitting(
                surfaceId: 'surf-sub-ephemeral',
                actionName: 'submit',
                sourceComponentId: 'btn-1',
              ),
            )
            ..emitForTest(const SurfaceInitial())
            ..emitForTest(
              const SurfaceError(error: 'err'),
            );
          await tester.pump();
        },
      );

      testWidgets(
        '(Issue #292) renders streaming skeleton when active or targeted '
        'surface is created with empty component tree',
        (tester) async {
          final bloc = A2uiSurfaceBloc()
            ..add(
              ProcessMessage(
                CreateSurfaceMessage(
                  surfaceId: 'surf-1',
                  catalogId: minimalCatalogId,
                ),
              ),
            );
          addTearDown(bloc.close);

          expect(bloc.value, isA<SurfaceStreaming>());
          expect(bloc.activeSurfaceId.value, equals('surf-1'));

          // 1. Default view (surfaceId == null) must render streaming skeleton
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: A2uiSurfaceView(
                  bloc: bloc,
                  streamingBuilder: (context, streaming) =>
                      Text('Streaming active: ${streaming.surfaceId}'),
                ),
              ),
            ),
          );
          await tester.pump();
          expect(find.text('Streaming active: surf-1'), findsOneWidget);

          // 2. Targeted view (surfaceId: 'surf-1') must also render streaming
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: A2uiSurfaceView(
                  bloc: bloc,
                  surfaceId: 'surf-1',
                  streamingBuilder: (context, streaming) =>
                      Text('Streaming targeted: ${streaming.surfaceId}'),
                ),
              ),
            ),
          );
          await tester.pump();
          expect(find.text('Streaming targeted: surf-1'), findsOneWidget);

          // 3. When 'surf-1' gets components (becomes SurfaceReady) and a
          // secondary 'surf-2' is created with 0 components and then user
          // switches back to 'surf-1' (so bloc.value is SurfaceReady),
          // a split-pane A2uiSurfaceView(surfaceId: 'surf-2') targeting the
          // empty 'surf-2' must render streaming rather than a blank tree!
          bloc
            ..add(
              ProcessMessage(
                UpdateComponentsMessage(
                  surfaceId: 'surf-1',
                  components: const [
                    {'id': 'txt-1', 'component': 'Text', 'text': 'One Ready'},
                  ],
                ),
              ),
            )
            ..add(
              ProcessMessage(
                CreateSurfaceMessage(
                  surfaceId: 'surf-2',
                  catalogId: minimalCatalogId,
                ),
              ),
            )
            ..add(const SelectSurface(surfaceId: 'surf-1'));
          expect(bloc.value, isA<SurfaceReady>());
          expect(bloc.activeSurfaceId.value, equals('surf-1'));

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: A2uiSurfaceView(
                  bloc: bloc,
                  surfaceId: 'surf-2',
                  streamingBuilder: (context, streaming) =>
                      Text('Streaming secondary: ${streaming.surfaceId}'),
                ),
              ),
            ),
          );
          await tester.pump();
          expect(find.text('Streaming secondary: surf-2'), findsOneWidget);

          // 4. When activeSurfaceId is 'surf-1' (populated) and a new stream
          // starts emitting SurfaceStreaming(surfaceId: null), default
          // A2uiSurfaceView (widget.surfaceId == null) must render streaming
          // skeleton instead of falling through to getSurfaceReady('surf-1')!
          bloc.emitForTest(const SurfaceStreaming());
          expect(bloc.activeSurfaceId.value, equals('surf-1'));

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: A2uiSurfaceView(
                  bloc: bloc,
                  streamingBuilder: (context, streaming) =>
                      Text('Streaming new turn: ${streaming.messageCount}'),
                ),
              ),
            ),
          );
          await tester.pump();
          expect(find.text('Streaming new turn: 0'), findsOneWidget);
        },
      );
    });

    group('(Issue #321: R7) Per-Component Binder Signal Subscriptions', () {
      testWidgets(
        '(Issue #321: R7) direct dataModel mutation rebuilds only the bound '
        'component via binder.resolvedProps without rebuilding sibling '
        'components, and reconciles cleanly on component update or removal',
        (tester) async {
          final buildCounts = <String, int>{};
          final trackingCatalog = A2uiFlutterCatalog.standard()
            ..register('Text', (context, componentContext) {
              final id = componentContext.component.id;
              buildCounts[id] = (buildCounts[id] ?? 0) + 1;
              final text = componentContext.props['text']?.toString() ?? '';
              return Text(text);
            });

          final bloc = A2uiSurfaceBloc()
            ..add(
              ProcessMessages([
                CreateSurfaceMessage(
                  surfaceId: 'surf-granular',
                  catalogId: minimalCatalogId,
                ),
                UpdateDataModelMessage(
                  surfaceId: 'surf-granular',
                  path: '/greeting',
                  value: 'Hello World',
                ),
                UpdateDataModelMessage(
                  surfaceId: 'surf-granular',
                  path: '/other',
                  value: 'Static Sibling',
                ),
                UpdateComponentsMessage(
                  surfaceId: 'surf-granular',
                  components: const [
                    {
                      'id': 'col-root',
                      'component': 'Column',
                      'children': ['comp-a', 'comp-b'],
                    },
                    {
                      'id': 'comp-a',
                      'component': 'Text',
                      'text': {'path': '/greeting'},
                    },
                    {
                      'id': 'comp-b',
                      'component': 'Text',
                      'text': {'path': '/other'},
                    },
                  ],
                ),
              ]),
            );
          addTearDown(bloc.close);

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: A2uiSurfaceView(
                  bloc: bloc,
                  catalog: trackingCatalog,
                ),
              ),
            ),
          );
          await tester.pump();

          expect(find.text('Hello World'), findsOneWidget);
          expect(find.text('Static Sibling'), findsOneWidget);
          expect(buildCounts['comp-a'], equals(1));
          expect(buildCounts['comp-b'], equals(1));

          final versionBefore = (bloc.value as SurfaceReady).version;
          final surface =
              bloc.processor.groupModel.getSurface('surf-granular')!;

          // Mutate surface.dataModel directly without dispatching a bloc event
          // or bumping SurfaceReady.version
          surface.dataModel.set('/greeting', 'Updated Directly');
          await tester.pump();

          expect((bloc.value as SurfaceReady).version, equals(versionBefore));
          expect(find.text('Updated Directly'), findsOneWidget);
          expect(find.text('Static Sibling'), findsOneWidget);
          expect(buildCounts['comp-a'], equals(2));
          expect(buildCounts['comp-b'], equals(1));

          // Remove comp-b from the surface and update comp-a's binding path
          surface.componentsModel.removeComponent('comp-b');
          bloc.add(
            ProcessMessage(
              UpdateComponentsMessage(
                surfaceId: 'surf-granular',
                components: const [
                  {
                    'id': 'col-root',
                    'component': 'Column',
                    'children': ['comp-a'],
                  },
                  {
                    'id': 'comp-a',
                    'component': 'Text',
                    'text': {'path': '/other'},
                  },
                ],
              ),
            ),
          );
          await tester.pump();

          expect(find.text('Static Sibling'), findsOneWidget);
          expect(find.text('Updated Directly'), findsNothing);

          // Direct mutation to '/other' updates comp-a; comp-b is unmounted and does not rebuild
          final countB = buildCounts['comp-b']!;
          surface.dataModel.set('/other', 'Rebound Value');
          await tester.pump();

          expect(find.text('Rebound Value'), findsOneWidget);
          expect(buildCounts['comp-b'], equals(countB));
        },
      );
    });
  });
}

extension on A2uiSurfaceBloc {
  void emitForTest(A2uiSurfaceState state) {
    emit(state);
  }
}
