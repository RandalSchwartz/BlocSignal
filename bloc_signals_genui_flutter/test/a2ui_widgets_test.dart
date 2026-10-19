import 'package:bloc_signals_genui/bloc_signals_genui.dart';
import 'package:bloc_signals_genui_flutter/bloc_signals_genui_flutter.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/safe_prop_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const minimalCatalogId =
      'https://a2ui.org/specification/v0_9/catalogs/minimal/minimal_catalog.json';

  group('A2UI Interactive Catalog Widgets', () {
    testWidgets('Button dispatches action to A2uiSurfaceBloc', (tester) async {
      final bloc = A2uiSurfaceBloc();
      final catalog = A2uiFlutterCatalog.standard();

      bloc
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 'surf-btn',
              'catalogId': minimalCatalogId,
            },
          }),
        )
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateComponents': {
              'surfaceId': 'surf-btn',
              'components': [
                {
                  'id': 'btn-1',
                  'component': 'Button',
                  'child': 'txt-btn',
                  'action': {
                    'event': {'name': 'confirm_order'},
                    'context': {'orderId': '12345'},
                  },
                },
                {
                  'id': 'txt-btn',
                  'component': 'Text',
                  'text': 'Confirm Order',
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
      expect(find.text('Confirm Order'), findsOneWidget);

      await tester.tap(find.text('Confirm Order'));
      await tester.pump();

      expect(bloc.value, isA<SurfaceSubmitting>());
      final submitting = bloc.value as SurfaceSubmitting;
      expect(submitting.actionName, equals('confirm_order'));
      final contextMap =
          submitting.payload['context'] as Map<dynamic, dynamic>?;
      expect(contextMap?['orderId'], equals('12345'));

      await bloc.close();
    });

    testWidgets('Borderless Button renders TextButton and dispatches action',
        (tester) async {
      final bloc = A2uiSurfaceBloc();
      final catalog = A2uiFlutterCatalog.standard();

      bloc
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 'surf-borderless',
              'catalogId': minimalCatalogId,
            },
          }),
        )
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateComponents': {
              'surfaceId': 'surf-borderless',
              'components': [
                {
                  'id': 'btn-cancel',
                  'component': 'Button',
                  'variant': 'borderless',
                  'child': 'txt-cancel',
                  'action': 'cancel_action',
                },
                {
                  'id': 'txt-cancel',
                  'component': 'Text',
                  'text': 'Cancel',
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
      expect(find.byType(TextButton), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pump();

      expect(bloc.value, isA<SurfaceSubmitting>());
      final submitting = bloc.value as SurfaceSubmitting;
      expect(submitting.actionName, equals('cancel_action'));

      await bloc.close();
    });

    testWidgets('TextField updates text and syncs value to data model',
        (tester) async {
      final bloc = A2uiSurfaceBloc();
      final catalog = A2uiFlutterCatalog.standard();

      bloc
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 'surf-input',
              'catalogId': minimalCatalogId,
            },
          }),
        )
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateComponents': {
              'surfaceId': 'surf-input',
              'components': [
                {
                  'id': 'input-name',
                  'component': 'TextField',
                  'label': 'Your Name',
                  'value': {'path': '/userName'},
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
      expect(find.text('Your Name'), findsOneWidget);

      final tfFinder = find.byType(TextField);
      expect(tfFinder, findsOneWidget);

      await tester.enterText(tfFinder, 'Updated Val');
      await tester.pump();

      final tf = tester.widget<TextField>(tfFinder);
      expect(tf.controller?.text, equals('Updated Val'));

      final ready = bloc.value as SurfaceReady;
      expect(ready.surface.dataModel.get('/userName'), equals('Updated Val'));

      await bloc.close();
    });

    testWidgets(
        'Button dispatches action with object actionContext and string name',
        (tester) async {
      final bloc = A2uiSurfaceBloc();
      final catalog = A2uiFlutterCatalog.standard();

      bloc
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 'surf-btn-name',
              'catalogId': minimalCatalogId,
            },
          }),
        )
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateComponents': {
              'surfaceId': 'surf-btn-name',
              'components': [
                {
                  'id': 'btn-direct-name',
                  'component': 'Button',
                  'child': 'txt-direct',
                  'action': {
                    'name': 'quick_tap',
                  },
                },
                {
                  'id': 'txt-direct',
                  'component': 'Text',
                  'text': 'Quick Tap',
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
      await tester.tap(find.text('Quick Tap'));
      await tester.pump();

      expect(bloc.value, isA<SurfaceSubmitting>());
      expect((bloc.value as SurfaceSubmitting).actionName, equals('quick_tap'));

      await bloc.close();
    });

    testWidgets(
        '(Issue #301: F13) Button preserves action context from normalized '
        'event map', (tester) async {
      final bloc = A2uiSurfaceBloc();
      final catalog = A2uiFlutterCatalog.standard();
      addTearDown(bloc.close);

      bloc
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 'surf-btn-normalized',
              'catalogId': minimalCatalogId,
            },
          }),
        )
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateComponents': {
              'surfaceId': 'surf-btn-normalized',
              'components': [
                {
                  'id': 'btn-normalized-context',
                  'component': 'Button',
                  'child': 'txt-btn-norm',
                  'action': {
                    'event': {
                      'name': 'add_to_cart',
                      'context': {
                        'productId': 'prod_99',
                        'qty': 3,
                      },
                    },
                  },
                },
                {
                  'id': 'txt-btn-norm',
                  'component': 'Text',
                  'text': 'Add Normalized',
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
      await tester.tap(find.text('Add Normalized'));
      await tester.pump();

      expect(bloc.value, isA<SurfaceSubmitting>());
      final submitting = bloc.value as SurfaceSubmitting;
      expect(submitting.actionName, equals('add_to_cart'));
      expect(
        submitting.payload['context'],
        equals({'productId': 'prod_99', 'qty': 3}),
      );
    });

    testWidgets(
        '(Issue #301: F13) Button preserves action context from un-normalized '
        'fallback map', (tester) async {
      final bloc = A2uiSurfaceBloc();
      final catalog = A2uiFlutterCatalog.standard();
      addTearDown(bloc.close);

      bloc
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 'surf-btn-fallback',
              'catalogId': minimalCatalogId,
            },
          }),
        )
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateComponents': {
              'surfaceId': 'surf-btn-fallback',
              'components': [
                {
                  'id': 'btn-fallback-context',
                  'component': 'Button',
                  'child': 'txt-btn-fall',
                  'action': {
                    'name': 'add_to_cart',
                    'context': {
                      'productId': 'prod_fallback',
                      'qty': 1,
                    },
                  },
                },
                {
                  'id': 'txt-btn-fall',
                  'component': 'Text',
                  'text': 'Add Fallback',
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
      await tester.tap(find.text('Add Fallback'));
      await tester.pump();

      expect(bloc.value, isA<SurfaceSubmitting>());
      final submitting = bloc.value as SurfaceSubmitting;
      expect(submitting.actionName, equals('add_to_cart'));
      expect(
        submitting.payload['context'],
        equals({'productId': 'prod_fallback', 'qty': 1}),
      );
    });

    testWidgets('TextField updates when external property changes',
        (tester) async {
      final bloc = A2uiSurfaceBloc();
      final catalog = A2uiFlutterCatalog.standard();

      bloc
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 'surf-tf-ext',
              'catalogId': minimalCatalogId,
            },
          }),
        )
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateComponents': {
              'surfaceId': 'surf-tf-ext',
              'components': [
                {
                  'id': 'tf-ext',
                  'component': 'TextField',
                  'label': 'Dynamic Name',
                  'value': {'path': '/name'},
                },
              ],
            },
          }),
        )
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateDataModel': {
              'surfaceId': 'surf-tf-ext',
              'path': '/name',
              'value': 'Alice',
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
      final tfFinder = find.byType(TextField);
      expect(tfFinder, findsOneWidget);
      expect(
        tester.widget<TextField>(tfFinder).controller?.text,
        equals('Alice'),
      );

      // Update data model externally
      bloc.add(
        const ProcessJsonMessage({
          'version': 'v0.9',
          'updateDataModel': {
            'surfaceId': 'surf-tf-ext',
            'path': '/name',
            'value': 'Bob',
          },
        }),
      );
      await tester.pump();
      expect(
        tester.widget<TextField>(tfFinder).controller?.text,
        equals('Bob'),
      );

      await bloc.close();
    });

    testWidgets('TextField without explicit path falls back to component ID',
        (tester) async {
      final bloc = A2uiSurfaceBloc();
      final catalog = A2uiFlutterCatalog.standard();

      bloc
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 'surf-tf-fallback',
              'catalogId': minimalCatalogId,
            },
          }),
        )
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateComponents': {
              'surfaceId': 'surf-tf-fallback',
              'components': [
                {
                  'id': 'tf-auto-id',
                  'component': 'TextField',
                  'label': 'Auto Path',
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
      final tfFinder = find.byType(TextField);
      await tester.enterText(tfFinder, 'Fallback Val');
      await tester.pump();

      final ready = bloc.value as SurfaceReady;
      expect(
        ready.surface.dataModel.get('/tf-auto-id'),
        equals('Fallback Val'),
      );

      await bloc.close();
    });

    testWidgets(
      '(Issue #292) covers Button un-normalized Map/String actions and '
      'TextField null value path fallback',
      (tester) async {
        final bloc = A2uiSurfaceBloc()
          ..add(
            ProcessMessages([
              CreateSurfaceMessage(
                version: 'v0.9',
                surfaceId: 'surf-direct-comp',
                catalogId: minimalCatalogId,
              ),
              UpdateComponentsMessage(
                version: 'v0.9',
                surfaceId: 'surf-direct-comp',
                components: const [
                  {'id': 'txt-root', 'component': 'Text', 'text': 'Root'},
                ],
              ),
            ]),
          );
        addTearDown(bloc.close);

        final catalog = A2uiFlutterCatalog.standard();

        final btnMapCtx = A2uiComponentContext(
          component: ComponentModel('btn-map', 'Button', const {
            'action': {'name': 'raw_map_action'},
          }),
          props: const {
            'action': {'name': 'raw_map_action'},
          },
          surfaceBloc: bloc,
          buildChildCallback: (id) => const Text('Raw Map Btn'),
          buildChildrenCallback: (ids) => const [],
          surfaceId: 'surf-direct-comp',
        );

        final btnStrCtx = A2uiComponentContext(
          component: ComponentModel('btn-str', 'Button', const {
            'action': 'raw_string_action',
          }),
          props: const {
            'action': 'raw_string_action',
          },
          surfaceBloc: bloc,
          buildChildCallback: (id) => const Text('Raw Str Btn'),
          buildChildrenCallback: (ids) => const [],
          surfaceId: 'surf-direct-comp',
        );

        final tfNullPathCtx = A2uiComponentContext(
          component: ComponentModel('tf-null-path', 'TextField', const {
            'label': 'Null Path TF',
            'value': {'path': null},
          }),
          props: const {
            'label': 'Null Path TF',
          },
          surfaceBloc: bloc,
          buildChildCallback: (id) => const SizedBox(),
          buildChildrenCallback: (ids) => const [],
          surfaceId: 'surf-direct-comp',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Column(
                  children: [
                    catalog.build(context, btnMapCtx),
                    catalog.build(context, btnStrCtx),
                    catalog.build(context, tfNullPathCtx),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        await tester.enterText(find.byType(TextField), 'NullPathTyped');
        await tester.pump();
        final surface = bloc.processor.model.getSurface('surf-direct-comp')!;
        expect(
          surface.dataModel.get('/tf-null-path'),
          equals('NullPathTyped'),
        );

        await tester.tap(find.byType(ElevatedButton).first);
        await tester.pump();
        expect(
          (bloc.value as SurfaceSubmitting).actionName,
          equals('raw_map_action'),
        );

        bloc.add(const CompleteAction(surfaceId: 'surf-direct-comp'));
        await tester.pump();

        await tester.tap(find.byType(ElevatedButton).last);
        await tester.pump();
        expect(
          (bloc.value as SurfaceSubmitting).actionName,
          equals('raw_string_action'),
        );
      },
    );
  });

  group(
      '(Issue #369) BasicCatalog Standard Flutter Widgets & CheckRule '
      'Validation UI', () {
    const basicV09CatalogId =
        'https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json';

    testWidgets(
      '(Issue #369) Dual-spec layout properties on A2uiRow and A2uiColumn',
      (tester) async {
        final bloc = A2uiSurfaceBloc();
        addTearDown(bloc.close);
        final catalog = A2uiFlutterCatalog.standard();

        final examples = <({
          String component,
          String justify,
          String align,
          MainAxisAlignment expectedMain,
          CrossAxisAlignment expectedCross,
        })>[
          (
            component: 'Row',
            justify: 'start',
            align: 'start',
            expectedMain: MainAxisAlignment.start,
            expectedCross: CrossAxisAlignment.start,
          ),
          (
            component: 'Row',
            justify: 'center',
            align: 'center',
            expectedMain: MainAxisAlignment.center,
            expectedCross: CrossAxisAlignment.center,
          ),
          (
            component: 'Row',
            justify: 'end',
            align: 'end',
            expectedMain: MainAxisAlignment.end,
            expectedCross: CrossAxisAlignment.end,
          ),
          (
            component: 'Row',
            justify: 'spaceBetween',
            align: 'stretch',
            expectedMain: MainAxisAlignment.spaceBetween,
            expectedCross: CrossAxisAlignment.stretch,
          ),
          (
            component: 'Row',
            justify: 'spaceAround',
            align: 'center',
            expectedMain: MainAxisAlignment.spaceAround,
            expectedCross: CrossAxisAlignment.center,
          ),
          (
            component: 'Row',
            justify: 'spaceEvenly',
            align: 'start',
            expectedMain: MainAxisAlignment.spaceEvenly,
            expectedCross: CrossAxisAlignment.start,
          ),
          (
            component: 'Row',
            justify: 'stretch',
            align: 'stretch',
            expectedMain: MainAxisAlignment.start,
            expectedCross: CrossAxisAlignment.stretch,
          ),
          (
            component: 'Column',
            justify: 'start',
            align: 'stretch',
            expectedMain: MainAxisAlignment.start,
            expectedCross: CrossAxisAlignment.stretch,
          ),
          (
            component: 'Column',
            justify: 'center',
            align: 'center',
            expectedMain: MainAxisAlignment.center,
            expectedCross: CrossAxisAlignment.center,
          ),
          (
            component: 'Column',
            justify: 'spaceBetween',
            align: 'start',
            expectedMain: MainAxisAlignment.spaceBetween,
            expectedCross: CrossAxisAlignment.start,
          ),
          (
            component: 'Column',
            justify: 'end',
            align: 'end',
            expectedMain: MainAxisAlignment.end,
            expectedCross: CrossAxisAlignment.end,
          ),
          (
            component: 'Column',
            justify: 'spaceAround',
            align: 'center',
            expectedMain: MainAxisAlignment.spaceAround,
            expectedCross: CrossAxisAlignment.center,
          ),
          (
            component: 'Column',
            justify: 'spaceEvenly',
            align: 'start',
            expectedMain: MainAxisAlignment.spaceEvenly,
            expectedCross: CrossAxisAlignment.start,
          ),
          (
            component: 'Column',
            justify: 'stretch',
            align: 'stretch',
            expectedMain: MainAxisAlignment.start,
            expectedCross: CrossAxisAlignment.stretch,
          ),
        ];

        for (var i = 0; i < examples.length; i++) {
          final row = examples[i];
          final ctx = A2uiComponentContext(
            component: ComponentModel('flex-$i', row.component, {
              'justify': row.justify,
              'align': row.align,
              'children': const <String>[],
            }),
            props: {
              'justify': row.justify,
              'align': row.align,
              'children': const <String>[],
            },
            surfaceBloc: bloc,
            buildChildCallback: (_) => const SizedBox.shrink(),
            buildChildrenCallback: (_) => const <Widget>[],
            surfaceId: 'surf-flex',
          );

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 300,
                  height: 300,
                  child: Builder(
                    builder: (context) => catalog.build(context, ctx),
                  ),
                ),
              ),
            ),
          );

          final flex = row.component == 'Row'
              ? tester.widget<Row>(find.byType(Row))
              : tester.widget<Column>(find.byType(Column));
          expect(
            flex.mainAxisAlignment,
            equals(row.expectedMain),
            reason:
                '${row.component} with justify=${row.justify} should map to '
                '${row.expectedMain}',
          );
          expect(
            flex.crossAxisAlignment,
            equals(row.expectedCross),
            reason: '${row.component} with align=${row.align} should map to '
                '${row.expectedCross}',
          );
        }
      },
    );

    testWidgets(
      '(Issue #369) A2uiText typography variant and style fallback mapping',
      (tester) async {
        final bloc = A2uiSurfaceBloc();
        addTearDown(bloc.close);
        final catalog = A2uiFlutterCatalog.standard();

        final variants = <String>[
          'h1',
          'h2',
          'h3',
          'h4',
          'h5',
          'title',
          'caption',
          'body',
        ];

        for (final v in variants) {
          late TextTheme capturedTheme;
          final ctx = A2uiComponentContext(
            component: ComponentModel('txt-$v', 'Text', {
              'text': 'Hello World',
              'variant': v,
            }),
            props: {
              'text': 'Hello World',
              'variant': v,
            },
            surfaceBloc: bloc,
            buildChildCallback: (_) => const SizedBox.shrink(),
            buildChildrenCallback: (_) => const <Widget>[],
            surfaceId: 'surf-txt',
          );

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) {
                    capturedTheme = Theme.of(context).textTheme;
                    return catalog.build(context, ctx);
                  },
                ),
              ),
            ),
          );

          final textWidget = tester.widget<Text>(find.text('Hello World'));
          final expectedStyle = switch (v) {
            'h1' => capturedTheme.headlineLarge,
            'h2' => capturedTheme.headlineMedium,
            'h3' => capturedTheme.headlineSmall,
            'h4' => capturedTheme.titleLarge,
            'h5' => capturedTheme.titleMedium,
            'title' => capturedTheme.titleMedium,
            'caption' => capturedTheme.bodySmall,
            _ => capturedTheme.bodyMedium,
          };
          expect(textWidget.style, equals(expectedStyle), reason: 'variant=$v');
        }

        // Also verify style fallback when variant is omitted
        late TextTheme fallbackTheme;
        final styleFallbackCtx = A2uiComponentContext(
          component: ComponentModel('txt-style', 'Text', const {
            'text': 'Styled Fallback',
            'style': 'h4',
          }),
          props: const {
            'text': 'Styled Fallback',
            'style': 'h4',
          },
          surfaceBloc: bloc,
          buildChildCallback: (_) => const SizedBox.shrink(),
          buildChildrenCallback: (_) => const <Widget>[],
          surfaceId: 'surf-txt',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  fallbackTheme = Theme.of(context).textTheme;
                  return catalog.build(context, styleFallbackCtx);
                },
              ),
            ),
          ),
        );

        final fallbackText = tester.widget<Text>(find.text('Styled Fallback'));
        expect(fallbackText.style, equals(fallbackTheme.titleLarge));
      },
    );

    testWidgets(
      '(Issue #369) A2uiDivider axis orientation (horizontal, vertical, '
      'omitted)',
      (tester) async {
        final bloc = A2uiSurfaceBloc();
        addTearDown(bloc.close);
        final catalog = A2uiFlutterCatalog.standard();

        for (final axis in <String?>['horizontal', 'vertical', null]) {
          final props = <String, dynamic>{
            if (axis != null) 'axis': axis,
            'thickness': 2.0,
          };
          final ctx = A2uiComponentContext(
            component: ComponentModel('div-$axis', 'Divider', props),
            props: props,
            surfaceBloc: bloc,
            buildChildCallback: (_) => const SizedBox.shrink(),
            buildChildrenCallback: (_) => const <Widget>[],
            surfaceId: 'surf-div',
          );

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  height: 100,
                  width: 100,
                  child: Builder(
                    builder: (context) => catalog.build(context, ctx),
                  ),
                ),
              ),
            ),
          );

          if (axis == 'vertical') {
            expect(find.byType(VerticalDivider), findsOneWidget);
            expect(find.byType(Divider), findsNothing);
          } else {
            expect(find.byType(Divider), findsOneWidget);
            expect(find.byType(VerticalDivider), findsNothing);
          }
        }
      },
    );

    testWidgets(
      '(Issue #369) A2uiTextField variants and CheckRule validation errorText',
      (tester) async {
        final bloc = A2uiSurfaceBloc();
        addTearDown(bloc.close);
        final catalog = A2uiFlutterCatalog.standard();

        final examples = <({
          String variant,
          String? checkError,
          bool obscured,
          TextInputType keyboardType,
          String? expectedError,
        })>[
          (
            variant: 'shortText',
            checkError: null,
            obscured: false,
            keyboardType: TextInputType.text,
            expectedError: null,
          ),
          (
            variant: 'longText',
            checkError: null,
            obscured: false,
            keyboardType: TextInputType.multiline,
            expectedError: null,
          ),
          (
            variant: 'number',
            checkError: 'Must be number',
            obscured: false,
            keyboardType: TextInputType.number,
            expectedError: 'Must be number',
          ),
          (
            variant: 'obscured',
            checkError: 'Too short',
            obscured: true,
            keyboardType: TextInputType.text,
            expectedError: 'Too short',
          ),
        ];

        for (var i = 0; i < examples.length; i++) {
          final ex = examples[i];
          final props = <String, dynamic>{
            'label': 'Field $i',
            'variant': ex.variant,
            if (ex.checkError != null) ...{
              'isValid': false,
              'validationErrors': <String>[ex.checkError!],
              'validationResults': <ValidationResult>[
                ValidationResult(valid: false, message: ex.checkError),
              ],
            },
          };

          final ctx = A2uiComponentContext(
            component: ComponentModel('tf-var-$i', 'TextField', props),
            props: props,
            surfaceBloc: bloc,
            buildChildCallback: (_) => const SizedBox.shrink(),
            buildChildrenCallback: (_) => const <Widget>[],
            surfaceId: 'surf-tf-var',
          );

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => catalog.build(context, ctx),
                ),
              ),
            ),
          );

          final tf = tester.widget<TextField>(find.byType(TextField));
          expect(tf.obscureText, equals(ex.obscured), reason: ex.variant);
          expect(
            tf.keyboardType,
            equals(ex.keyboardType),
            reason: ex.variant,
          );
          expect(
            tf.decoration?.errorText,
            equals(ex.expectedError),
            reason: ex.variant,
          );
        }
      },
    );

    testWidgets(
      '(Issue #369) A2uiButton disabled when CheckRule validation fails or '
      'enabled is false',
      (tester) async {
        final bloc = A2uiSurfaceBloc()
          ..add(
            const ProcessJsonMessage({
              'version': 'v0.9',
              'createSurface': {
                'surfaceId': 'surf-btn-check',
                'catalogId': basicV09CatalogId,
              },
            }),
          )
          ..add(
            const ProcessJsonMessage({
              'version': 'v0.9',
              'updateDataModel': {
                'surfaceId': 'surf-btn-check',
                'path': '/email',
                'value': '',
              },
            }),
          )
          ..add(
            const ProcessJsonMessage({
              'version': 'v0.9',
              'updateComponents': {
                'surfaceId': 'surf-btn-check',
                'components': [
                  {
                    'id': 'btn-submit',
                    'component': 'Button',
                    'child': 'txt-submit',
                    'action': {
                      'event': {'name': 'submit_form'},
                    },
                    'checks': [
                      {
                        'condition': {
                          'call': 'required',
                          'args': {
                            'value': {'path': '/email'},
                          },
                        },
                        'message': 'Email is required',
                      },
                    ],
                  },
                  {
                    'id': 'txt-submit',
                    'component': 'Text',
                    'text': 'Submit',
                  },
                ],
              },
            }),
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

        final elevatedBtn =
            tester.widget<ElevatedButton>(find.byType(ElevatedButton));
        expect(elevatedBtn.onPressed, isNull);

        await tester.tap(find.text('Submit'));
        await tester.pump();
        expect(bloc.value, isA<SurfaceReady>());

        // Once the bound data model satisfies the check rule, the button
        // enables
        bloc.add(
          const UpdateFormField(
            surfaceId: 'surf-btn-check',
            path: '/email',
            value: 'randal@example.com',
          ),
        );
        await tester.pump();

        final enabledBtn =
            tester.widget<ElevatedButton>(find.byType(ElevatedButton));
        expect(enabledBtn.onPressed, isNotNull);

        await tester.tap(find.text('Submit'));
        await tester.pump();
        expect(bloc.value, isA<SurfaceSubmitting>());
      },
    );

    testWidgets(
      '(Issue #369) Two-way interactive input data synchronization for '
      'CheckBox, Slider, ChoicePicker, and DateTimeInput',
      (tester) async {
        final bloc = A2uiSurfaceBloc()
          ..add(
            const ProcessJsonMessage({
              'version': 'v0.9',
              'createSurface': {
                'surfaceId': 'surf-inputs',
                'catalogId': basicV09CatalogId,
              },
            }),
          )
          ..add(
            const ProcessJsonMessage({
              'version': 'v0.9',
              'updateDataModel': {
                'surfaceId': 'surf-inputs',
                'path': '/',
                'value': {
                  'termsAgreed': false,
                  'volume': 25.0,
                  'selectedTag': <String>[],
                  'eventDate': '2026-10-15',
                },
              },
            }),
          )
          ..add(
            const ProcessJsonMessage({
              'version': 'v0.9',
              'updateComponents': {
                'surfaceId': 'surf-inputs',
                'components': [
                  {
                    'id': 'root-col',
                    'component': 'Column',
                    'children': [
                      'cb-terms',
                      'slider-vol',
                      'cp-tags',
                      'dt-event',
                    ],
                  },
                  {
                    'id': 'cb-terms',
                    'component': 'CheckBox',
                    'label': 'Agree to Terms',
                    'value': {'path': '/termsAgreed'},
                  },
                  {
                    'id': 'slider-vol',
                    'component': 'Slider',
                    'label': 'Volume',
                    'min': 0,
                    'max': 100,
                    'value': {'path': '/volume'},
                  },
                  {
                    'id': 'cp-tags',
                    'component': 'ChoicePicker',
                    'label': 'Select Tags',
                    'variant': 'mutuallyExclusive',
                    'displayStyle': 'chips',
                    'options': [
                      {'label': 'Tag One', 'value': 'tag1'},
                      {'label': 'Tag Two', 'value': 'tag2'},
                    ],
                    'value': {'path': '/selectedTag'},
                  },
                  {
                    'id': 'dt-event',
                    'component': 'DateTimeInput',
                    'label': 'Event Date',
                    'enableDate': true,
                    'enableTime': false,
                    'value': {'path': '/eventDate'},
                  },
                ],
              },
            }),
          );
        addTearDown(bloc.close);

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

        final surface = bloc.processor.model.getSurface('surf-inputs')!;

        // 1. CheckBox: false -> true -> false
        await tester.tap(find.byType(CheckboxListTile));
        await tester.pump();
        expect(surface.dataModel.get('/termsAgreed'), isTrue);

        await tester.tap(find.byType(CheckboxListTile));
        await tester.pump();
        expect(surface.dataModel.get('/termsAgreed'), isFalse);

        // 2. Slider: update via onChanged callback to 75.0
        final slider = tester.widget<Slider>(find.byType(Slider));
        slider.onChanged!(75);
        await tester.pump();
        expect(surface.dataModel.get('/volume'), equals(75.0));

        // 3. ChoicePicker: tap 'Tag One' chip -> ['tag1']
        await tester.tap(find.text('Tag One'));
        await tester.pump();
        expect(surface.dataModel.get('/selectedTag'), equals(['tag1']));

        // 4. DateTimeInput: tap to open DatePicker and select day 20
        await tester.tap(find.byType(InputDecorator).last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('20'));
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        expect(surface.dataModel.get('/eventDate'), equals('2026-10-20'));
      },
    );

    testWidgets(
      '(Issue #369) covers all remaining branches in A2uiComponentContext, '
      'Card, CheckBox, ChoicePicker, DateTimeInput, Icon, List, Slider, Tabs, '
      'and TextField',
      (tester) async {
        expect(asBool(true), isTrue);
        expect(asBool('true'), isTrue);
        expect(asBool('FALSE'), isFalse);
        expect(asBool(123, defaultValue: true), isTrue);

        final bloc = A2uiSurfaceBloc()
          ..add(
            ProcessMessages([
              CreateSurfaceMessage(
                version: 'v0.9',
                surfaceId: 'surf-branches',
                catalogId: minimalCatalogId,
              ),
              UpdateComponentsMessage(
                version: 'v0.9',
                surfaceId: 'surf-branches',
                components: const [
                  {'id': 'txt-root', 'component': 'Text', 'text': 'Root'},
                ],
              ),
            ]),
          );
        addTearDown(bloc.close);
        final catalog = A2uiFlutterCatalog.standard();

        // 1. A2uiComponentContext validationResults, isValid fallback, and
        // resolveBoundPath via rawProp Map
        const validationResult = ValidationResult(
          valid: false,
          message: 'Rule failed',
        );
        final ctxWithMapPath = A2uiComponentContext(
          component: ComponentModel('comp-map-path', 'TextField', const {
            'label': 'Map Path TF',
            'value': {'path': '/customMapPath'},
          }),
          props: const {
            'label': 'Map Path TF',
            'errorText': 'Explicit TF Error',
            'validationErrors': <String>['Rule failed'],
            'validationResults': <ValidationResult>[validationResult],
          },
          surfaceBloc: bloc,
          buildChildCallback: (_) => const SizedBox.shrink(),
          buildChildrenCallback: (_) => const <Widget>[],
          surfaceId: 'surf-branches',
        );
        expect(ctxWithMapPath.isValid, isFalse);
        expect(ctxWithMapPath.validationResults, equals([validationResult]));
        expect(
          ctxWithMapPath.resolveBoundPath('value'),
          equals('/customMapPath'),
        );

        final ctxEmptyResults = A2uiComponentContext(
          component: ComponentModel('comp-empty-res', 'Text', const {}),
          props: const {},
          surfaceBloc: bloc,
          buildChildCallback: (_) => const SizedBox.shrink(),
          buildChildrenCallback: (_) => const <Widget>[],
          surfaceId: 'surf-branches',
        );
        expect(ctxEmptyResults.isValid, isTrue);
        expect(ctxEmptyResults.validationResults, isEmpty);

        // 2. Card with children list
        final cardChildrenCtx = A2uiComponentContext(
          component: ComponentModel('card-children', 'Card', const {
            'children': ['c1', 'c2'],
          }),
          props: const {
            'children': ['c1', 'c2'],
          },
          surfaceBloc: bloc,
          buildChildCallback: (id) => Text('Child $id'),
          buildChildrenCallback: (ids) =>
              ids.map((id) => Text('Child $id')).toList(),
          surfaceId: 'surf-branches',
        );

        // 3. CheckBox with CheckRule error subtitle
        final cbErrorCtx = A2uiComponentContext(
          component: ComponentModel('cb-err', 'CheckBox', const {
            'label': 'Terms',
            'value': false,
          }),
          props: const {
            'label': 'Terms',
            'value': false,
            'isValid': false,
            'validationErrors': <String>['Must accept terms'],
          },
          surfaceBloc: bloc,
          buildChildCallback: (_) => const SizedBox.shrink(),
          buildChildrenCallback: (_) => const <Widget>[],
          surfaceId: 'surf-branches',
        );

        // 4. ChoicePicker with multipleSelection, checkbox displayStyle,
        // String value, and CheckRule error
        final cpMultiCheckboxCtx = A2uiComponentContext(
          component: ComponentModel('cp-multi', 'ChoicePicker', const {
            'label': 'Multi Check',
            'variant': 'multipleSelection',
            'displayStyle': 'checkbox',
          }),
          props: const {
            'label': 'Multi Check',
            'variant': 'multipleSelection',
            'displayStyle': 'checkbox',
            'options': [
              {'label': 'Opt A', 'value': 'a'},
              {'label': 'Opt B', 'value': 'b'},
            ],
            'value': 'a',
            'isValid': false,
            'validationErrors': <String>['Select at least two'],
          },
          surfaceBloc: bloc,
          buildChildCallback: (_) => const SizedBox.shrink(),
          buildChildrenCallback: (_) => const <Widget>[],
          surfaceId: 'surf-branches',
        );

        // 5. Slider with CheckRule error
        final sliderErrCtx = A2uiComponentContext(
          component: ComponentModel('slider-err', 'Slider', const {
            'label': 'Speed',
            'min': 0,
            'max': 50,
            'value': 10,
          }),
          props: const {
            'label': 'Speed',
            'min': 0,
            'max': 50,
            'value': 10,
            'isValid': false,
            'validationErrors': <String>['Speed too low'],
          },
          surfaceBloc: bloc,
          buildChildCallback: (_) => const SizedBox.shrink(),
          buildChildrenCallback: (_) => const <Widget>[],
          surfaceId: 'surf-branches',
        );

        // 6. List with horizontal direction and alignments (start, center,
        // end, stretch)
        final listHorizStretchCtx = A2uiComponentContext(
          component: ComponentModel('list-h-stretch', 'List', const {
            'direction': 'horizontal',
            'align': 'stretch',
            'children': ['l1'],
          }),
          props: const {
            'direction': 'horizontal',
            'align': 'stretch',
            'children': ['l1'],
          },
          surfaceBloc: bloc,
          buildChildCallback: Text.new,
          buildChildrenCallback: (ids) => ids.map(Text.new).toList(),
          surfaceId: 'surf-branches',
        );
        final listHorizStartCtx = A2uiComponentContext(
          component: ComponentModel('list-h-start', 'List', const {
            'direction': 'horizontal',
            'align': 'start',
            'children': ['l2'],
          }),
          props: const {
            'direction': 'horizontal',
            'align': 'start',
            'children': ['l2'],
          },
          surfaceBloc: bloc,
          buildChildCallback: Text.new,
          buildChildrenCallback: (ids) => ids.map(Text.new).toList(),
          surfaceId: 'surf-branches',
        );
        final listVertCenterCtx = A2uiComponentContext(
          component: ComponentModel('list-v-center', 'List', const {
            'direction': 'vertical',
            'align': 'center',
            'children': ['l3'],
          }),
          props: const {
            'direction': 'vertical',
            'align': 'center',
            'children': ['l3'],
          },
          surfaceBloc: bloc,
          buildChildCallback: Text.new,
          buildChildrenCallback: (ids) => ids.map(Text.new).toList(),
          surfaceId: 'surf-branches',
        );
        final listVertEndCtx = A2uiComponentContext(
          component: ComponentModel('list-v-end', 'List', const {
            'direction': 'vertical',
            'align': 'end',
            'children': ['l4'],
          }),
          props: const {
            'direction': 'vertical',
            'align': 'end',
            'children': ['l4'],
          },
          surfaceBloc: bloc,
          buildChildCallback: Text.new,
          buildChildrenCallback: (ids) => ids.map(Text.new).toList(),
          surfaceId: 'surf-branches',
        );

        // 7. Icon with Map name (svgPath)
        final iconMapCtx = A2uiComponentContext(
          component: ComponentModel('icon-map', 'Icon', const {
            'name': {'svgPath': 'M0 0'},
            'size': 32,
          }),
          props: const {
            'name': {'svgPath': 'M0 0'},
            'size': 32,
          },
          surfaceBloc: bloc,
          buildChildCallback: (_) => const SizedBox.shrink(),
          buildChildrenCallback: (_) => const <Widget>[],
          surfaceId: 'surf-branches',
        );

        // 8. Image variants (icon, avatar, smallFeature, largeFeature, header)
        // and fits (contain, none, scaleDown)
        final imgVariants = <A2uiComponentContext>[
          for (final (v, f) in const [
            ('icon', 'contain'),
            ('avatar', 'none'),
            ('smallFeature', 'scaleDown'),
            ('largeFeature', 'fill'),
            ('header', 'cover'),
          ])
            A2uiComponentContext(
              component: ComponentModel('img-$v', 'Image', {
                'url': '',
                'variant': v,
                'fit': f,
              }),
              props: {
                'url': '',
                'variant': v,
                'fit': f,
              },
              surfaceBloc: bloc,
              buildChildCallback: (_) => const SizedBox.shrink(),
              buildChildrenCallback: (_) => const <Widget>[],
              surfaceId: 'surf-branches',
            ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Builder(
                  builder: (context) => Column(
                    children: [
                      catalog.build(context, ctxWithMapPath),
                      catalog.build(context, cardChildrenCtx),
                      catalog.build(context, cbErrorCtx),
                      catalog.build(context, cpMultiCheckboxCtx),
                      catalog.build(context, sliderErrCtx),
                      catalog.build(context, listHorizStretchCtx),
                      catalog.build(context, listHorizStartCtx),
                      catalog.build(context, listVertCenterCtx),
                      catalog.build(context, listVertEndCtx),
                      catalog.build(context, iconMapCtx),
                      for (final imgCtx in imgVariants)
                        catalog.build(context, imgCtx),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Explicit TF Error'), findsOneWidget);
        expect(find.text('Child c1'), findsOneWidget);
        expect(find.text('Child c2'), findsOneWidget);
        expect(find.text('Must accept terms'), findsOneWidget);
        expect(find.text('Select at least two'), findsOneWidget);
        expect(find.text('Speed too low'), findsOneWidget);

        // Toggle ChoicePicker checkbox 'Opt B' on (adds 'b' to ['a']) and
        // 'Opt A' off (removes 'a')
        await tester.tap(find.text('Opt B'));
        await tester.pump();
        final surface = bloc.processor.model.getSurface('surf-branches')!;
        expect(surface.dataModel.get('/cp-multi'), equals(['a', 'b']));

        await tester.tap(find.text('Opt A'));
        await tester.pump();
        expect(surface.dataModel.get('/cp-multi'), equals(<String>[]));

        // 9. DateTimeInput with enableDate: true & enableTime: true, and with
        // enableDate: false & enableTime: true, plus CheckRule error
        final dtBothCtx = A2uiComponentContext(
          component: ComponentModel('dt-both', 'DateTimeInput', const {
            'label': 'Date And Time',
            'enableDate': true,
            'enableTime': true,
            'value': '2026-10-15T10:30:00',
          }),
          props: const {
            'label': 'Date And Time',
            'enableDate': true,
            'enableTime': true,
            'value': '2026-10-15T10:30:00',
            'isValid': false,
            'validationErrors': <String>['Invalid date/time'],
          },
          surfaceBloc: bloc,
          buildChildCallback: (_) => const SizedBox.shrink(),
          buildChildrenCallback: (_) => const <Widget>[],
          surfaceId: 'surf-branches',
        );

        final dtTimeOnlyCtx = A2uiComponentContext(
          component: ComponentModel('dt-time-only', 'DateTimeInput', const {
            'label': 'Time Only',
            'enableDate': false,
            'enableTime': true,
            'value': '',
          }),
          props: const {
            'label': 'Time Only',
            'enableDate': false,
            'enableTime': true,
            'value': '',
          },
          surfaceBloc: bloc,
          buildChildCallback: (_) => const SizedBox.shrink(),
          buildChildrenCallback: (_) => const <Widget>[],
          surfaceId: 'surf-branches',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Column(
                  children: [
                    catalog.build(context, dtBothCtx),
                    catalog.build(context, dtTimeOnlyCtx),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Invalid date/time'), findsOneWidget);

        // Tap dtBothCtx -> DatePicker OK -> TimePicker OK
        await tester.tap(find.byType(InputDecorator).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        expect(
          surface.dataModel.get('/dt-both'),
          equals('2026-10-15T10:30:00'),
        );

        // Tap dtTimeOnlyCtx -> TimePicker OK
        await tester.tap(find.byType(InputDecorator).last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        expect(
          surface.dataModel.get('/dt-time-only'),
          equals('12:00:00'),
        );
      },
    );

    testWidgets(
      '(Issue #369) Layout and Display widgets (List, Tabs, Modal, Icon, '
      'Image)',
      (tester) async {
        final bloc = A2uiSurfaceBloc()
          ..add(
            const ProcessJsonMessage({
              'version': 'v0.9',
              'createSurface': {
                'surfaceId': 'surf-display',
                'catalogId': basicV09CatalogId,
              },
            }),
          )
          ..add(
            const ProcessJsonMessage({
              'version': 'v0.9',
              'updateComponents': {
                'surfaceId': 'surf-display',
                'components': [
                  {
                    'id': 'root-list',
                    'component': 'List',
                    'direction': 'vertical',
                    'align': 'stretch',
                    'children': [
                      'tabs-main',
                      'modal-info',
                      'icon-star',
                      'img-banner',
                    ],
                  },
                  {
                    'id': 'tabs-main',
                    'component': 'Tabs',
                    'tabs': [
                      {'title': 'Overview', 'child': 'txt-tab-1'},
                      {'title': 'Details', 'child': 'txt-tab-2'},
                    ],
                  },
                  {
                    'id': 'txt-tab-1',
                    'component': 'Text',
                    'text': 'Overview Content',
                  },
                  {
                    'id': 'txt-tab-2',
                    'component': 'Text',
                    'text': 'Details Content',
                  },
                  {
                    'id': 'modal-info',
                    'component': 'Modal',
                    'trigger': 'txt-open-modal',
                    'content': 'txt-modal-body',
                  },
                  {
                    'id': 'txt-open-modal',
                    'component': 'Text',
                    'text': 'Open Modal Dialog',
                  },
                  {
                    'id': 'txt-modal-body',
                    'component': 'Text',
                    'text': 'Inside Modal Content',
                  },
                  {
                    'id': 'icon-star',
                    'component': 'Icon',
                    'name': 'star',
                  },
                  {
                    'id': 'img-banner',
                    'component': 'Image',
                    'url': 'https://example.invalid/banner.png',
                    'description': 'Banner Image',
                    'fit': 'cover',
                    'variant': 'mediumFeature',
                  },
                ],
              },
            }),
          );
        addTearDown(bloc.close);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: A2uiSurfaceView(bloc: bloc),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // List rendered children
        expect(find.text('Overview Content'), findsOneWidget);
        expect(find.text('Details Content'), findsNothing);

        // Tabs switches between tab titles and child views
        await tester.tap(find.text('Details'));
        await tester.pump();
        expect(find.text('Details Content'), findsOneWidget);
        expect(find.text('Overview Content'), findsNothing);

        // Icon maps 'star' to Icons.star
        expect(find.byIcon(Icons.star), findsOneWidget);

        // Image renders with BoxFit.cover
        expect(find.byType(Image), findsOneWidget);

        // Modal opens dialog containing content child when trigger is tapped
        await tester.tap(find.text('Open Modal Dialog'));
        await tester.pumpAndSettle();
        expect(find.text('Inside Modal Content'), findsOneWidget);
      },
    );
  });
}
