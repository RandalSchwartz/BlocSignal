import 'package:bloc_signals_genui/bloc_signals_genui.dart';
import 'package:bloc_signals_genui_flutter/bloc_signals_genui_flutter.dart';
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
  });
}
