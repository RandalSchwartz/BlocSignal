import 'package:bloc_signals_genui/bloc_signals_genui.dart';
import 'package:bloc_signals_genui_flutter/bloc_signals_genui_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const catalogId =
      'https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json';

  group('(Issue #260: Cupertino Catalog Registry & Tokens)', () {
    test('(Issue #260: Cupertino tokens defaults, copyWith, and equality)', () {
      const tokens = CupertinoCatalogTokens();
      expect(tokens.primaryColor, isNull);
      expect(tokens.cardColor, isNull);
      expect(tokens.barBackgroundColor, isNull);
      expect(tokens.scaffoldBackgroundColor, isNull);
      expect(tokens.borderRadius, isNull);
      expect(tokens.textTheme, isNull);

      const textTheme = CupertinoTextThemeData();
      final custom = tokens.copyWith(
        primaryColor: CupertinoColors.activeGreen,
        cardColor: CupertinoColors.systemGrey6,
        barBackgroundColor: CupertinoColors.systemBackground,
        scaffoldBackgroundColor: CupertinoColors.systemGroupedBackground,
        borderRadius: BorderRadius.circular(16),
        textTheme: textTheme,
      );
      expect(custom.primaryColor, equals(CupertinoColors.activeGreen));
      expect(custom.cardColor, equals(CupertinoColors.systemGrey6));
      expect(
        custom.barBackgroundColor,
        equals(CupertinoColors.systemBackground),
      );
      expect(
        custom.scaffoldBackgroundColor,
        equals(CupertinoColors.systemGroupedBackground),
      );
      expect(custom.borderRadius, equals(BorderRadius.circular(16)));
      expect(custom.textTheme, equals(textTheme));
      expect(tokens == custom, isFalse);
      expect(custom == custom.copyWith(), isTrue);
      expect(custom.hashCode, isNotNull);
      expect(custom.toString(), contains('CupertinoCatalogTokens'));
    });

    test(
        '(Issue #260: A2uiFlutterCatalog.cupertino registers all 16 '
        'components)', () {
      final catalog = A2uiFlutterCatalog.cupertino(
        tokens: const CupertinoCatalogTokens(
          primaryColor: CupertinoColors.activeBlue,
        ),
        theme: const CupertinoThemeData(
          brightness: Brightness.light,
        ),
      );
      const expected = <String>[
        'Text',
        'Row',
        'Column',
        'Button',
        'TextField',
        'Card',
        'Divider',
        'List',
        'Tabs',
        'Modal',
        'Icon',
        'Image',
        'CheckBox',
        'ChoicePicker',
        'Slider',
        'DateTimeInput',
      ];
      for (final type in expected) {
        expect(
          catalog.hasBuilder(type),
          isTrue,
          reason: 'Missing builder for $type',
        );
      }
    });
  });

  group('(Issue #260: Cupertino SurfaceView Interactive Pipeline)', () {
    testWidgets('(Issue #260: Cupertino Button dispatches action to bloc)',
        (tester) async {
      final bloc = A2uiSurfaceBloc();
      final catalog = A2uiFlutterCatalog.cupertino();

      bloc
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 'surf-btn',
              'catalogId': catalogId,
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
                  'id': 'btn-primary',
                  'component': 'Button',
                  'child': 'txt-btn-1',
                  'variant': 'primary',
                  'action': {
                    'event': {
                      'name': 'cupertino_order',
                      'context': {'qty': 2},
                    },
                  },
                },
                {
                  'id': 'txt-btn-1',
                  'component': 'Text',
                  'text': 'Order Now',
                },
              ],
            },
          }),
        );

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: A2uiSurfaceView(
              bloc: bloc,
              catalog: catalog,
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(CupertinoButton), findsOneWidget);
      expect(find.text('Order Now'), findsOneWidget);

      await tester.tap(find.text('Order Now'));
      await tester.pump();

      expect(bloc.value, isA<SurfaceSubmitting>());
      final submitting = bloc.value as SurfaceSubmitting;
      expect(submitting.actionName, equals('cupertino_order'));
      expect(submitting.payload['context'], equals({'qty': 2}));

      await bloc.close();
    });

    testWidgets('(Issue #260: Cupertino Checkbox updates bloc data model)',
        (tester) async {
      final bloc = A2uiSurfaceBloc();
      final catalog = A2uiFlutterCatalog.cupertino();

      bloc
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 'surf-chk',
              'catalogId': catalogId,
            },
          }),
        )
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateDataModel': {
              'surfaceId': 'surf-chk',
              'path': '/',
              'value': {'agree': false},
            },
          }),
        )
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateComponents': {
              'surfaceId': 'surf-chk',
              'components': [
                {
                  'id': 'chk-1',
                  'component': 'CheckBox',
                  'label': 'I agree to the Terms',
                  'value': {'path': '/agree'},
                },
              ],
            },
          }),
        );

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: A2uiSurfaceView(
              bloc: bloc,
              catalog: catalog,
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(CupertinoCheckbox), findsOneWidget);
      expect(find.text('I agree to the Terms'), findsOneWidget);

      await tester.tap(find.byType(CupertinoCheckbox));
      await tester.pump();
      final surface = (bloc.value as SurfaceReady).surface;
      expect(surface.dataModel.get('/agree'), isTrue);

      await bloc.close();
    });

    testWidgets('(Issue #260: Cupertino Slider updates bloc data model)',
        (tester) async {
      final bloc = A2uiSurfaceBloc();
      final catalog = A2uiFlutterCatalog.cupertino();

      bloc
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 'surf-sl',
              'catalogId': catalogId,
            },
          }),
        )
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateDataModel': {
              'surfaceId': 'surf-sl',
              'path': '/',
              'value': {'volume': 50.0},
            },
          }),
        )
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateComponents': {
              'surfaceId': 'surf-sl',
              'components': [
                {
                  'id': 'sl-1',
                  'component': 'Slider',
                  'label': 'Volume',
                  'min': 0,
                  'max': 100,
                  'value': {'path': '/volume'},
                },
              ],
            },
          }),
        );

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: A2uiSurfaceView(
              bloc: bloc,
              catalog: catalog,
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(CupertinoSlider), findsOneWidget);
      expect(find.text('Volume'), findsOneWidget);

      await bloc.close();
    });

    testWidgets(
        '(Issue #260: Cupertino ChoicePicker segmented & multi-selection)',
        (tester) async {
      final bloc = A2uiSurfaceBloc();
      final catalog = A2uiFlutterCatalog.cupertino();

      bloc
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 'surf-picker',
              'catalogId': catalogId,
            },
          }),
        )
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateDataModel': {
              'surfaceId': 'surf-picker',
              'path': '/',
              'value': {
                'plan': 'pro',
                'features': ['analytics'],
              },
            },
          }),
        )
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateComponents': {
              'surfaceId': 'surf-picker',
              'components': [
                {
                  'id': 'root-list',
                  'component': 'List',
                  'children': ['pick-single', 'pick-multi'],
                },
                {
                  'id': 'pick-single',
                  'component': 'ChoicePicker',
                  'label': 'Select Plan',
                  'variant': 'mutuallyExclusive',
                  'value': {'path': '/plan'},
                  'options': [
                    {'label': 'Free', 'value': 'free'},
                    {'label': 'Pro', 'value': 'pro'},
                    {'label': 'Enterprise', 'value': 'enterprise'},
                  ],
                },
                {
                  'id': 'pick-multi',
                  'component': 'ChoicePicker',
                  'label': 'Select Add-ons',
                  'variant': 'multipleSelection',
                  'value': {'path': '/features'},
                  'options': [
                    {'label': 'Analytics', 'value': 'analytics'},
                    {'label': 'Cloud Backup', 'value': 'backup'},
                  ],
                },
              ],
            },
          }),
        );

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: A2uiSurfaceView(
              bloc: bloc,
              catalog: catalog,
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Select Plan'), findsOneWidget);
      expect(find.text('Free'), findsOneWidget);
      expect(find.text('Pro'), findsOneWidget);
      expect(find.text('Analytics'), findsOneWidget);
      expect(find.text('Cloud Backup'), findsOneWidget);

      await tester.tap(find.text('Free'));
      await tester.pump();
      final surface = (bloc.value as SurfaceReady).surface;
      expect(surface.dataModel.get('/plan'), equals(['free']));

      await tester.tap(find.text('Cloud Backup'));
      await tester.pump();
      final feats =
          (surface.dataModel.get('/features')! as List).cast<String>();
      expect(feats, contains('backup'));

      await bloc.close();
    });

    testWidgets('(Issue #260: Cupertino Tabs switches active child)',
        (tester) async {
      final bloc = A2uiSurfaceBloc();
      final catalog = A2uiFlutterCatalog.cupertino();

      bloc
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 'surf-tabs',
              'catalogId': catalogId,
            },
          }),
        )
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateComponents': {
              'surfaceId': 'surf-tabs',
              'components': [
                {
                  'id': 'tab-container',
                  'component': 'Tabs',
                  'tabs': [
                    {'title': 'General', 'child': 'txt-tab-1'},
                    {'title': 'Security', 'child': 'txt-tab-2'},
                  ],
                },
                {
                  'id': 'txt-tab-1',
                  'component': 'Text',
                  'text': 'General Tab Content',
                },
                {
                  'id': 'txt-tab-2',
                  'component': 'Text',
                  'text': 'Security Tab Content',
                },
              ],
            },
          }),
        );

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: A2uiSurfaceView(
              bloc: bloc,
              catalog: catalog,
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('General Tab Content'), findsOneWidget);
      expect(find.text('Security Tab Content'), findsNothing);

      await tester.tap(find.text('Security'));
      await tester.pump();
      expect(find.text('Security Tab Content'), findsOneWidget);

      await bloc.close();
    });

    testWidgets('(Issue #260: Cupertino Modal opens popup surface)',
        (tester) async {
      final bloc = A2uiSurfaceBloc();
      final catalog = A2uiFlutterCatalog.cupertino();

      bloc
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 'surf-modal',
              'catalogId': catalogId,
            },
          }),
        )
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateComponents': {
              'surfaceId': 'surf-modal',
              'components': [
                {
                  'id': 'modal-1',
                  'component': 'Modal',
                  'trigger': 'txt-trigger',
                  'content': 'txt-content',
                },
                {
                  'id': 'txt-trigger',
                  'component': 'Text',
                  'text': 'Open Sheet',
                },
                {
                  'id': 'txt-content',
                  'component': 'Text',
                  'text': 'Sheet Inner Content',
                },
              ],
            },
          }),
        );

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: A2uiSurfaceView(
              bloc: bloc,
              catalog: catalog,
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Open Sheet'), findsOneWidget);
      expect(find.text('Sheet Inner Content'), findsNothing);

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();
      expect(find.text('Sheet Inner Content'), findsOneWidget);

      await bloc.close();
    });

    testWidgets('(Issue #260: Cupertino DateTimeInput opens date picker modal)',
        (tester) async {
      final bloc = A2uiSurfaceBloc();
      final catalog = A2uiFlutterCatalog.cupertino();

      bloc
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 'surf-dt',
              'catalogId': catalogId,
            },
          }),
        )
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateDataModel': {
              'surfaceId': 'surf-dt',
              'path': '/',
              'value': {'eventDate': '2026-10-31'},
            },
          }),
        )
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'updateComponents': {
              'surfaceId': 'surf-dt',
              'components': [
                {
                  'id': 'dt-1',
                  'component': 'DateTimeInput',
                  'label': 'Event Date',
                  'value': {'path': '/eventDate'},
                  'enableDate': true,
                  'enableTime': false,
                },
              ],
            },
          }),
        );

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: A2uiSurfaceView(
              bloc: bloc,
              catalog: catalog,
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Event Date'), findsOneWidget);
      expect(find.text('2026-10-31'), findsOneWidget);

      await tester.tap(find.text('2026-10-31'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoDatePicker), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoDatePicker), findsNothing);

      await bloc.close();
    });
  });

  group('(Issue #260: Cupertino Widget Variants & Coverage Exhaustion)', () {
    testWidgets(
        '(Issue #260: CupertinoButton variants, disabled states, and string '
        'action)', (tester) async {
      final bloc = A2uiSurfaceBloc()
        ..add(
          const ProcessJsonMessage({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 'surf-test',
              'catalogId': catalogId,
            },
          }),
        );
      final catalog = A2uiFlutterCatalog.cupertino();

      final primaryBtnCtx = A2uiComponentContext(
        component: ComponentModel('p-btn', 'Button', const {
          'child': 'c-primary',
          'variant': 'primary',
          'action': 'do_primary',
        }),
        props: const {
          'child': 'c-primary',
          'variant': 'primary',
          'action': 'do_primary',
          'enabled': true,
        },
        surfaceBloc: bloc,
        buildChildCallback: (_) => const Text('Primary Btn'),
        buildChildrenCallback: (_) => const [],
        surfaceId: 'surf-test',
      );

      final borderlessBtnCtx = A2uiComponentContext(
        component: ComponentModel('b-btn', 'Button', const {
          'child': 'c-borderless',
          'variant': 'borderless',
          'action': {
            'name': 'do_borderless',
            'context': {'testKey': 'testVal'},
          },
        }),
        props: const {
          'child': 'c-borderless',
          'variant': 'borderless',
          'action': {
            'name': 'do_borderless',
            'context': {'testKey': 'testVal'},
          },
          'enabled': true,
        },
        surfaceBloc: bloc,
        buildChildCallback: (_) => const Text('Borderless Btn'),
        buildChildrenCallback: (_) => const [],
        surfaceId: 'surf-test',
      );

      final disabledBtnCtx = A2uiComponentContext(
        component: ComponentModel('d-btn', 'Button', const {
          'child': 'c-disabled',
          'enabled': false,
        }),
        props: const {
          'child': 'c-disabled',
          'enabled': false,
          'isValid': false,
        },
        surfaceBloc: bloc,
        buildChildCallback: (_) => const Text('Disabled Btn'),
        buildChildrenCallback: (_) => const [],
        surfaceId: 'surf-test',
      );

      final noChildBtnCtx = A2uiComponentContext(
        component: ComponentModel('nc-btn', 'Button', const {}),
        props: const {'variant': 'primary'},
        surfaceBloc: bloc,
        buildChildCallback: (_) => const SizedBox.shrink(),
        buildChildrenCallback: (_) => const [],
        surfaceId: 'surf-test',
      );

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: Builder(
              builder: (context) => Column(
                children: [
                  catalog.build(context, primaryBtnCtx),
                  catalog.build(context, borderlessBtnCtx),
                  catalog.build(context, disabledBtnCtx),
                  catalog.build(context, noChildBtnCtx),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Primary Btn'), findsOneWidget);
      expect(find.text('Borderless Btn'), findsOneWidget);
      expect(find.text('Disabled Btn'), findsOneWidget);
      expect(find.text('Action'), findsOneWidget);

      final btns = tester
          .widgetList<CupertinoButton>(find.byType(CupertinoButton))
          .toList();
      expect(btns[0].onPressed, isNotNull);
      expect(btns[1].onPressed, isNotNull);
      expect(btns[2].onPressed, isNull);

      await tester.tap(find.text('Borderless Btn'));
      await tester.pump();
      expect(bloc.value, isA<SurfaceSubmitting>());
      final sub = bloc.value as SurfaceSubmitting;
      expect(sub.actionName, equals('do_borderless'));
      expect(sub.payload['context'], equals({'testKey': 'testVal'}));

      await bloc.close();
    });

    testWidgets(
        '(Issue #260: CupertinoTextField variants, controller sync, focus, '
        'and error display)', (tester) async {
      final bloc = A2uiSurfaceBloc();
      final catalog = A2uiFlutterCatalog.cupertino(
        tokens: const CupertinoCatalogTokens(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      );

      final tfCtx = A2uiComponentContext(
        component: ComponentModel('tf-all', 'TextField', const {
          'label': 'Email Address',
          'placeholder': 'Enter your email',
          'helperText': 'We never share your email',
          'errorText': 'Invalid email format',
          'value': {'path': '/email'},
          'variant': 'shortText',
        }),
        props: const {
          'label': 'Email Address',
          'placeholder': 'Enter your email',
          'helperText': 'We never share your email',
          'errorText': 'Invalid email format',
          'value': 'initial@example.com',
          'variant': 'shortText',
        },
        surfaceBloc: bloc,
        buildChildCallback: (_) => const SizedBox.shrink(),
        buildChildrenCallback: (_) => const [],
        surfaceId: 'surf-test',
      );

      final longTextCtx = A2uiComponentContext(
        component: ComponentModel('tf-long', 'TextField', const {
          'variant': 'longText',
        }),
        props: const {
          'variant': 'longText',
          'value': 'Line 1\nLine 2',
        },
        surfaceBloc: bloc,
        buildChildCallback: (_) => const SizedBox.shrink(),
        buildChildrenCallback: (_) => const [],
        surfaceId: 'surf-test',
      );

      final numberCtx = A2uiComponentContext(
        component: ComponentModel('tf-num', 'TextField', const {
          'variant': 'number',
        }),
        props: const {
          'variant': 'number',
          'value': '42',
        },
        surfaceBloc: bloc,
        buildChildCallback: (_) => const SizedBox.shrink(),
        buildChildrenCallback: (_) => const [],
        surfaceId: 'surf-test',
      );

      final obscuredCtx = A2uiComponentContext(
        component: ComponentModel('tf-obs', 'TextField', const {
          'variant': 'obscured',
        }),
        props: const {
          'variant': 'obscured',
          'value': 'secret',
        },
        surfaceBloc: bloc,
        buildChildCallback: (_) => const SizedBox.shrink(),
        buildChildrenCallback: (_) => const [],
        surfaceId: 'surf-test',
      );

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: SingleChildScrollView(
              child: Builder(
                builder: (context) => Column(
                  children: [
                    catalog.build(context, tfCtx),
                    catalog.build(context, longTextCtx),
                    catalog.build(context, numberCtx),
                    catalog.build(context, obscuredCtx),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Enter your email'), findsOneWidget);
      expect(find.text('Invalid email format'), findsOneWidget);
      expect(find.text('Line 1\nLine 2'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);

      await tester.enterText(
        find.byType(CupertinoTextField).first,
        'new@example.com',
      );
      await tester.pump();

      // Test widget didUpdateWidget externally
      final updatedTfCtx = A2uiComponentContext(
        component: tfCtx.component,
        props: const {
          'label': 'Email Address',
          'value': 'updated@example.com',
          'helperText': 'Helper text visible now',
          'variant': 'shortText',
        },
        surfaceBloc: bloc,
        buildChildCallback: (_) => const SizedBox.shrink(),
        buildChildrenCallback: (_) => const [],
        surfaceId: 'surf-test',
      );

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: SingleChildScrollView(
              child: Builder(
                builder: (context) => catalog.build(context, updatedTfCtx),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Helper text visible now'), findsOneWidget);

      await bloc.close();
    });

    testWidgets('(Issue #260: CupertinoCard child vs children vs empty)',
        (tester) async {
      final catalog = A2uiFlutterCatalog.cupertino();

      final singleChildCardCtx = A2uiComponentContext(
        component: ComponentModel('c-single', 'Card', const {'child': 'c1'}),
        props: const {'child': 'c1'},
        surfaceBloc: A2uiSurfaceBloc(),
        buildChildCallback: (_) => const Text('Single Inset Child'),
        buildChildrenCallback: (_) => const [],
        surfaceId: 'surf-test',
      );

      final multiChildrenCardCtx = A2uiComponentContext(
        component: ComponentModel('c-multi', 'Card', const {
          'children': ['c1', 'c2'],
        }),
        props: const {
          'children': ['c1', 'c2'],
        },
        surfaceBloc: A2uiSurfaceBloc(),
        buildChildCallback: (_) => const SizedBox.shrink(),
        buildChildrenCallback: (_) => const [Text('Item A'), Text('Item B')],
        surfaceId: 'surf-test',
      );

      final emptyCardCtx = A2uiComponentContext(
        component: ComponentModel('c-empty', 'Card', const {}),
        props: const {},
        surfaceBloc: A2uiSurfaceBloc(),
        buildChildCallback: (_) => const SizedBox.shrink(),
        buildChildrenCallback: (_) => const [],
        surfaceId: 'surf-test',
      );

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: Builder(
              builder: (context) => Column(
                children: [
                  catalog.build(context, singleChildCardCtx),
                  catalog.build(context, multiChildrenCardCtx),
                  catalog.build(context, emptyCardCtx),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Single Inset Child'), findsOneWidget);
      expect(find.text('Item A'), findsOneWidget);
      expect(find.text('Item B'), findsOneWidget);
    });

    testWidgets(
        '(Issue #260: CupertinoText typography variants and style fallback)',
        (tester) async {
      final catalog = A2uiFlutterCatalog.cupertino();
      const variants = [
        'h1',
        'h2',
        'h3',
        'h4',
        'h5',
        'title',
        'caption',
        'body',
        'customFallback',
      ];

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: Builder(
              builder: (context) => Column(
                children: [
                  for (final v in variants)
                    catalog.build(
                      context,
                      A2uiComponentContext(
                        component: ComponentModel(
                          't-$v',
                          'Text',
                          {'text': 'Text-$v', 'variant': v},
                        ),
                        props: {'text': 'Text-$v', 'variant': v},
                        surfaceBloc: A2uiSurfaceBloc(),
                        buildChildCallback: (_) => const SizedBox.shrink(),
                        buildChildrenCallback: (_) => const [],
                        surfaceId: 'surf-test',
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      for (final v in variants) {
        expect(find.text('Text-$v'), findsOneWidget);
      }
    });

    testWidgets('(Issue #260: CupertinoDivider horizontal and vertical)',
        (tester) async {
      final catalog = A2uiFlutterCatalog.cupertino();

      final horizCtx = A2uiComponentContext(
        component: ComponentModel(
          'd-h',
          'Divider',
          const {'axis': 'horizontal', 'height': 20, 'thickness': 2},
        ),
        props: const {'axis': 'horizontal', 'height': 20, 'thickness': 2},
        surfaceBloc: A2uiSurfaceBloc(),
        buildChildCallback: (_) => const SizedBox.shrink(),
        buildChildrenCallback: (_) => const [],
        surfaceId: 'surf-test',
      );

      final vertCtx = A2uiComponentContext(
        component: ComponentModel(
          'd-v',
          'Divider',
          const {'axis': 'vertical', 'width': 10, 'thickness': 3},
        ),
        props: const {'axis': 'vertical', 'width': 10, 'thickness': 3},
        surfaceBloc: A2uiSurfaceBloc(),
        buildChildCallback: (_) => const SizedBox.shrink(),
        buildChildrenCallback: (_) => const [],
        surfaceId: 'surf-test',
      );

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: Builder(
              builder: (context) => Row(
                children: [
                  catalog.build(context, horizCtx),
                  catalog.build(context, vertCtx),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets(
        '(Issue #260: CupertinoCheckbox with label tap and validation error)',
        (tester) async {
      final bloc = A2uiSurfaceBloc();
      final catalog = A2uiFlutterCatalog.cupertino();

      final cbCtx = A2uiComponentContext(
        component: ComponentModel('cb-err', 'CheckBox', const {
          'label': 'Accept Terms',
          'value': {'path': '/accepted'},
        }),
        props: const {
          'label': 'Accept Terms',
          'value': false,
          'isValid': false,
          'validationErrors': ['Must accept terms'],
        },
        surfaceBloc: bloc,
        buildChildCallback: (_) => const SizedBox.shrink(),
        buildChildrenCallback: (_) => const [],
        surfaceId: 'surf-test',
      );

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: Builder(
              builder: (context) => catalog.build(context, cbCtx),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Accept Terms'), findsOneWidget);
      expect(find.text('Must accept terms'), findsOneWidget);

      await tester.tap(find.text('Accept Terms'));
      await tester.pump();

      await bloc.close();
    });

    testWidgets('(Issue #260: CupertinoSlider validation error and label)',
        (tester) async {
      final bloc = A2uiSurfaceBloc();
      final catalog = A2uiFlutterCatalog.cupertino();

      final slCtx = A2uiComponentContext(
        component: ComponentModel('sl-err', 'Slider', const {
          'label': 'Brightness',
          'min': 0,
          'max': 100,
          'value': 10,
        }),
        props: const {
          'label': 'Brightness',
          'min': 0,
          'max': 100,
          'value': 10,
          'isValid': false,
          'validationErrors': ['Value too low'],
        },
        surfaceBloc: bloc,
        buildChildCallback: (_) => const SizedBox.shrink(),
        buildChildrenCallback: (_) => const [],
        surfaceId: 'surf-test',
      );

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: Builder(
              builder: (context) => catalog.build(context, slCtx),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Brightness'), findsOneWidget);
      expect(find.text('Value too low'), findsOneWidget);

      await bloc.close();
    });

    testWidgets(
        '(Issue #260: CupertinoChoicePicker multi checkbox toggle & validation '
        'error)', (tester) async {
      final bloc = A2uiSurfaceBloc();
      final catalog = A2uiFlutterCatalog.cupertino();

      final cpCtx = A2uiComponentContext(
        component: ComponentModel('cp-err', 'ChoicePicker', const {
          'label': 'Skills',
          'variant': 'multipleSelection',
          'options': [
            {'label': 'Dart', 'value': 'dart'},
            {'label': 'Flutter', 'value': 'flutter'},
          ],
          'value': ['dart'],
        }),
        props: const {
          'label': 'Skills',
          'variant': 'multipleSelection',
          'options': [
            {'label': 'Dart', 'value': 'dart'},
            {'label': 'Flutter', 'value': 'flutter'},
          ],
          'value': ['dart'],
          'isValid': false,
          'validationErrors': ['Select at least two'],
        },
        surfaceBloc: bloc,
        buildChildCallback: (_) => const SizedBox.shrink(),
        buildChildrenCallback: (_) => const [],
        surfaceId: 'surf-test',
      );

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: Builder(
              builder: (context) => catalog.build(context, cpCtx),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Skills'), findsOneWidget);
      expect(find.text('Select at least two'), findsOneWidget);
      expect(find.text('Dart'), findsOneWidget);
      expect(find.text('Flutter'), findsOneWidget);

      await tester.tap(find.text('Flutter'));
      await tester.pump();

      await bloc.close();
    });

    testWidgets('(Issue #260: CupertinoTabs empty tabs fallback)',
        (tester) async {
      final catalog = A2uiFlutterCatalog.cupertino();

      final emptyTabsCtx = A2uiComponentContext(
        component: ComponentModel('t-empty', 'Tabs', const {}),
        props: const {},
        surfaceBloc: A2uiSurfaceBloc(),
        buildChildCallback: (_) => const SizedBox.shrink(),
        buildChildrenCallback: (_) => const [],
        surfaceId: 'surf-test',
      );

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: Builder(
              builder: (context) => catalog.build(context, emptyTabsCtx),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets(
        '(Issue #260: CupertinoModal empty/null trigger and content fallbacks)',
        (tester) async {
      final catalog = A2uiFlutterCatalog.cupertino();

      final noTriggerCtx = A2uiComponentContext(
        component: ComponentModel('m-nt', 'Modal', const {}),
        props: const {},
        surfaceBloc: A2uiSurfaceBloc(),
        buildChildCallback: (_) => const SizedBox.shrink(),
        buildChildrenCallback: (_) => const [],
        surfaceId: 'surf-test',
      );

      final noContentCtx = A2uiComponentContext(
        component: ComponentModel('m-nc', 'Modal', const {'trigger': 't1'}),
        props: const {'trigger': 't1'},
        surfaceBloc: A2uiSurfaceBloc(),
        buildChildCallback: (_) => const Text('Disabled Trigger'),
        buildChildrenCallback: (_) => const [],
        surfaceId: 'surf-test',
      );

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: Builder(
              builder: (context) => Column(
                children: [
                  catalog.build(context, noTriggerCtx),
                  catalog.build(context, noContentCtx),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Disabled Trigger'), findsOneWidget);
      await tester.tap(find.text('Disabled Trigger'));
      await tester.pump();
      expect(find.byType(CupertinoPopupSurface), findsNothing);
    });

    testWidgets(
        '(Issue #260: CupertinoDateTimeInput time-only, both, and validation '
        'error)', (tester) async {
      final bloc = A2uiSurfaceBloc();
      final catalog = A2uiFlutterCatalog.cupertino();

      final dtTimeOnlyCtx = A2uiComponentContext(
        component: ComponentModel('dt-time', 'DateTimeInput', const {
          'label': 'Reminder Time',
          'enableDate': false,
          'enableTime': true,
          'value': '14:30:00',
        }),
        props: const {
          'label': 'Reminder Time',
          'enableDate': false,
          'enableTime': true,
          'value': '14:30:00',
          'isValid': false,
          'validationErrors': ['Must be in the future'],
        },
        surfaceBloc: bloc,
        buildChildCallback: (_) => const SizedBox.shrink(),
        buildChildrenCallback: (_) => const [],
        surfaceId: 'surf-test',
      );

      final dtBothCtx = A2uiComponentContext(
        component: ComponentModel('dt-both', 'DateTimeInput', const {
          'label': 'Appointment',
          'enableDate': true,
          'enableTime': true,
          'value': '2026-10-31T15:00:00',
        }),
        props: const {
          'label': 'Appointment',
          'enableDate': true,
          'enableTime': true,
          'value': '2026-10-31T15:00:00',
        },
        surfaceBloc: bloc,
        buildChildCallback: (_) => const SizedBox.shrink(),
        buildChildrenCallback: (_) => const [],
        surfaceId: 'surf-test',
      );

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: Builder(
              builder: (context) => Column(
                children: [
                  catalog.build(context, dtTimeOnlyCtx),
                  catalog.build(context, dtBothCtx),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Reminder Time'), findsOneWidget);
      expect(find.text('Must be in the future'), findsOneWidget);
      expect(find.text('Appointment'), findsOneWidget);

      await bloc.close();
    });

    testWidgets(
        '(Issue #260: CupertinoIcon mappings, map representation, and '
        'fallback)', (tester) async {
      final catalog = A2uiFlutterCatalog.cupertino();

      final iconMapCtx = A2uiComponentContext(
        component: ComponentModel('ico-map', 'Icon', const {
          'icon': {'name': 'star', 'size': 32, 'description': 'Favorite Star'},
        }),
        props: const {
          'icon': {'name': 'star', 'size': 32, 'description': 'Favorite Star'},
        },
        surfaceBloc: A2uiSurfaceBloc(),
        buildChildCallback: (_) => const SizedBox.shrink(),
        buildChildrenCallback: (_) => const [],
        surfaceId: 'surf-test',
      );

      final iconFallbackCtx = A2uiComponentContext(
        component: ComponentModel(
          'ico-fallback',
          'Icon',
          const {'name': 'nonExistentIcon'},
        ),
        props: const {'name': 'nonExistentIcon'},
        surfaceBloc: A2uiSurfaceBloc(),
        buildChildCallback: (_) => const SizedBox.shrink(),
        buildChildrenCallback: (_) => const [],
        surfaceId: 'surf-test',
      );

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: Builder(
              builder: (context) => Row(
                children: [
                  catalog.build(context, iconMapCtx),
                  catalog.build(context, iconFallbackCtx),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byIcon(CupertinoIcons.star_fill), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.question_circle), findsOneWidget);
    });

    testWidgets(
        '(Issue #260: CupertinoImage sizing variants, fit, and empty fallback)',
        (tester) async {
      final catalog = A2uiFlutterCatalog.cupertino();
      const variants = [
        'icon',
        'avatar',
        'smallFeature',
        'largeFeature',
        'header',
        'mediumFeature',
      ];

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: SingleChildScrollView(
              child: Builder(
                builder: (context) => Column(
                  children: [
                    for (final v in variants)
                      catalog.build(
                        context,
                        A2uiComponentContext(
                          component: ComponentModel(
                            'img-$v',
                            'Image',
                            {'variant': v, 'url': ''},
                          ),
                          props: {'variant': v, 'url': ''},
                          surfaceBloc: A2uiSurfaceBloc(),
                          buildChildCallback: (_) => const SizedBox.shrink(),
                          buildChildrenCallback: (_) => const [],
                          surfaceId: 'surf-test',
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byIcon(CupertinoIcons.photo), findsNWidgets(variants.length));
    });

    testWidgets(
        '(Issue #260: CupertinoList vertical, horizontal, and alignments)',
        (tester) async {
      final catalog = A2uiFlutterCatalog.cupertino();

      final vertCtx = A2uiComponentContext(
        component: ComponentModel('l-v', 'List', const {
          'children': ['c1'],
          'direction': 'vertical',
          'align': 'center',
        }),
        props: const {
          'children': ['c1'],
          'direction': 'vertical',
          'align': 'center',
        },
        surfaceBloc: A2uiSurfaceBloc(),
        buildChildCallback: (_) => const Text('Vert Item'),
        buildChildrenCallback: (_) => const [Text('Vert Item')],
        surfaceId: 'surf-test',
      );

      final horizCtx = A2uiComponentContext(
        component: ComponentModel('l-h', 'List', const {
          'children': ['c2'],
          'direction': 'horizontal',
          'align': 'start',
        }),
        props: const {
          'children': ['c2'],
          'direction': 'horizontal',
          'align': 'start',
        },
        surfaceBloc: A2uiSurfaceBloc(),
        buildChildCallback: (_) => const Text('Horiz Item'),
        buildChildrenCallback: (_) => const [Text('Horiz Item')],
        surfaceId: 'surf-test',
      );

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: Builder(
              builder: (context) => Column(
                children: [
                  catalog.build(context, vertCtx),
                  catalog.build(context, horizCtx),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Vert Item'), findsOneWidget);
      expect(find.text('Horiz Item'), findsOneWidget);
    });

    testWidgets(
        '(Issue #260: CupertinoRow and CupertinoColumn layout alignments)',
        (tester) async {
      final catalog = A2uiFlutterCatalog.cupertino();

      final rowCtx = A2uiComponentContext(
        component: ComponentModel('r-align', 'Row', const {
          'children': ['r1'],
          'justify': 'spaceBetween',
          'align': 'end',
        }),
        props: const {
          'children': ['r1'],
          'justify': 'spaceBetween',
          'align': 'end',
        },
        surfaceBloc: A2uiSurfaceBloc(),
        buildChildCallback: (_) => const Text('Row Child'),
        buildChildrenCallback: (_) => const [Text('Row Child')],
        surfaceId: 'surf-test',
      );

      final colCtx = A2uiComponentContext(
        component: ComponentModel('c-align', 'Column', const {
          'children': ['c1'],
          'justify': 'spaceEvenly',
          'align': 'start',
        }),
        props: const {
          'children': ['c1'],
          'justify': 'spaceEvenly',
          'align': 'start',
        },
        surfaceBloc: A2uiSurfaceBloc(),
        buildChildCallback: (_) => const Text('Col Child'),
        buildChildrenCallback: (_) => const [Text('Col Child')],
        surfaceId: 'surf-test',
      );

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: Builder(
              builder: (context) => Column(
                children: [
                  catalog.build(context, rowCtx),
                  catalog.build(context, colCtx),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Row Child'), findsOneWidget);
      expect(find.text('Col Child'), findsOneWidget);
    });
  });
}
