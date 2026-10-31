import 'package:bloc_signals_genui/bloc_signals_genui.dart';
import 'package:bloc_signals_genui_jaspr/bloc_signals_genui_jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_test/jaspr_test.dart';

void main() {
  const minimalCatalogId =
      'https://a2ui.org/specification/v0_9/catalogs/minimal/minimal_catalog.json';

  group('A2uiSurfaceView lifecycle states', () {
    testComponents('renders custom placeholder on SurfaceInitial',
        (tester) async {
      final bloc = A2uiSurfaceBloc();
      tester.pumpComponent(
        A2uiSurfaceView(
          bloc: bloc,
          placeholderBuilder: (context) => const div([
            Component.text('Initial Placeholder'),
          ]),
        ),
      );

      expect(find.text('Initial Placeholder'), findsOneComponent);
      await bloc.close();
    });

    testComponents('renders default placeholder when none provided',
        (tester) async {
      final bloc = A2uiSurfaceBloc();
      tester.pumpComponent(
        A2uiSurfaceView(bloc: bloc),
      );

      expect(find.text('Initial Placeholder'), findsNothing);
      await bloc.close();
    });

    testComponents('renders custom streaming indicator on SurfaceStreaming',
        (tester) async {
      final bloc = A2uiSurfaceBloc();
      tester.pumpComponent(
        A2uiSurfaceView(
          bloc: bloc,
          streamingBuilder: (context, streaming) => div([
            Component.text('Streaming: ${streaming.messageCount}'),
          ]),
        ),
      );

      bloc.emitForTest(const SurfaceStreaming(messageCount: 5));
      await pumpEventQueue();

      expect(find.text('Streaming: 5'), findsOneComponent);
      await bloc.close();
    });

    testComponents('renders default streaming indicator on SurfaceStreaming',
        (tester) async {
      final bloc = A2uiSurfaceBloc();
      tester.pumpComponent(
        A2uiSurfaceView(bloc: bloc),
      );

      bloc.emitForTest(const SurfaceStreaming(messageCount: 3));
      await pumpEventQueue();

      expect(
        find.text('Generating UI (3 chunks)...'),
        findsOneComponent,
      );
      await bloc.close();
    });

    testComponents('renders custom submitting view on SurfaceSubmitting',
        (tester) async {
      final bloc = A2uiSurfaceBloc();
      tester.pumpComponent(
        A2uiSurfaceView(
          bloc: bloc,
          submittingBuilder: (context, submitting) => div([
            Component.text('Custom Submitting: ${submitting.actionName}'),
          ]),
        ),
      );

      bloc.emitForTest(
        const SurfaceSubmitting(
          surfaceId: 's1',
          actionName: 'checkout',
          sourceComponentId: 'btn_1',
        ),
      );
      await pumpEventQueue();

      expect(
        find.text('Custom Submitting: checkout'),
        findsOneComponent,
      );
      await bloc.close();
    });

    testComponents('renders default submitting view on SurfaceSubmitting',
        (tester) async {
      final bloc = A2uiSurfaceBloc();
      tester.pumpComponent(
        A2uiSurfaceView(bloc: bloc),
      );

      bloc.emitForTest(
        const SurfaceSubmitting(
          surfaceId: 's1',
          actionName: 'checkout',
          sourceComponentId: 'btn_1',
        ),
      );
      await pumpEventQueue();

      expect(
        find.text('Submitting checkout...'),
        findsOneComponent,
      );
      await bloc.close();
    });

    testComponents('renders custom error view on SurfaceError', (tester) async {
      final bloc = A2uiSurfaceBloc();
      tester.pumpComponent(
        A2uiSurfaceView(
          bloc: bloc,
          errorBuilder: (context, error) => div([
            Component.text('Custom Error: ${error.error}'),
          ]),
        ),
      );

      bloc.emitForTest(
        const SurfaceError(
          surfaceId: 's1',
          error: 'Network failure',
        ),
      );
      await pumpEventQueue();

      expect(
        find.text('Custom Error: Network failure'),
        findsOneComponent,
      );
      await bloc.close();
    });

    testComponents('renders default error view on SurfaceError',
        (tester) async {
      final bloc = A2uiSurfaceBloc();
      tester.pumpComponent(
        A2uiSurfaceView(bloc: bloc),
      );

      bloc.emitForTest(
        const SurfaceError(
          surfaceId: 's1',
          error: 'Parsing failed',
        ),
      );
      await pumpEventQueue();

      expect(find.text('Generative UI Error'), findsOneComponent);
      expect(find.text('Parsing failed'), findsOneComponent);
      await bloc.close();
    });

    testComponents('uses custom validationErrorsBuilder when provided',
        (tester) async {
      final bloc = A2uiSurfaceBloc(catalogs: [MinimalCatalog()])
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 'surf_1',
              'catalogId': minimalCatalogId,
            },
          }),
        )
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateComponents': {
              'surfaceId': 'surf_1',
              'components': [
                {
                  'id': 'txt_1',
                  'component': 'Text',
                  'text': 'Surface Content',
                },
              ],
            },
          }),
        );

      tester.pumpComponent(
        A2uiSurfaceView(
          bloc: bloc,
          validationErrorsBuilder: (context, errors) => div([
            Component.text('Custom Error: ${errors.join(', ')}'),
          ]),
        ),
      );

      final currentReady = bloc.state.value as SurfaceReady;
      bloc.emitForTest(
        SurfaceReady(
          surfaceId: 'surf_1',
          surface: currentReady.surface,
          isValid: false,
          validationErrors: const ['Custom validation error'],
        ),
      );
      await pumpEventQueue();

      expect(
        find.text('Custom Error: Custom validation error'),
        findsOneComponent,
      );
      await bloc.close();
    });

    testComponents('handles empty surface components cleanly', (tester) async {
      final bloc = A2uiSurfaceBloc(catalogs: [MinimalCatalog()])
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 'empty_surf',
              'catalogId': minimalCatalogId,
            },
          }),
        );
      await pumpEventQueue();

      tester.pumpComponent(
        A2uiSurfaceView(bloc: bloc),
      );
      await pumpEventQueue();

      expect(bloc.state.value, isA<A2uiSurfaceState>());
      await bloc.close();
    });

    testComponents(
        'localized error boundary isolates throwing component builders ([SCAR-A2UI-03] / [SCAR-ERR-02])',
        (tester) async {
      final throwingCatalog = A2uiJasprCatalog.standard()
        ..register('ThrowingComponent', (context, compCtx) {
          throw const FormatException('Simulated LLM malformed payload');
        });

      final bloc = A2uiSurfaceBloc(catalogs: [MinimalCatalog()])
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 'fault_surf',
              'catalogId': minimalCatalogId,
            },
          }),
        )
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateComponents': {
              'surfaceId': 'fault_surf',
              'components': [
                {
                  'id': 'root_col',
                  'component': 'Column',
                  'children': ['good_txt', 'bad_comp'],
                },
                {
                  'id': 'good_txt',
                  'component': 'Text',
                  'text': 'Safe sibling content',
                },
                {
                  'id': 'bad_comp',
                  'component': 'ThrowingComponent',
                },
              ],
            },
          }),
        );

      tester.pumpComponent(
        A2uiSurfaceView(
          bloc: bloc,
          catalog: throwingCatalog,
        ),
      );

      expect(find.text('Safe sibling content'), findsOneComponent);
      expect(
        find.text('Failed to render component "bad_comp"'),
        findsOneComponent,
      );
      await bloc.close();
    });

    testComponents('dynamic data update triggers re-render of bound values',
        (tester) async {
      final bloc = A2uiSurfaceBloc(catalogs: [MinimalCatalog()])
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 'data_surf',
              'catalogId': minimalCatalogId,
            },
          }),
        )
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateDataModel': {
              'surfaceId': 'data_surf',
              'path': '/title',
              'value': 'Original Header',
            },
          }),
        )
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateComponents': {
              'surfaceId': 'data_surf',
              'components': [
                {
                  'id': 'dyn_txt',
                  'component': 'Text',
                  'text': {'path': '/title'},
                },
              ],
            },
          }),
        );
      await pumpEventQueue();

      tester.pumpComponent(
        A2uiSurfaceView(
          bloc: bloc,
        ),
      );
      await pumpEventQueue();
      await tester.pump();

      expect(find.text('Original Header'), findsOneComponent);

      // Update data model dynamically
      bloc.add(
        const ProcessJsonMessage({
          'version': 'v0.9',
          'updateDataModel': {
            'surfaceId': 'data_surf',
            'path': '/title',
            'value': 'Updated Header',
          },
        }),
      );
      await pumpEventQueue();
      await tester.pump();

      expect(find.text('Updated Header'), findsOneComponent);
      await bloc.close();
    });

    testComponents(
        'didUpdateComponent updates subscription when bloc or '
        'surfaceId changes', (tester) async {
      final bloc1 = A2uiSurfaceBloc(catalogs: [MinimalCatalog()])
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 's1',
              'catalogId': minimalCatalogId,
            },
          }),
        )
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateComponents': {
              'surfaceId': 's1',
              'components': [
                {
                  'id': 't1',
                  'component': 'Text',
                  'text': 'Bloc 1 Text',
                },
              ],
            },
          }),
        );

      final bloc2 = A2uiSurfaceBloc(catalogs: [MinimalCatalog()])
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 's2',
              'catalogId': minimalCatalogId,
            },
          }),
        )
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateComponents': {
              'surfaceId': 's2',
              'components': [
                {
                  'id': 't2',
                  'component': 'Text',
                  'text': 'Bloc 2 Text',
                },
              ],
            },
          }),
        );

      tester.pumpComponent(
        A2uiSurfaceView(bloc: bloc1),
      );

      expect(find.text('Bloc 1 Text'), findsOneComponent);

      // Update with bloc2
      tester.pumpComponent(
        A2uiSurfaceView(bloc: bloc2),
      );

      expect(find.text('Bloc 2 Text'), findsOneComponent);

      await bloc1.close();
      await bloc2.close();
    });

    testComponents('wrapper updates subscription and disposes cleanly',
        (tester) async {
      final bloc1 = A2uiSurfaceBloc();
      final bloc2 = A2uiSurfaceBloc();
      final controller = _TestController();

      tester.pumpComponent(
        _TestWrapper(controller: controller, bloc: bloc1),
      );

      controller.update?.call(newBloc: bloc2, newSurfaceId: 'targeted_surf');
      await tester.pump();

      controller.update?.call(newBloc: bloc2, newSurfaceId: 'targeted_surf_2');
      await tester.pump();

      controller.hide?.call();
      await tester.pump();

      await bloc1.close();
      await bloc2.close();
    });

    testComponents('renders with NodeResolver when root component is present',
        (tester) async {
      final bloc = A2uiSurfaceBloc(catalogs: [MinimalCatalog()])
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 'surf_root',
              'catalogId': minimalCatalogId,
            },
          }),
        )
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateComponents': {
              'surfaceId': 'surf_root',
              'components': [
                {
                  'id': 'root',
                  'component': 'Column',
                  'children': ['c_text', 'c_child_node'],
                },
                {
                  'id': 'c_text',
                  'component': 'Text',
                  'text': 'Root Node Text',
                },
                {
                  'id': 'c_child_node',
                  'component': 'Text',
                  'text': 'Child Node Text',
                },
              ],
            },
          }),
        );
      await pumpEventQueue();

      tester.pumpComponent(A2uiSurfaceView(bloc: bloc));
      await pumpEventQueue();
      await tester.pump();

      expect(find.text('Root Node Text'), findsOneComponent);
      expect(find.text('Child Node Text'), findsOneComponent);
      await bloc.close();
    });

    testComponents('handles NodeResolver cyclic, pending, and unknown states',
        (tester) async {
      // 1. Pending child state and dynamic arrival triggering rootNode
      // subscription
      final blocPending = A2uiSurfaceBloc(catalogs: [MinimalCatalog()])
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 'surf_pending',
              'catalogId': minimalCatalogId,
            },
          }),
        )
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateComponents': {
              'surfaceId': 'surf_pending',
              'components': [
                {
                  'id': 'root',
                  'component': 'Column',
                  'children': ['late_child'],
                },
              ],
            },
          }),
        );
      await pumpEventQueue();

      tester.pumpComponent(A2uiSurfaceView(bloc: blocPending));
      await pumpEventQueue();
      await tester.pump();

      expect(
        find.byKey(const ValueKey('missing_late_child')),
        findsOneComponent,
      );

      // Now stream the missing component to trigger rootNode subscription
      // update
      blocPending.add(
        const ProcessJsonMessage({
          'version': 'v0.9',
          'updateComponents': {
            'surfaceId': 'surf_pending',
            'components': [
              {
                'id': 'late_child',
                'component': 'Text',
                'text': 'Late Child Arrived',
              },
            ],
          },
        }),
      );
      await pumpEventQueue();
      await tester.pump();

      expect(
        find.byKey(const ValueKey('missing_late_child')),
        findsNothing,
      );
      expect(find.text('Late Child Arrived'), findsOneComponent);
      await blocPending.close();

      // 2. Cyclic reference breaking recursion
      final blocCyclic = A2uiSurfaceBloc(catalogs: [MinimalCatalog()])
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 'surf_cyclic',
              'catalogId': minimalCatalogId,
            },
          }),
        )
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateComponents': {
              'surfaceId': 'surf_cyclic',
              'components': [
                {
                  'id': 'root',
                  'component': 'Column',
                  'children': ['child_a'],
                },
                {
                  'id': 'child_a',
                  'component': 'Column',
                  'children': ['root'],
                },
              ],
            },
          }),
        );
      await pumpEventQueue();

      tester.pumpComponent(A2uiSurfaceView(bloc: blocCyclic));
      await pumpEventQueue();
      await tester.pump();

      expect(
        find.byKey(const ValueKey('circular_ref_root')),
        findsOneComponent,
      );
      await blocCyclic.close();

      // 3. Unknown component type error fallback
      final blocUnknown = A2uiSurfaceBloc(catalogs: [MinimalCatalog()])
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 'surf_unknown',
              'catalogId': minimalCatalogId,
            },
          }),
        )
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateComponents': {
              'surfaceId': 'surf_unknown',
              'components': [
                {
                  'id': 'root',
                  'component': 'Column',
                  'children': ['mystery_box'],
                },
                {
                  'id': 'mystery_box',
                  'component': 'HologramProjector',
                },
              ],
            },
          }),
        );
      await pumpEventQueue();

      tester.pumpComponent(A2uiSurfaceView(bloc: blocUnknown));
      await pumpEventQueue();
      await tester.pump();

      expect(
        find.byKey(const ValueKey('a2ui_error_mystery_box')),
        findsOneComponent,
      );
      expect(
        find.text('Failed to render component "mystery_box"'),
        findsOneComponent,
      );
      await blocUnknown.close();
    });

    testComponents(
        'reconciles binders and disposes previous resolver on '
        'surface instance swap', (tester) async {
      final bloc = A2uiSurfaceBloc(catalogs: [MinimalCatalog()]);
      final surface1 = SurfaceModel<ComponentApi>(
        's1',
        defaultCatalog: MinimalCatalog(),
      )..componentsModel.addComponent(
          ComponentModel('txt_1', 'Text', const {'text': 'Version 1'}),
        );
      final surface2 = SurfaceModel<ComponentApi>(
        's1',
        defaultCatalog: MinimalCatalog(),
      )..componentsModel.addComponent(
          ComponentModel('txt_1', 'Text', const {'text': 'Version 2'}),
        );

      bloc.emitForTest(
        SurfaceReady(
          surfaceId: 's1',
          surface: surface1,
          version: 1,
        ),
      );
      tester.pumpComponent(A2uiSurfaceView(bloc: bloc));
      await tester.pump();
      expect(find.text('Version 1'), findsOneComponent);

      bloc.emitForTest(
        SurfaceReady(
          surfaceId: 's1',
          surface: surface2,
          version: 2,
        ),
      );
      await tester.pump();
      expect(find.text('Version 2'), findsOneComponent);

      // And component model change in same surface instance
      surface2.componentsModel.removeComponent('txt_1');
      surface2.componentsModel.addComponent(
        ComponentModel('txt_1', 'Text', const {'text': 'Version 2 Updated'}),
      );
      bloc.emitForTest(
        SurfaceReady(
          surfaceId: 's1',
          surface: surface2,
          version: 3,
        ),
      );
      await tester.pump();
      expect(find.text('Version 2 Updated'), findsOneComponent);

      // Prune component
      surface2.componentsModel.removeComponent('txt_1');
      bloc.emitForTest(
        SurfaceReady(
          surfaceId: 's1',
          surface: surface2,
          version: 4,
        ),
      );
      await tester.pump();
      expect(find.text('Version 2 Updated'), findsNothing);

      await bloc.close();
    });

    testComponents('evaluates template child nodes and scoped binders',
        (tester) async {
      final bloc = A2uiSurfaceBloc(catalogs: [MinimalCatalog()])
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 's_tmpl',
              'catalogId': minimalCatalogId,
            },
          }),
        );
      await pumpEventQueue();

      final surface = bloc.processor.model.getSurface('s_tmpl')!;
      surface.dataModel.set('/items', [
        {'title': 'Item 1'},
        {'title': 'Item 2'},
      ]);
      surface.componentsModel.addComponent(
        ComponentModel('col_list', 'Column', {
          'children': {
            'componentId': 'item_tmpl',
            'path': '/items',
          },
        }),
      );
      surface.componentsModel.addComponent(
        ComponentModel('item_tmpl', 'Text', {
          'text': {'path': 'title'},
        }),
      );

      bloc.emitForTest(
        SurfaceReady(
          surfaceId: 's_tmpl',
          surface: surface,
        ),
      );

      tester.pumpComponent(A2uiSurfaceView(bloc: bloc, surfaceId: 's_tmpl'));
      await tester.pump();

      expect(find.text('Item 1'), findsOneComponent);
      expect(find.text('Item 2'), findsOneComponent);
      await bloc.close();
    });

    testComponents(
        'collectId handles tabs, trigger, entryPointChild, content, '
        'and Map children', (tester) async {
      final bloc = A2uiSurfaceBloc(catalogs: [MinimalCatalog()]);
      final surface = SurfaceModel<ComponentApi>(
        's_props',
        defaultCatalog: MinimalCatalog(),
      );
      surface.componentsModel.addComponent(
        ComponentModel('host_comp', 'Card', {
          'child': {'id': 'c_child'},
          'trigger': {'id': 'c_trigger'},
          'entryPointChild': 'c_entry',
          'content': 'c_content',
          'contentChild': 'c_content_child',
          'tabs': [
            {'child': 'c_tab_1'},
          ],
        }),
      );
      surface.componentsModel.addComponent(
        ComponentModel('c_child', 'Text', const {'text': 'Child'}),
      );
      surface.componentsModel.addComponent(
        ComponentModel('c_trigger', 'Text', const {'text': 'Trigger'}),
      );
      surface.componentsModel.addComponent(
        ComponentModel('c_entry', 'Text', const {'text': 'Entry'}),
      );
      surface.componentsModel.addComponent(
        ComponentModel('c_content', 'Text', const {'text': 'Content'}),
      );
      surface.componentsModel.addComponent(
        ComponentModel(
          'c_content_child',
          'Text',
          const {'text': 'ContentChild'},
        ),
      );
      surface.componentsModel.addComponent(
        ComponentModel('c_tab_1', 'Text', const {'text': 'Tab 1'}),
      );

      bloc.emitForTest(SurfaceReady(surfaceId: 's_props', surface: surface));
      tester.pumpComponent(A2uiSurfaceView(bloc: bloc));
      await tester.pump();

      expect(find.text('Child'), findsOneComponent);
      await bloc.close();
    });

    testComponents('detects circular references in _buildComponent',
        (tester) async {
      final bloc = A2uiSurfaceBloc(catalogs: [MinimalCatalog()]);
      final surface = SurfaceModel<ComponentApi>(
        's_circ',
        defaultCatalog: MinimalCatalog(),
      );
      surface.componentsModel.addComponent(
        ComponentModel('node_a', 'Card', const {'child': 'node_b'}),
      );
      surface.componentsModel.addComponent(
        ComponentModel('node_b', 'Card', const {'child': 'node_a'}),
      );

      bloc.emitForTest(SurfaceReady(surfaceId: 's_circ', surface: surface));
      tester.pumpComponent(A2uiSurfaceView(bloc: bloc));
      await tester.pump();

      expect(
        find.byKey(const ValueKey('circular_ref_node_a')),
        findsOneComponent,
      );
      await bloc.close();
    });

    testComponents('renders missing placeholder for unresolvable child',
        (tester) async {
      final bloc = A2uiSurfaceBloc(catalogs: [MinimalCatalog()]);
      final surface = SurfaceModel<ComponentApi>(
        's_miss',
        defaultCatalog: MinimalCatalog(),
      );
      surface.componentsModel.addComponent(
        ComponentModel('parent', 'Card', const {'child': 'ghost_child'}),
      );

      bloc.emitForTest(SurfaceReady(surfaceId: 's_miss', surface: surface));
      tester.pumpComponent(A2uiSurfaceView(bloc: bloc));
      await tester.pump();

      expect(
        find.byKey(const ValueKey('missing_ghost_child')),
        findsOneComponent,
      );
      await bloc.close();
    });

    testComponents('handles fallback presentation states cleanly',
        (tester) async {
      final bloc = A2uiSurfaceBloc(catalogs: [MinimalCatalog()])
        // 1. SurfaceStreaming with null surfaceId
        ..emitForTest(const SurfaceStreaming(messageCount: 3));
      tester.pumpComponent(A2uiSurfaceView(bloc: bloc));
      await tester.pump();
      expect(find.text('Generating UI (3 chunks)...'), findsOneComponent);

      // 2. Targeted surface ready with empty components when active surface
      // is s_other
      bloc
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 's_empty',
              'catalogId': minimalCatalogId,
            },
          }),
        )
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 's_other',
              'catalogId': minimalCatalogId,
            },
          }),
        )
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateComponents': {
              'surfaceId': 's_other',
              'components': [
                {'id': 't_other', 'component': 'Text', 'text': 'Other Active'},
              ],
            },
          }),
        );
      await pumpEventQueue();

      tester.pumpComponent(
        A2uiSurfaceView(bloc: bloc, surfaceId: 's_empty'),
      );
      await tester.pump();
      expect(find.text('Generating UI (1 chunks)...'), findsOneComponent);

      // 3. Unknown target surfaceId
      tester.pumpComponent(
        A2uiSurfaceView(bloc: bloc, surfaceId: 'non_existent_surf'),
      );
      await tester.pump();

      // 4. SurfaceError with null surfaceId
      bloc.emitForTest(const SurfaceError(error: 'Global failure'));
      tester.pumpComponent(A2uiSurfaceView(bloc: bloc));
      await tester.pump();
      expect(find.text('Global failure'), findsOneComponent);

      // 5. Multiple root components
      final multiSurface = SurfaceModel<ComponentApi>(
        's_multi',
        defaultCatalog: MinimalCatalog(),
      );
      multiSurface.componentsModel.addComponent(
        ComponentModel('m1', 'Text', const {'text': 'Multi 1'}),
      );
      multiSurface.componentsModel.addComponent(
        ComponentModel('m2', 'Text', const {'text': 'Multi 2'}),
      );
      bloc.emitForTest(
        SurfaceReady(surfaceId: 's_multi', surface: multiSurface),
      );
      tester.pumpComponent(A2uiSurfaceView(bloc: bloc));
      await tester.pump();
      expect(find.text('Multi 1'), findsOneComponent);
      expect(find.text('Multi 2'), findsOneComponent);

      await bloc.close();
    });

    testComponents('handles null surfaceId streaming and fallback error states',
        (tester) async {
      final bloc = A2uiSurfaceBloc(catalogs: [MinimalCatalog()])
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 'surf_active',
              'catalogId': minimalCatalogId,
            },
          }),
        );
      await pumpEventQueue();

      // Line 163: activeSurfaceId is 'surf_active', component.surfaceId
      // is null, state.surfaceId is null
      bloc.emitForTest(
        const SurfaceStreaming(messageCount: 1),
      );
      tester.pumpComponent(A2uiSurfaceView(bloc: bloc));
      await tester.pump();
      expect(find.text('Generating UI (1 chunks)...'), findsOneComponent);

      // Line 200: activeSurfaceId is null, component.surfaceId is null,
      // state is SurfaceError
      final emptyBloc = A2uiSurfaceBloc()
        ..emitForTest(
          const SurfaceError(error: 'Fallback Global Error'),
        );
      tester.pumpComponent(A2uiSurfaceView(bloc: emptyBloc));
      await tester.pump();
      expect(find.text('Fallback Global Error'), findsOneComponent);
      await emptyBloc.close();
      await bloc.close();
    });

    testComponents(
        'dynamically updates rootNode when root component is '
        'modified on same surface', (tester) async {
      final bloc = A2uiSurfaceBloc(catalogs: [MinimalCatalog()]);
      final surface = SurfaceModel<ComponentApi>(
        's_dyn_root',
        defaultCatalog: MinimalCatalog(),
      )..componentsModel.addComponent(
          ComponentModel('root', 'Text', const {'text': 'Initial Root'}),
        );

      bloc.emitForTest(
        SurfaceReady(surfaceId: 's_dyn_root', surface: surface, version: 1),
      );
      tester.pumpComponent(
        A2uiSurfaceView(bloc: bloc, surfaceId: 's_dyn_root'),
      );
      await tester.pump();
      expect(find.text('Initial Root'), findsOneComponent);

      // Update root component in place and re-resolve to trigger
      // rootNode.subscribe
      surface.componentsModel.removeComponent('root');
      surface.componentsModel.addComponent(
        ComponentModel('root', 'Text', const {'text': 'Updated Root'}),
      );
      bloc.emitForTest(
        SurfaceReady(surfaceId: 's_dyn_root', surface: surface, version: 2),
      );
      await pumpEventQueue();
      await tester.pump();
      expect(find.text('Updated Root'), findsOneComponent);
      await bloc.close();
    });

    testComponents(
        '_ResolvedNodeComponent subscribes to props updates and disposes',
        (tester) async {
      final bloc = A2uiSurfaceBloc(catalogs: [MinimalCatalog()])
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 'surf_node_sub',
              'catalogId': minimalCatalogId,
            },
          }),
        )
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateDataModel': {
              'surfaceId': 'surf_node_sub',
              'path': '/title',
              'value': 'Initial Node Title',
            },
          }),
        )
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateComponents': {
              'surfaceId': 'surf_node_sub',
              'components': [
                {
                  'id': 'root',
                  'component': 'Text',
                  'text': {'path': '/title'},
                },
              ],
            },
          }),
        );
      await pumpEventQueue();

      final controller = _TestController();
      tester.pumpComponent(
        _TestWrapper(
          controller: controller,
          bloc: bloc,
          surfaceId: 'surf_node_sub',
        ),
      );
      await tester.pump();
      expect(find.text('Initial Node Title'), findsOneComponent);

      // Update data model to trigger node.props.subscribe
      bloc.add(
        const ProcessJsonMessage({
          'version': 'v0.9',
          'updateDataModel': {
            'surfaceId': 'surf_node_sub',
            'path': '/title',
            'value': 'Updated Node Title',
          },
        }),
      );
      await pumpEventQueue();
      await tester.pump();
      expect(find.text('Updated Node Title'), findsOneComponent);

      // Hide to trigger dispose
      controller.hide?.call();
      await tester.pump();
      await bloc.close();
    });

    testComponents('_ResolvedNodeComponent catches error when builder throws',
        (tester) async {
      final catalog = A2uiJasprCatalog()
        ..register('Text', (context, compContext) {
          throw StateError('Boom in Text node!');
        });

      final bloc = A2uiSurfaceBloc(catalogs: [MinimalCatalog()])
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 'surf_node_err',
              'catalogId': minimalCatalogId,
            },
          }),
        )
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateComponents': {
              'surfaceId': 'surf_node_err',
              'components': [
                {
                  'id': 'root',
                  'component': 'Text',
                  'text': 'Will explode',
                },
              ],
            },
          }),
        );
      await pumpEventQueue();

      tester.pumpComponent(
        A2uiSurfaceView(
          bloc: bloc,
          surfaceId: 'surf_node_err',
          catalog: catalog,
        ),
      );
      await tester.pump();
      expect(
        find.text('Failed to render component "root"'),
        findsOneComponent,
      );
      await bloc.close();
    });

    testComponents(
        '_collectChildNodes handles Map properties and child fallback in '
        '_ResolvedNodeComponent', (tester) async {
      final catalog = A2uiJasprCatalog.standard()
        ..register('Card', (context, compContext) {
          return div([
            compContext.buildChild('external_child'),
          ]);
        });

      final bloc = A2uiSurfaceBloc(catalogs: [MinimalCatalog()])
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 'surf_container',
              'catalogId': minimalCatalogId,
            },
          }),
        )
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateComponents': {
              'surfaceId': 'surf_container',
              'components': [
                {
                  'id': 'root',
                  'component': 'Card',
                  'child': 'card_child',
                  'extraSlots': {
                    'slot1': {'id': 'card_child'},
                  },
                },
                {
                  'id': 'card_child',
                  'component': 'Text',
                  'text': 'Card Child Text',
                },
                {
                  'id': 'external_child',
                  'component': 'Text',
                  'text': 'External Child Rendered',
                },
              ],
            },
          }),
        );
      await pumpEventQueue();

      tester.pumpComponent(
        A2uiSurfaceView(
          bloc: bloc,
          surfaceId: 'surf_container',
          catalog: catalog,
        ),
      );
      await pumpEventQueue();
      await tester.pump();

      expect(find.text('External Child Rendered'), findsOneComponent);
      await bloc.close();
    });

    testComponents(
        '_BoundComponent disposes owned binder on update and unmount',
        (tester) async {
      final bloc = A2uiSurfaceBloc(catalogs: [MinimalCatalog()])
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 'surf_owned_binder',
              'catalogId': minimalCatalogId,
            },
          }),
        );
      await pumpEventQueue();

      final surface = bloc.processor.model.getSurface('surf_owned_binder')!;
      surface.dataModel.set('/items', [
        {'title': 'Item A'},
      ]);
      surface.componentsModel.addComponent(
        ComponentModel('col_tmpl', 'Column', {
          'children': {
            'componentId': 'item_node',
            'path': '/items',
          },
        }),
      );
      surface.componentsModel.addComponent(
        ComponentModel('item_node', 'Text', {
          'text': {'path': 'title'},
        }),
      );

      final controller = _TestController();
      bloc.emitForTest(
        SurfaceReady(
          surfaceId: 'surf_owned_binder',
          surface: surface,
          version: 1,
        ),
      );

      tester.pumpComponent(
        _TestWrapper(
          controller: controller,
          bloc: bloc,
          surfaceId: 'surf_owned_binder',
        ),
      );
      await tester.pump();
      expect(find.text('Item A'), findsOneComponent);

      // Mutate data model to update template items
      surface.dataModel.set('/items', [
        {'title': 'Item B'},
      ]);
      bloc.emitForTest(
        SurfaceReady(
          surfaceId: 'surf_owned_binder',
          surface: surface,
          version: 2,
        ),
      );
      await tester.pump();
      expect(find.text('Item B'), findsOneComponent);

      // Hide to trigger unmount and dispose of owned binders
      controller.hide?.call();
      await tester.pump();
      await bloc.close();
    });

    testComponents(
        'handles schema == null in scoped binder and fallback when '
        'binder is null', (tester) async {
      final catalog = A2uiJasprCatalog.standard()
        ..register('Unschematized', (context, compContext) {
          return div([
            Component.text('Raw property: ${compContext.props['customProp']}'),
          ]);
        });

      final bloc = A2uiSurfaceBloc(catalogs: [MinimalCatalog()])
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 'surf_unschem',
              'catalogId': minimalCatalogId,
            },
          }),
        );
      await pumpEventQueue();

      final surface = bloc.processor.model.getSurface('surf_unschem')!;
      surface.dataModel.set('/items', [
        {'title': 'Unschem 1'},
      ]);
      surface.componentsModel.addComponent(
        ComponentModel('col_unschem', 'Column', {
          'children': {
            'componentId': 'item_unschem',
            'path': '/items',
          },
        }),
      );
      surface.componentsModel.addComponent(
        ComponentModel('item_unschem', 'Unschematized', const {
          'customProp': 'Custom Value',
        }),
      );

      bloc.emitForTest(
        SurfaceReady(surfaceId: 'surf_unschem', surface: surface),
      );
      tester.pumpComponent(
        A2uiSurfaceView(
          bloc: bloc,
          surfaceId: 'surf_unschem',
          catalog: catalog,
        ),
      );
      await tester.pump();
      expect(find.text('Raw property: Custom Value'), findsOneComponent);
      await bloc.close();
    });

    testComponents(
        'renders targeted SurfaceReady when active surface in bloc '
        'is different', (tester) async {
      final bloc = A2uiSurfaceBloc(catalogs: [MinimalCatalog()])
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 's_targeted_ready',
              'catalogId': minimalCatalogId,
            },
          }),
        )
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateComponents': {
              'surfaceId': 's_targeted_ready',
              'components': [
                {'id': 't1', 'component': 'Text', 'text': 'Targeted Content'},
              ],
            },
          }),
        )
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 's_active_other',
              'catalogId': minimalCatalogId,
            },
          }),
        );
      await pumpEventQueue();

      tester.pumpComponent(
        A2uiSurfaceView(bloc: bloc, surfaceId: 's_targeted_ready'),
      );
      await tester.pump();
      expect(find.text('Targeted Content'), findsOneComponent);
      await bloc.close();
    });

    testComponents('renders default validation error banner when errors exist',
        (tester) async {
      final bloc = A2uiSurfaceBloc(catalogs: [MinimalCatalog()]);
      final surface = SurfaceModel<ComponentApi>(
        's_val_err',
        defaultCatalog: MinimalCatalog(),
      )..componentsModel.addComponent(
          ComponentModel('t1', 'Text', const {'text': 'Valid Comp'}),
        );

      bloc.emitForTest(
        SurfaceReady(
          surfaceId: 's_val_err',
          surface: surface,
          isValid: false,
          validationErrors: const ['Field "name" is required'],
        ),
      );

      tester.pumpComponent(
        A2uiSurfaceView(bloc: bloc, surfaceId: 's_val_err'),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('a2ui_validation_errors_banner')),
        findsOneComponent,
      );
      expect(find.text('Field "name" is required'), findsOneComponent);
      await bloc.close();
    });

    testComponents('handles null binder fallback in _BoundComponent',
        (tester) async {
      final bloc = A2uiSurfaceBloc(catalogs: [MinimalCatalog()]);
      final surface = SurfaceModel<ComponentApi>(
        's_null_binder',
        defaultCatalog: MinimalCatalog(),
      );
      surface.componentsModel.addComponent(
        ComponentModel('parent', 'Card', const {'child': 'unbound_child'}),
      );
      bloc.emitForTest(
        SurfaceReady(surfaceId: 's_null_binder', surface: surface),
      );

      final controller = _TestController();
      tester.pumpComponent(
        _TestWrapper(
          controller: controller,
          bloc: bloc,
          surfaceId: 's_null_binder',
        ),
      );
      await tester.pump();

      // Add unbound_child directly to componentsModel without changing version
      surface.componentsModel.addComponent(
        ComponentModel(
          'unbound_child',
          'Text',
          const {'text': 'Fallback Raw Props'},
        ),
      );

      // Rebuild wrapper so _SurfaceTreeRenderer rebuilds without
      // reconciling binders
      controller.update?.call(newBloc: bloc, newSurfaceId: 's_null_binder');
      await tester.pump();

      expect(find.text('Fallback Raw Props'), findsOneComponent);
      await bloc.close();
    });
  });
}

