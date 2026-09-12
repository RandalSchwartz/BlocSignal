import 'package:a2ui_core/a2ui_core.dart';
import 'package:bloc_signals_genui/bloc_signals_genui.dart';
import 'package:bloc_signals_genui_flutter/bloc_signals_genui_flutter.dart';
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

void main() {
  const minimalCatalogId =
      'https://a2ui.org/specification/v0_9/catalogs/minimal/minimal_catalog.json';

  group('A2uiFlutterCatalog', () {
    testWidgets('renders standard Text variants correctly', (tester) async {
      final bloc = A2uiSurfaceBloc();
      final catalog = A2uiFlutterCatalog.standard();

      bloc
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
                  'text': 'Hello Generative UI',
                  'variant': 'h1',
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
              catalog: catalog,
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Hello Generative UI'), findsOneWidget);

      await bloc.close();
    });

    testWidgets('renders Row and Column with nested children', (tester) async {
      final bloc = A2uiSurfaceBloc();
      final catalog = A2uiFlutterCatalog.standard();

      bloc
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 'surf-layout',
              'catalogId': minimalCatalogId,
            },
          }),
        )
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateComponents': {
              'surfaceId': 'surf-layout',
              'components': [
                {
                  'id': 'col-1',
                  'component': 'Column',
                  'children': ['row-1', 'txt-bottom'],
                },
                {
                  'id': 'row-1',
                  'component': 'Row',
                  'children': ['txt-left', 'txt-right'],
                },
                {
                  'id': 'txt-left',
                  'component': 'Text',
                  'text': 'Left Item',
                },
                {
                  'id': 'txt-right',
                  'component': 'Text',
                  'text': 'Right Item',
                },
                {
                  'id': 'txt-bottom',
                  'component': 'Text',
                  'text': 'Bottom Item',
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
              catalog: catalog,
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Left Item'), findsOneWidget);
      expect(find.text('Right Item'), findsOneWidget);
      expect(find.text('Bottom Item'), findsOneWidget);

      await bloc.close();
    });

    testWidgets('renders Card and Divider in extended catalog', (tester) async {
      final customCoreCatalog = Catalog<ComponentApi>(
        id: 'https://custom.catalog/custom.json',
        components: [
          ...MinimalCatalog().components.values,
          _CustomComponentApi(
            name: 'Card',
            schema: Schema.fromMap(const {
              'properties': {
                'child': {'type': 'string'},
                'elevation': {'type': 'number'},
              },
            }),
          ),
          _CustomComponentApi(
            name: 'Divider',
            schema: Schema.fromMap(const {
              'properties': {
                'height': {'type': 'number'},
                'thickness': {'type': 'number'},
              },
            }),
          ),
        ],
      );
      final bloc = A2uiSurfaceBloc(catalogs: [customCoreCatalog]);
      final catalog = A2uiFlutterCatalog.standard();

      bloc
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 'surf-card',
              'catalogId': 'https://custom.catalog/custom.json',
            },
          }),
        )
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateComponents': {
              'surfaceId': 'surf-card',
              'components': [
                {
                  'id': 'col-card',
                  'component': 'Column',
                  'children': ['card-1', 'div-1'],
                },
                {
                  'id': 'card-1',
                  'component': 'Card',
                  'child': 'txt-in-card',
                },
                {
                  'id': 'txt-in-card',
                  'component': 'Text',
                  'text': 'Inside Card',
                },
                {
                  'id': 'div-1',
                  'component': 'Divider',
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
              catalog: catalog,
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Inside Card'), findsOneWidget);
      expect(find.byType(Card), findsOneWidget);
      expect(find.byType(Divider), findsOneWidget);

      await bloc.close();
    });

    testWidgets('renders fallback widget on unknown component type',
        (tester) async {
      final customCoreCatalog = Catalog<ComponentApi>(
        id: 'https://custom.catalog/custom.json',
        components: [
          ...MinimalCatalog().components.values,
          _CustomComponentApi(
            name: 'HologramDisplay',
            schema: Schema.fromMap(const {}),
          ),
        ],
      );
      final bloc = A2uiSurfaceBloc(catalogs: [customCoreCatalog]);
      final catalog = A2uiFlutterCatalog(); // empty

      bloc
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 'surf-unknown',
              'catalogId': 'https://custom.catalog/custom.json',
            },
          }),
        )
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateComponents': {
              'surfaceId': 'surf-unknown',
              'components': [
                {
                  'id': 'u-1',
                  'component': 'HologramDisplay',
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
              catalog: catalog,
            ),
          ),
        ),
      );

      await tester.pump();
      expect(
        find.text('Unknown A2UI Component: <HologramDisplay>'),
        findsOneWidget,
      );

      await bloc.close();
    });

    testWidgets('allows custom component registration', (tester) async {
      final customCoreCatalog = Catalog<ComponentApi>(
        id: 'https://custom.catalog/custom.json',
        components: [
          ...MinimalCatalog().components.values,
          _CustomComponentApi(
            name: 'Badge',
            schema: Schema.fromMap(const {
              'properties': {
                'label': {'type': 'string'},
              },
            }),
          ),
        ],
      );
      final bloc = A2uiSurfaceBloc(catalogs: [customCoreCatalog]);
      final catalog = A2uiFlutterCatalog()
        ..register('Badge', (context, compCtx) {
          final label = compCtx.props['label']?.toString() ?? '';
          return Chip(label: Text(label));
        });

      bloc
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 'surf-custom',
              'catalogId': 'https://custom.catalog/custom.json',
            },
          }),
        )
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateComponents': {
              'surfaceId': 'surf-custom',
              'components': [
                {
                  'id': 'b-1',
                  'component': 'Badge',
                  'label': 'Verified AI',
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
              catalog: catalog,
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Verified AI'), findsOneWidget);
      expect(find.byType(Chip), findsOneWidget);

      await bloc.close();
    });

    testWidgets('renders all Text variants (h2, h3, title, caption, body)',
        (tester) async {
      final bloc = A2uiSurfaceBloc();
      final catalog = A2uiFlutterCatalog.standard();

      bloc
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 'surf-variants',
              'catalogId': minimalCatalogId,
            },
          }),
        )
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateComponents': {
              'surfaceId': 'surf-variants',
              'components': [
                {
                  'id': 't-h2',
                  'component': 'Text',
                  'text': 'H2 Text',
                  'variant': 'h2',
                },
                {
                  'id': 't-h3',
                  'component': 'Text',
                  'text': 'H3 Text',
                  'variant': 'h3',
                },
                {
                  'id': 't-title',
                  'component': 'Text',
                  'text': 'Title Text',
                  'variant': 'title',
                },
                {
                  'id': 't-cap',
                  'component': 'Text',
                  'text': 'Caption Text',
                  'variant': 'caption',
                },
                {
                  'id': 't-body',
                  'component': 'Text',
                  'text': 'Body Text',
                  'variant': 'body',
                },
                {
                  'id': 't-def',
                  'component': 'Text',
                  'text': 'Default Text',
                  'variant': 'other',
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
              catalog: catalog,
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('H2 Text'), findsOneWidget);
      expect(find.text('H3 Text'), findsOneWidget);
      expect(find.text('Title Text'), findsOneWidget);
      expect(find.text('Caption Text'), findsOneWidget);
      expect(find.text('Body Text'), findsOneWidget);
      expect(find.text('Default Text'), findsOneWidget);

      await bloc.close();
    });

    test('initialBuilders in constructor and hasBuilder check', () {
      final catalog = A2uiFlutterCatalog(
        initialBuilders: {
          'Dummy': (context, compCtx) => const SizedBox(),
        },
      );
      expect(catalog.hasBuilder('Dummy'), isTrue);
    });

    testWidgets(
        'renders Row and Column with alignment variants and ChildNode children',
        (tester) async {
      final bloc = A2uiSurfaceBloc();
      final catalog = A2uiFlutterCatalog.standard();

      bloc
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 'surf-flex',
              'catalogId': minimalCatalogId,
            },
          }),
        )
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateComponents': {
              'surfaceId': 'surf-flex',
              'components': [
                {
                  'id': 'col-flex',
                  'component': 'Column',
                  'mainAxisAlignment': 'center',
                  'crossAxisAlignment': 'start',
                  'children': ['row-flex'],
                },
                {
                  'id': 'row-flex',
                  'component': 'Row',
                  'mainAxisAlignment': 'spaceBetween',
                  'crossAxisAlignment': 'start',
                  'children': ['txt-f1', 'txt-f2'],
                },
                {
                  'id': 'txt-f1',
                  'component': 'Text',
                  'text': 'Flex 1',
                },
                {
                  'id': 'txt-f2',
                  'component': 'Text',
                  'text': 'Flex 2',
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
              catalog: catalog,
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Flex 1'), findsOneWidget);
      expect(find.text('Flex 2'), findsOneWidget);

      await bloc.close();
    });

    testWidgets('Row and Column handle ChildNode and direct Maps in children',
        (tester) async {
      final bloc = A2uiSurfaceBloc();
      final ctx = A2uiComponentContext(
        component: ComponentModel(
          'col',
          'Column',
          {
            'children': [
              ChildNode('c1', '/col/children/0'),
              {'id': 'c2'},
              'c3',
            ],
          },
        ),
        props: {
          'children': [
            ChildNode('c1', '/col/children/0'),
            {'id': 'c2'},
            'c3',
          ],
        },
        surfaceBloc: bloc,
        surfaceId: 'surf-test',
        buildChildCallback: (id) => Text('Rendered $id'),
        buildChildrenCallback: (ids) =>
            ids.map((id) => Text('Rendered $id')).toList(),
      );

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final element = tester.element(find.byType(SizedBox));
      final colWidget = buildA2uiColumn(
        element,
        ctx,
      );
      final rowWidget = buildA2uiRow(
        tester.element(find.byType(SizedBox)),
        ctx,
      );

      expect(colWidget, isA<Column>());
      expect(rowWidget, isA<Row>());
      await bloc.close();
    });
  });
}
