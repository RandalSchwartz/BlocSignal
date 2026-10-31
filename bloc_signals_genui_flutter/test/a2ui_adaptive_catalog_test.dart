import 'package:bloc_signals_genui/bloc_signals_genui.dart';
import 'package:bloc_signals_genui_flutter/bloc_signals_genui_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const catalogId =
      'https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json';

  group('(Issue #260: Adaptive Catalog & Platform Detection)', () {
    testWidgets(
        '(Issue #260: isCupertinoPlatform detects iOS/macOS and respects platformOverride)',
        (tester) async {
      late BuildContext capturedContext;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.iOS),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                capturedContext = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(isCupertinoPlatform(capturedContext), isTrue);
      expect(
        isCupertinoPlatform(capturedContext, TargetPlatform.android),
        isFalse,
      );

      // In Android theme
      await tester.pumpWidget(
        MaterialApp(
          key: const ValueKey('android-app'),
          theme: ThemeData(platform: TargetPlatform.android),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                capturedContext = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      await tester.pump();
      expect(isCupertinoPlatform(capturedContext), isFalse);
      expect(
        isCupertinoPlatform(capturedContext, TargetPlatform.macOS),
        isTrue,
      );
    });

    testWidgets(
        '(Issue #260: isCupertinoPlatform handles pure CupertinoApp without '
        'Theme BEL-07)', (tester) async {
      late BuildContext capturedContext;

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: Builder(
              builder: (context) {
                capturedContext = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      // Must not throw FlutterError and must fall back to defaultTargetPlatform
      final isCupertino = isCupertinoPlatform(capturedContext);
      final expected = defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS;
      expect(isCupertino, equals(expected));
    });

    testWidgets(
        '(Issue #260: Adaptive catalog switches between Material and '
        'Cupertino)', (tester) async {
      final bloc = A2uiSurfaceBloc();
      final adaptiveCatalog = A2uiFlutterCatalog.adaptive();

      bloc
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 'surf-adaptive',
              'catalogId': catalogId,
            },
          }),
        )
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateComponents': {
              'surfaceId': 'surf-adaptive',
              'components': [
                {
                  'id': 'root-list',
                  'component': 'List',
                  'children': ['btn-1', 'chk-1', 'sl-1'],
                },
                {
                  'id': 'btn-1',
                  'component': 'Button',
                  'child': 'txt-btn',
                  'action': 'submit_action',
                },
                {
                  'id': 'txt-btn',
                  'component': 'Text',
                  'text': 'Adaptive Button',
                },
                {
                  'id': 'chk-1',
                  'component': 'CheckBox',
                  'label': 'Adaptive Check',
                  'value': false,
                },
                {
                  'id': 'sl-1',
                  'component': 'Slider',
                  'min': 0,
                  'max': 100,
                  'value': 25,
                },
              ],
            },
          }),
        );

      // 1. Under iOS platform -> renders Cupertino widgets
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.iOS),
          home: Scaffold(
            body: A2uiSurfaceView(
              bloc: bloc,
              catalog: adaptiveCatalog,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CupertinoButton), findsOneWidget);
      expect(find.byType(CupertinoCheckbox), findsOneWidget);
      expect(find.byType(CupertinoSlider), findsOneWidget);
      expect(find.byType(ElevatedButton), findsNothing);

      // 2. Under Android platform -> renders Material widgets
      await tester.pumpWidget(
        MaterialApp(
          key: const ValueKey('android-app'),
          theme: ThemeData(platform: TargetPlatform.android),
          home: Scaffold(
            body: A2uiSurfaceView(
              bloc: bloc,
              catalog: adaptiveCatalog,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      expect(find.byType(CupertinoButton), findsNothing);

      await bloc.close();
    });

    testWidgets('(Issue #260: Adaptive catalog with explicit platformOverride)',
        (tester) async {
      final bloc = A2uiSurfaceBloc();
      final forcedCupertino = A2uiFlutterCatalog.adaptive(
        platformOverride: TargetPlatform.iOS,
      );

      bloc
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 'surf-override',
              'catalogId': catalogId,
            },
          }),
        )
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateComponents': {
              'surfaceId': 'surf-override',
              'components': [
                {
                  'id': 'root-list',
                  'component': 'List',
                  'children': ['btn-1', 'chk-1', 'sl-1'],
                },
                {
                  'id': 'btn-1',
                  'component': 'Button',
                  'child': 'txt-btn',
                  'action': 'submit_action',
                },
                {
                  'id': 'txt-btn',
                  'component': 'Text',
                  'text': 'Overridden Button',
                },
              ],
            },
          }),
        );

      // Even inside an Android-themed MaterialApp, platformOverride forces
      // Cupertino.
      await tester.pumpWidget(
        MaterialApp(
          key: const ValueKey('android-app'),
          theme: ThemeData(platform: TargetPlatform.android),
          home: Scaffold(
            body: A2uiSurfaceView(
              bloc: bloc,
              catalog: forcedCupertino,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CupertinoButton), findsOneWidget);
      expect(find.byType(ElevatedButton), findsNothing);

      await bloc.close();
    });
  });
}