extension on A2uiSurfaceBloc {
  void emitForTest(A2uiSurfaceState state) {
    emit(state);
  }
}

class _TestController {
  void Function({required A2uiSurfaceBloc newBloc, String? newSurfaceId})?
      update;
  void Function()? hide;
}

class _TestWrapper extends StatefulComponent {
  const _TestWrapper({
    required this.bloc,
    required this.controller,
    this.surfaceId,
  });

  final A2uiSurfaceBloc bloc;
  final String? surfaceId;
  final _TestController controller;

  @override
  State<_TestWrapper> createState() => _TestWrapperState();
}

class _TestWrapperState extends State<_TestWrapper> {
  late A2uiSurfaceBloc bloc;
  late String? surfaceId;
  bool show = true;

  @override
  void initState() {
    super.initState();
    bloc = component.bloc;
    surfaceId = component.surfaceId;
    component.controller.update = ({
      required newBloc,
      newSurfaceId,
    }) {
      setState(() {
        bloc = newBloc;
        surfaceId = newSurfaceId;
      });
    };
    component.controller.hide = () {
      setState(() {
        show = false;
      });
    };
  }

  @override
  Component build(BuildContext context) {
    if (!show) return const div([]);
    return A2uiSurfaceView(bloc: bloc, surfaceId: surfaceId);
  }
}
