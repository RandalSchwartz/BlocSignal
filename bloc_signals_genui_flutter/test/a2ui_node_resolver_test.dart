import 'package:bloc_signals_genui/bloc_signals_genui.dart';
import 'package:bloc_signals_genui_flutter/bloc_signals_genui_flutter.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/safe_prop_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema_builder/json_schema_builder.dart'
    hide ValidationResult;

class _SimpleCustomApi extends ComponentApi {
  _SimpleCustomApi(String name)
      : super(
          name: name,
          schema: Schema.object(
            properties: {
              'relMap': CommonSchemas.dynamicString,
            },
            additionalProperties: true,
          ),
        );
}

void main() {
  const minimalCatalogId =
      'https://a2ui.org/specification/v0_9/catalogs/minimal/minimal_catalog.json';

  group(
    '(Issue #370) NodeResolver Reactive Tree & Template ChildList Expansion '
    'in A2uiSurfaceView',
    () {
      testWidgets(
        'Scenario: Data-driven ChildList template expansion renders repeated '
        'child subtrees with scoped DataContext',
        (tester) async {
          final bloc = A2uiSurfaceBloc();
          addTearDown(bloc.close);

          bloc.add(
            ProcessMessages([
              CreateSurfaceMessage(
                version: 'v0.9',
                surfaceId: 'surf-list',
                catalogId: minimalCatalogId,
              ),
              UpdateDataModelMessage(
                version: 'v0.9',
                surfaceId: 'surf-list',
                path: '/items',
                value: const [
                  {'title': 'Alpha'},
                  {'title': 'Beta'},
                ],
              ),
              UpdateComponentsMessage(
                version: 'v0.9',
                surfaceId: 'surf-list',
                components: const [
                  {
                    'id': 'root',
                    'component': 'Column',
                    'children': {
                      'componentId': 'item_row',
                      'path': '/items',
                    },
                  },
                  {
                    'id': 'item_row',
                    'component': 'Column',
                    'children': ['item_text', 'item_field'],
                  },
                  {
                    'id': 'item_text',
                    'component': 'Text',
                    'text': {'path': 'title'},
                  },
                  {
                    'id': 'item_field',
                    'component': 'TextField',
                    'label': 'Item Title',
                    'value': {'path': 'title'},
                  },
                ],
              ),
            ]),
          );

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: A2uiSurfaceView(bloc: bloc),
                ),
              ),
            ),
          );
          await tester.pump();

          expect(find.byType(TextField), findsNWidgets(2));
          expect(find.text('Alpha'), findsWidgets);
          expect(find.text('Beta'), findsWidgets);

          // Verify extractChildId supports ComponentNode from root's node.props
          final ready = bloc.value as SurfaceReady;
          final resolver = NodeResolver<ComponentApi>(ready.surface);
          addTearDown(resolver.dispose);
          final rootChildren =
              resolver.rootNode.value!.props.value['children']! as List;
          expect(rootChildren.first, isA<ComponentNode<ComponentApi>>());
          expect(
            extractChildId(rootChildren.first),
            equals((rootChildren.first as ComponentNode).instanceId),
          );

          // Type "Alpha Updated" into the first TextField (index 0)
          await tester.enterText(find.byType(TextField).first, 'Alpha Updated');
          await tester.pump();

          expect(
            ready.surface.dataModel.get('/items/0/title'),
            equals('Alpha Updated'),
          );
          expect(
            ready.surface.dataModel.get('/items/1/title'),
            equals('Beta'),
          );

          // Update DataModel at /items to 3 items
          bloc.add(
            const UpdateFormField(
              surfaceId: 'surf-list',
              path: '/items',
              value: [
                {'title': 'Alpha Updated'},
                {'title': 'Beta'},
                {'title': 'Gamma'},
              ],
            ),
          );
          await tester.pump();

          expect(find.byType(TextField), findsNWidgets(3));
          expect(find.text('Gamma'), findsWidgets);
        },
      );

      group(
        'Scenario Outline: NodeResolver NodeState edge cases in '
        'A2uiSurfaceView',
        () {
          testWidgets(
            'Example 1: NodeState.pending renders SizedBox.shrink with '
            'ValueKey("missing_<componentId>") until definition arrives, '
            'then upgrades in-place',
            (tester) async {
              final bloc = A2uiSurfaceBloc()
                ..add(
                  ProcessMessages([
                    CreateSurfaceMessage(
                      version: 'v0.9',
                      surfaceId: 'surf-pending',
                      catalogId: minimalCatalogId,
                    ),
                    UpdateComponentsMessage(
                      version: 'v0.9',
                      surfaceId: 'surf-pending',
                      components: const [
                        {
                          'id': 'root',
                          'component': 'Column',
                          'children': ['late_child'],
                        },
                      ],
                    ),
                  ]),
                );
              addTearDown(bloc.close);

              await tester.pumpWidget(
                MaterialApp(
                  home: Scaffold(
                    body: A2uiSurfaceView(bloc: bloc),
                  ),
                ),
              );
              await tester.pump();

              expect(
                find.byKey(const ValueKey('missing_late_child')),
                findsOneWidget,
              );

              // Now stream the missing component definition
              bloc.add(
                ProcessMessage(
                  UpdateComponentsMessage(
                    version: 'v0.9',
                    surfaceId: 'surf-pending',
                    components: const [
                      {
                        'id': 'late_child',
                        'component': 'Text',
                        'text': 'Arrived In Place',
                      },
                    ],
                  ),
                ),
              );
              await tester.pump();

              expect(
                find.byKey(const ValueKey('missing_late_child')),
                findsNothing,
              );
              expect(find.text('Arrived In Place'), findsOneWidget);
            },
          );

          testWidgets(
            'Example 2: NodeState.cyclic renders SizedBox.shrink with '
            'ValueKey("circular_ref_<componentId>") breaking recursion',
            (tester) async {
              final bloc = A2uiSurfaceBloc()
                ..add(
                  ProcessMessages([
                    CreateSurfaceMessage(
                      version: 'v0.9',
                      surfaceId: 'surf-cyclic',
                      catalogId: minimalCatalogId,
                    ),
                    UpdateComponentsMessage(
                      version: 'v0.9',
                      surfaceId: 'surf-cyclic',
                      components: const [
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
                    ),
                  ]),
                );
              addTearDown(bloc.close);

              await tester.pumpWidget(
                MaterialApp(
                  home: Scaffold(
                    body: A2uiSurfaceView(bloc: bloc),
                  ),
                ),
              );
              await tester.pump();

              expect(
                find.byKey(const ValueKey('circular_ref_root')),
                findsOneWidget,
              );
            },
          );

          testWidgets(
            'Example 3: NodeState.unknownType renders localized component '
            'error fallback widget with ValueKey("a2ui_error_<componentId>")',
            (tester) async {
              final bloc = A2uiSurfaceBloc()
                ..add(
                  ProcessMessages([
                    CreateSurfaceMessage(
                      version: 'v0.9',
                      surfaceId: 'surf-unknown',
                      catalogId: minimalCatalogId,
                    ),
                    UpdateComponentsMessage(
                      version: 'v0.9',
                      surfaceId: 'surf-unknown',
                      components: const [
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
                    ),
                  ]),
                );
              addTearDown(bloc.close);

              await tester.pumpWidget(
                MaterialApp(
                  home: Scaffold(
                    body: A2uiSurfaceView(bloc: bloc),
                  ),
                ),
              );
              await tester.pump();

              expect(
                find.byKey(const ValueKey('a2ui_error_mystery_box')),
                findsOneWidget,
              );
              expect(
                find.text('Failed to render component "mystery_box"'),
                findsOneWidget,
              );
            },
          );

          testWidgets(
            'Example 4: unrooted surface fallback heuristic root scan renders '
            'components and expands ChildList templates when surface.rootId '
            '("root") is absent, then upgrades to NodeResolver when "root" '
            'arrives',
            (tester) async {
              final bloc = A2uiSurfaceBloc()
                ..add(
                  ProcessMessages([
                    CreateSurfaceMessage(
                      version: 'v0.9',
                      surfaceId: 'surf-unrooted',
                      catalogId: minimalCatalogId,
                    ),
                    UpdateDataModelMessage(
                      version: 'v0.9',
                      surfaceId: 'surf-unrooted',
                      path: '/rows',
                      value: const [
                        {'label': 'Row One'},
                        {'label': 'Row Two'},
                      ],
                    ),
                    UpdateComponentsMessage(
                      version: 'v0.9',
                      surfaceId: 'surf-unrooted',
                      components: const [
                        {
                          'id': 'custom_header',
                          'component': 'Column',
                          'children': {
                            'componentId': 'unrooted_item',
                            'path': '/rows',
                          },
                        },
                        {
                          'id': 'unrooted_item',
                          'component': 'Text',
                          'text': {'path': 'label'},
                        },
                      ],
                    ),
                  ]),
                );
              addTearDown(bloc.close);

              await tester.pumpWidget(
                MaterialApp(
                  home: Scaffold(
                    body: A2uiSurfaceView(bloc: bloc),
                  ),
                ),
              );
              await tester.pump();

              expect(find.text('Row One'), findsOneWidget);
              expect(find.text('Row Two'), findsOneWidget);

              // Mutate unrooted template item to trigger scoped binder update
              final ready = bloc.value as SurfaceReady;
              ready.surface.componentsModel.removeComponent('unrooted_item');
              ready.surface.componentsModel.addComponent(
                ComponentModel('unrooted_item', 'Text', const {
                  'text': {'path': 'label'},
                }),
              );
              // Trigger a rebuild while unrooted_item is still referenced so
              // _BoundComponentWidget.didUpdateWidget disposes oldWidget.binder
              bloc.add(
                const UpdateFormField(
                  surfaceId: 'surf-unrooted',
                  path: '/rows/0/label',
                  value: 'Row One Step 1',
                ),
              );
              await tester.pump();
              expect(find.text('Row One Step 1'), findsOneWidget);

              ready.surface.componentsModel.addComponent(
                ComponentModel(
                  'unrooted_unknown_child',
                  'UnknownTypeX',
                  const {},
                ),
              );
              ready.surface.componentsModel.removeComponent('custom_header');
              ready.surface.componentsModel.addComponent(
                ComponentModel('custom_header', 'Column', const {
                  'children': {
                    'componentId': 'unrooted_unknown_child',
                    'path': '/rows',
                  },
                }),
              );
              bloc.add(
                const UpdateFormField(
                  surfaceId: 'surf-unrooted',
                  path: '/rows/0/label',
                  value: 'Row One Updated',
                ),
              );
              await tester.pump();

              // Restore unrooted_item on custom_header
              ready.surface.componentsModel.removeComponent('custom_header');
              ready.surface.componentsModel.addComponent(
                ComponentModel('custom_header', 'Column', const {
                  'children': {
                    'componentId': 'unrooted_item',
                    'path': '/rows',
                  },
                }),
              );
              bloc.add(
                const UpdateFormField(
                  surfaceId: 'surf-unrooted',
                  path: '/rows/0/label',
                  value: 'Row One Updated',
                ),
              );
              await tester.pump();
              expect(find.text('Row One Updated'), findsOneWidget);

              // Now add a 'root' component directly to surface.componentsModel
              // so _resolver.rootNode.subscribe fires while mounted
              ready.surface.componentsModel.addComponent(
                ComponentModel('root', 'Column', const {
                  'children': ['custom_header'],
                }),
              );
              await tester.pump();
              expect(find.text('Row One Updated'), findsOneWidget);

              // Replace 'root' with a new ComponentModel instance so
              // _ResolvedNodeWidget.didUpdateWidget sees a new widget.node
              // with the same ValueKey('a2ui_node_root')
              ready.surface.componentsModel.removeComponent('root');
              ready.surface.componentsModel.addComponent(
                ComponentModel('root', 'Column', const {
                  'children': ['custom_header'],
                }),
              );
              await tester.pump();
              expect(find.text('Row One Updated'), findsOneWidget);
            },
          );
        },
      );

      testWidgets(
        'covers _ResolvedNodeWidget didUpdateWidget, nested Map child nodes '
        '(Tabs), fallback buildComponentCallback, error boundary, and '
        'A2uiComponentContext relative fallback/scope paths',
        (tester) async {
          const customCatalogId = 'https://custom.catalog/v1/extra.json';
          final baseBasic = BasicCatalog.v0_9();
          final customModelCatalog =
              Catalog<ComponentApi, FunctionImplementation>(
            id: customCatalogId,
            protocolVersion: A2uiProtocolVersion.v0_9,
            components: [
              ...baseBasic.components.values,
              _SimpleCustomApi('BoomWidget'),
              _SimpleCustomApi('CustomFallbackChild'),
            ],
            functions: baseBasic.functions.values.toList(),
            definitions: baseBasic.definitions,
          );

          final catalog = A2uiFlutterCatalog.standard()
            ..register('BoomWidget', (context, componentCtx) {
              throw StateError('Boom during build');
            })
            ..register('CustomFallbackChild', (context, componentCtx) {
              // Requests a child ID that is NOT in rawProps (falling back to
              // buildComponentCallback) and checks relative resolveBoundPath
              final relFallback = componentCtx.resolveBoundPath(
                'missingProp',
                fallbackPath: 'rel_field',
              );
              final relDefault = componentCtx.resolveBoundPath('missingProp');
              final relMapProp = componentCtx.resolveBoundPath('relMap');
              return Column(
                children: [
                  Text('paths:$relFallback|$relDefault|$relMapProp'),
                  componentCtx.buildChild('extra_leaf'),
                ],
              );
            });

          final bloc = A2uiSurfaceBloc(catalogs: [customModelCatalog])
            ..add(
              ProcessMessages([
                CreateSurfaceMessage(
                  version: 'v0.9',
                  surfaceId: 'surf-extra',
                  catalogId: customCatalogId,
                ),
                UpdateDataModelMessage(
                  version: 'v0.9',
                  surfaceId: 'surf-extra',
                  path: '/items',
                  value: const [
                    {'name': 'Item0'},
                  ],
                ),
                UpdateComponentsMessage(
                  version: 'v0.9',
                  surfaceId: 'surf-extra',
                  components: const [
                    {
                      'id': 'root',
                      'component': 'Column',
                      'children': [
                        'tabs_comp',
                        'boom_comp',
                        'template_holder',
                      ],
                    },
                    {
                      'id': 'tabs_comp',
                      'component': 'Tabs',
                      'tabs': [
                        {'title': 'Tab 1', 'child': 'tab_child_1'},
                      ],
                    },
                    {
                      'id': 'tab_child_1',
                      'component': 'Text',
                      'text': 'Inside Tab 1',
                    },
                    {
                      'id': 'boom_comp',
                      'component': 'BoomWidget',
                    },
                    {
                      'id': 'template_holder',
                      'component': 'Column',
                      'children': {
                        'componentId': 'scoped_custom',
                        'path': '/items',
                      },
                    },
                    {
                      'id': 'scoped_custom',
                      'component': 'CustomFallbackChild',
                      'relMap': {'path': 'name'},
                    },
                    {
                      'id': 'extra_leaf',
                      'component': 'Text',
                      'text': 'Extra Leaf Body',
                    },
                  ],
                ),
              ]),
            );
          addTearDown(bloc.close);

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: A2uiSurfaceView(
                    bloc: bloc,
                    catalog: catalog,
                  ),
                ),
              ),
            ),
          );
          await tester.pump();

          expect(find.text('Inside Tab 1'), findsOneWidget);
          expect(
            find.byKey(const ValueKey('a2ui_error_boom_comp')),
            findsOneWidget,
          );
          expect(
            find.text(
              'paths:/items/0/rel_field|/items/0/scoped_custom|/items/0/name',
            ),
            findsOneWidget,
          );
          expect(find.text('Extra Leaf Body'), findsOneWidget);

          // Also exercise A2uiComponentContext without node (node == null)
          // and non-root dataPath for _resolveOrScopePath fallback
          final detachedCtx = A2uiComponentContext(
            component: ComponentModel('comp_x', 'TextField', const {
              'value': {'path': 'relativeProp'},
            }),
            props: const {},
            dataPath: '/custom/scope',
            surfaceBloc: bloc,
            surfaceId: 'surf-extra',
            buildChildCallback: (_) => const SizedBox.shrink(),
            buildChildrenCallback: (_) => const [],
          );
          expect(
            detachedCtx.resolveBoundPath('value'),
            equals('/custom/scope/relativeProp'),
          );
          expect(
            detachedCtx.resolveBoundPath(
              'unmapped',
              fallbackPath: 'relFallback',
            ),
            equals('/custom/scope/relFallback'),
          );
          expect(
            detachedCtx.resolveBoundPath('unmapped'),
            equals('/custom/scope/comp_x'),
          );
        },
      );
    },
  );
}
