import 'package:a2ui_core/a2ui_core.dart';
import 'package:bloc_signals_genui/bloc_signals_genui.dart';
import 'package:bloc_signals_genui_flutter/bloc_signals_genui_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
        )
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateComponents': {
              'surfaceId': 'surf-missing-child',
              'components': [
                {
                  'id': 'row-missing',
                  'component': 'Row',
                  'children': ['ghost-child'],
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
        final bloc = A2uiSurfaceBloc()
          ..add(
            const ProcessJsonMessage({
              'version': 'v0.9',
              'createSurface': {
                'surfaceId': 'surf-map-children',
                'catalogId': minimalCatalogId,
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
        final bloc = A2uiSurfaceBloc()
          ..add(
            const ProcessJsonMessage({
              'version': 'v0.9',
              'createSurface': {
                'surfaceId': 'surf-dynamic-child',
                'catalogId': minimalCatalogId,
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
          )
          ..add(
            const ProcessJsonMessage({
              'version': 'v0.9',
              'updateComponents': {
                'surfaceId': 'surf-circular',
                'components': [
                  {
                    'id': 'col-a',
                    'component': 'Column',
                    'children': ['col-b'],
                  },
                  {
                    'id': 'col-b',
                    'component': 'Column',
                    'children': ['col-a'],
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

        // Must render circular reference guard placeholder instead of throwing
        // StackOverflowError
        expect(
          find.byKey(const ValueKey('circular_ref_col-a')),
          findsOneWidget,
        );

        await bloc.close();
      },
    );
  });
}

extension on A2uiSurfaceBloc {
  void emitForTest(A2uiSurfaceState state) {
    emit(state);
  }
}
