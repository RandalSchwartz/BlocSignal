import 'package:bloc_signals_genui/bloc_signals_genui.dart';
import 'package:bloc_signals_genui_flutter/bloc_signals_genui_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

class _CustomComponentApi extends ComponentApi {
  _CustomComponentApi({required super.name, required super.schema});
}

void main() {
  const customCatalogId = 'https://custom.catalog/defensive_test.json';

  final extendedCatalog = Catalog<ComponentApi, FunctionImplementation>(
    id: customCatalogId,
    components: [
      ...MinimalCatalog().components.values.where(
            (c) => c.name != 'Card' && c.name != 'Divider',
          ),
      _CustomComponentApi(
        name: 'Card',
        schema: Schema.fromMap(const <String, Object?>{
          'properties': <String, Object?>{
            'child': <String, Object?>{'type': 'string'},
            'elevation': <String, Object?>{},
          },
        }),
      ),
      _CustomComponentApi(
        name: 'Divider',
        schema: Schema.fromMap(const <String, Object?>{
          'properties': <String, Object?>{
            'height': <String, Object?>{},
            'thickness': <String, Object?>{},
          },
        }),
      ),
      _CustomComponentApi(
        name: 'FaultyWidget',
        schema: Schema.fromMap(const <String, Object?>{}),
      ),
    ],
  );

  group('A2UI Defensive Prop Parsing & Error Boundary ([F-13])', () {
    testWidgets(
        'Malformed JSON props in Card and Divider do not crash rendering',
        (tester) async {
      final bloc = A2uiSurfaceBloc(catalogs: [extendedCatalog])
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 'malformed_surf',
              'catalogId': customCatalogId,
            },
          }),
        )
        // Card with string elevation, and Divider with string height
        // and thickness
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateComponents': {
              'surfaceId': 'malformed_surf',
              'components': [
                {
                  'id': 'root_col',
                  'component': 'Column',
                  'children': ['card_1', 'div_1'],
                },
                {
                  'id': 'card_1',
                  'component': 'Card',
                  'elevation':
                      'not_a_number', // Malformed string instead of num
                  'child': 'txt_card',
                },
                {
                  'id': 'txt_card',
                  'component': 'Text',
                  'text': 'Inside Card',
                },
                {
                  'id': 'div_1',
                  'component': 'Divider',
                  'height': 'invalid_height',
                  'thickness': 'invalid_thickness',
                },
              ],
            },
          }),
        );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: A2uiSurfaceView(bloc: bloc),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Inside Card'), findsOneWidget);
      expect(find.byType(Card), findsOneWidget);
      expect(find.byType(Divider), findsOneWidget);

      await bloc.close();
    });

    testWidgets(
        'Faulty component builder triggers fallback error placeholder '
        'without crashing tree', (tester) async {
      final bloc = A2uiSurfaceBloc(catalogs: [extendedCatalog])
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 'error_surf',
              'catalogId': customCatalogId,
            },
          }),
        )
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateComponents': {
              'surfaceId': 'error_surf',
              'components': [
                {
                  'id': 'faulty_comp',
                  'component': 'FaultyWidget',
                },
              ],
            },
          }),
        );

      // Create a catalog with a faulty builder that throws
      final customCatalog = A2uiFlutterCatalog()
        ..register('FaultyWidget', (ctx, compCtx) {
          throw StateError('Simulated unexpected widget render crash');
        });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: A2uiSurfaceView(
              bloc: bloc,
              catalog: customCatalog,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('error_fallback_faulty_comp')),
        findsOneWidget,
      );
      expect(
        find.text('Failed to render component "faulty_comp"'),
        findsOneWidget,
      );

      await bloc.close();
    });

    testWidgets(
      '(Issue #369) Defensive parsing on malformed properties in new and '
      'enhanced widgets',
      (tester) async {
        final bloc = A2uiSurfaceBloc();
        addTearDown(bloc.close);
        final catalog = A2uiFlutterCatalog.standard();

        final malformedComponents = <ComponentModel>[
          ComponentModel('list-bad', 'List', const {
            'direction': 999,
            'align': 'unknown_align',
            'children': 'not_a_list',
          }),
          ComponentModel('tabs-bad', 'Tabs', const {
            'tabs': null,
          }),
          ComponentModel('modal-bad', 'Modal', const {
            'trigger': null,
            'content': null,
          }),
          ComponentModel('icon-bad', 'Icon', const {
            'name': 'nonExistentIconName',
          }),
          ComponentModel('img-bad', 'Image', const {
            'url': '',
            'fit': 'invalid_fit',
            'variant': 'invalid_variant',
          }),
          ComponentModel('cb-bad', 'CheckBox', const {
            'label': 123,
            'value': 'not_a_bool',
          }),
          ComponentModel('cp-bad', 'ChoicePicker', const {
            'label': 'Bad Picker',
            'variant': 'invalid_variant',
            'displayStyle': 'invalid_style',
            'options': 'not_a_list',
            'value': 42,
          }),
          ComponentModel('slider-bad', 'Slider', const {
            'label': 'Bad Slider',
            'min': 100,
            'max': 10,
            'value': 'not_a_num',
          }),
          ComponentModel('dt-bad', 'DateTimeInput', const {
            'label': 'Bad Date',
            'value': 'not-an-iso-date',
            'enableDate': 'invalid_bool',
            'enableTime': 'invalid_bool',
          }),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Builder(
                  builder: (context) => Column(
                    children: [
                      for (final comp in malformedComponents)
                        catalog.build(
                          context,
                          A2uiComponentContext(
                            component: comp,
                            props: comp.properties,
                            surfaceBloc: bloc,
                            buildChildCallback: (_) => const SizedBox.shrink(),
                            buildChildrenCallback: (_) => const <Widget>[],
                            surfaceId: 'surf-malformed',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byIcon(Icons.help_outline), findsOneWidget);
        expect(find.byType(CheckboxListTile), findsOneWidget);
        expect(find.byType(Slider), findsOneWidget);
      },
    );
  });
}
