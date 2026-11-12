import 'package:bloc_signals_genui/bloc_signals_genui.dart';
import 'package:bloc_signals_genui_flutter/bloc_signals_genui_flutter.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/safe_prop_parser.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/svg_path_parser.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema_builder/json_schema_builder.dart'
    hide ValidationResult;

class _PingFunction extends FunctionImplementation {
  _PingFunction(this.onInvoke)
      : super(
          name: 'ping',
          returnType: A2uiReturnType.string,
          argumentSchema: Schema.object(
            properties: {'msg': Schema.string()},
          ),
        );

  final void Function(Map<String, Object?> args) onInvoke;

  @override
  Object? execute(
    Map<String, Object?> args,
    DataContext context, [
    CancellationSignal? cancellationSignal,
  ]) {
    onInvoke(args);
    return args['msg'];
  }
}

void main() {
  const v1CatalogId =
      'https://a2ui.org/specification/v1_0/catalogs/basic/catalog.json';

  group('(Issue #435) A2UI 1.0 Conformance', () {
    group('Button NodeAction execution & CheckRule gating', () {
      testWidgets(
        'Material Button executes NodeAction when valid and gates when invalid',
        (tester) async {
          final bloc = A2uiSurfaceBloc();
          addTearDown(bloc.close);
          var invoked = 0;

          Future<void> nodeAction([ActionDispatchOptions? options]) async {
            invoked++;
          }

          final validCtx = A2uiComponentContext(
            component: ComponentModel('btn-node', 'Button', const {}),
            props: {
              'child': 'run',
              'action': nodeAction,
              'isValid': true,
            },
            surfaceBloc: bloc,
            surfaceId: 'surf-1',
            buildChildCallback: (_) => const Text('Run'),
            buildChildrenCallback: (_) => const [],
          );

          final invalidCtx = A2uiComponentContext(
            component: ComponentModel('btn-invalid', 'Button', const {}),
            props: {
              'child': 'blocked',
              'action': nodeAction,
              'isValid': false,
            },
            surfaceBloc: bloc,
            surfaceId: 'surf-1',
            buildChildCallback: (_) => const Text('Blocked'),
            buildChildrenCallback: (_) => const [],
          );

          final catalog = A2uiFlutterCatalog.standard();
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    Builder(builder: (ctx) => catalog.build(ctx, validCtx)),
                    Builder(builder: (ctx) => catalog.build(ctx, invalidCtx)),
                  ],
                ),
              ),
            ),
          );

          await tester.tap(find.text('Run'));
          await tester.pump();
          expect(invoked, equals(1));

          await tester.tap(find.text('Blocked'));
          await tester.pump();
          expect(invoked, equals(1));
        },
      );

      testWidgets(
        'Cupertino Button executes NodeAction when valid and gates when '
        'invalid',
        (tester) async {
          final bloc = A2uiSurfaceBloc();
          addTearDown(bloc.close);
          var invoked = 0;

          Future<void> nodeAction([ActionDispatchOptions? options]) async {
            invoked++;
          }

          final validCtx = A2uiComponentContext(
            component: ComponentModel('btn-node', 'Button', const {}),
            props: {
              'child': 'crun',
              'action': nodeAction,
              'isValid': true,
            },
            surfaceBloc: bloc,
            surfaceId: 'surf-1',
            buildChildCallback: (_) => const Text('Cupertino Run'),
            buildChildrenCallback: (_) => const [],
          );

          final invalidCtx = A2uiComponentContext(
            component: ComponentModel('btn-invalid', 'Button', const {}),
            props: {
              'child': 'cblocked',
              'action': nodeAction,
              'isValid': false,
            },
            surfaceBloc: bloc,
            surfaceId: 'surf-1',
            buildChildCallback: (_) => const Text('Cupertino Blocked'),
            buildChildrenCallback: (_) => const [],
          );

          final catalog = A2uiFlutterCatalog.cupertino();
          await tester.pumpWidget(
            CupertinoApp(
              home: CupertinoPageScaffold(
                child: Column(
                  children: [
                    Builder(builder: (ctx) => catalog.build(ctx, validCtx)),
                    Builder(builder: (ctx) => catalog.build(ctx, invalidCtx)),
                  ],
                ),
              ),
            ),
          );

          await tester.tap(find.text('Cupertino Run'));
          await tester.pump();
          expect(invoked, equals(1));

          await tester.tap(find.text('Cupertino Blocked'));
          await tester.pump();
          expect(invoked, equals(1));
        },
      );

      testWidgets(
        'Material Button executes NodeAction for functionCall and dynamic '
        'event.context',
        (tester) async {
          var functionCalled = false;
          final customCatalog = BasicCatalog.v1_0().copyWith(
            functions: [
              _PingFunction((args) {
                if (args['msg'] == 'hi') {
                  functionCalled = true;
                }
              }),
              ...BasicCatalog.v1_0().functions.values,
            ],
          );
          final bloc = A2uiSurfaceBloc(catalogs: [customCatalog]);
          addTearDown(bloc.close);

          bloc
            ..add(
              const ProcessJsonMessage({
                'version': '1.0',
                'createSurface': {
                  'surfaceId': 'surf_fn',
                  'catalogId': v1CatalogId,
                  'components': [
                    {
                      'id': 'root',
                      'component': 'Column',
                      'children': ['btn_fn', 'btn_ev'],
                    },
                    {
                      'id': 'btn_fn',
                      'component': 'Button',
                      'child': 'txt_fn',
                      'action': {
                        'functionCall': {
                          '@call': 'ping',
                          'args': {'msg': 'hi'},
                        },
                      },
                    },
                    {'id': 'txt_fn', 'component': 'Text', 'text': 'Call Fn'},
                    {
                      'id': 'btn_ev',
                      'component': 'Button',
                      'child': 'txt_ev',
                      'action': {
                        'event': {
                          'name': 'greet',
                          'context': {
                            'who': {'@path': '/user/name'},
                          },
                        },
                      },
                    },
                    {'id': 'txt_ev', 'component': 'Text', 'text': 'Send Event'},
                  ],
                },
              }),
            )
            ..add(
              const ProcessJsonMessage({
                'version': '1.0',
                'updateDataModel': {
                  'surfaceId': 'surf_fn',
                  'path': '/user',
                  'value': {'name': 'Randal'},
                },
              }),
            );

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(body: A2uiSurfaceView(bloc: bloc)),
            ),
          );
          await tester.pump();
          expect(bloc.value, isA<SurfaceReady>());

          final surface = bloc.getSurfaceReady('surf_fn')!.surface;
          final receivedActions = <A2uiRendererAction>[];
          final sub = surface.onAction.subscribe(receivedActions.add);
          addTearDown(sub.unsubscribe);

          await tester.tap(find.text('Call Fn'));
          await tester.pump();
          expect(functionCalled, isTrue);
          expect(bloc.value, isA<SurfaceReady>());

          await tester.tap(find.text('Send Event'));
          await tester.pump();
          expect(receivedActions, hasLength(1));
          expect(receivedActions.first.name, equals('greet'));
          expect(receivedActions.first.context['who'], equals('Randal'));
          expect(bloc.value, isA<SurfaceSubmitting>());
        },
      );
    });

    group('Row & Column child weight & stretch alignment', () {
      testWidgets(
        'Material Row and Column wrap positive finite weights in Flexible and '
        'ignore invalid weights',
        (tester) async {
          final bloc = A2uiSurfaceBloc();
          addTearDown(bloc.close);

          bloc.add(
            const ProcessJsonMessage({
              'version': '1.0',
              'createSurface': {
                'surfaceId': 'surf_weight',
                'catalogId': v1CatalogId,
                'components': [
                  {
                    'id': 'root',
                    'component': 'Column',
                    'justify': 'stretch',
                    'align': 'stretch',
                    'children': ['row_1', 'txt_zero', 'txt_neg'],
                  },
                  {
                    'id': 'row_1',
                    'component': 'Row',
                    'justify': 'stretch',
                    'align': 'stretch',
                    'weight': 2,
                    'accessibility': {'label': 'Weighted row'},
                    'children': ['txt_a', 'txt_b'],
                  },
                  {
                    'id': 'txt_a',
                    'component': 'Text',
                    'text': 'A',
                    'weight': 0.2,
                  },
                  {
                    'id': 'txt_b',
                    'component': 'Text',
                    'text': 'B',
                    'weight': 1.6,
                  },
                  {
                    'id': 'txt_zero',
                    'component': 'Text',
                    'text': 'Zero',
                    'weight': 0,
                  },
                  {
                    'id': 'txt_neg',
                    'component': 'Text',
                    'text': 'Neg',
                    'weight': -1,
                  },
                ],
              },
            }),
          );

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(body: A2uiSurfaceView(bloc: bloc)),
            ),
          );
          await tester.pump();
          expect(bloc.value, isA<SurfaceReady>());

          final flexes = tester
              .widgetList<Flexible>(find.byType(Flexible))
              .map((f) => f.flex)
              .toList();
          // row-1 (weight 2 -> 2), txt-a (weight 0.2 -> max(1, 0) = 1),
          // txt-b (weight 1.6 -> 2)
          expect(flexes, containsAll([2, 1, 2]));
          expect(flexes, hasLength(3));
        },
      );

      testWidgets(
        'Cupertino Row and Column ignore NaN/Infinity weights and wrap '
        'positive weights',
        (tester) async {
          final bloc = A2uiSurfaceBloc();
          addTearDown(bloc.close);

          bloc.add(
            const ProcessJsonMessage({
              'version': '1.0',
              'createSurface': {
                'surfaceId': 'surf_cweight',
                'catalogId': v1CatalogId,
                'components': [
                  {
                    'id': 'root',
                    'component': 'Row',
                    'justify': 'stretch',
                    'align': 'stretch',
                    'children': ['col_1', 'txt_nan', 'txt_inf'],
                  },
                  {
                    'id': 'col_1',
                    'component': 'Column',
                    'justify': 'stretch',
                    'align': 'stretch',
                    'weight': 3,
                    'children': ['txt_inner'],
                  },
                  {'id': 'txt_inner', 'component': 'Text', 'text': 'Inner'},
                  {'id': 'txt_nan', 'component': 'Text', 'text': 'NaN'},
                  {'id': 'txt_inf', 'component': 'Text', 'text': 'Inf'},
                ],
              },
            }),
          );

          // Inject NaN and Infinity directly on ComponentModel properties
          final surface = bloc.getSurfaceReady('surf_cweight')!.surface;
          surface.componentsModel.get('txt_nan')!.properties['weight'] =
              double.nan;
          surface.componentsModel.get('txt_inf')!.properties['weight'] =
              double.infinity;

          await tester.pumpWidget(
            CupertinoApp(
              home: CupertinoPageScaffold(
                child: A2uiSurfaceView(
                  bloc: bloc,
                  catalog: A2uiFlutterCatalog.cupertino(),
                ),
              ),
            ),
          );
          await tester.pump();

          final flexes = tester
              .widgetList<Flexible>(find.byType(Flexible))
              .map((f) => f.flex)
              .toList();
          expect(flexes, equals([3]));
        },
      );
    });

    group('Slider steps -> divisions', () {
      testWidgets(
        'Material and Cupertino Sliders map steps >= 1 to divisions and '
        'ignore < 1',
        (tester) async {
          final bloc = A2uiSurfaceBloc();
          addTearDown(bloc.close);

          final ctxValidSteps = A2uiComponentContext(
            component: ComponentModel('s1', 'Slider', const {}),
            props: const {'min': 0, 'max': 10, 'value': 4, 'steps': 5},
            surfaceBloc: bloc,
            surfaceId: 's',
            buildChildCallback: (_) => const SizedBox.shrink(),
            buildChildrenCallback: (_) => const [],
          );
          final ctxInvalidSteps = A2uiComponentContext(
            component: ComponentModel('s2', 'Slider', const {}),
            props: const {'min': 0, 'max': 10, 'value': 4, 'steps': 0},
            surfaceBloc: bloc,
            surfaceId: 's',
            buildChildCallback: (_) => const SizedBox.shrink(),
            buildChildrenCallback: (_) => const [],
          );

          final matCatalog = A2uiFlutterCatalog.standard();
          final cupCatalog = A2uiFlutterCatalog.cupertino();

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    Builder(
                      builder: (ctx) => matCatalog.build(ctx, ctxValidSteps),
                    ),
                    Builder(
                      builder: (ctx) => matCatalog.build(ctx, ctxInvalidSteps),
                    ),
                    Builder(
                      builder: (ctx) => cupCatalog.build(ctx, ctxValidSteps),
                    ),
                    Builder(
                      builder: (ctx) => cupCatalog.build(ctx, ctxInvalidSteps),
                    ),
                  ],
                ),
              ),
            ),
          );

          final matSliders =
              tester.widgetList<Slider>(find.byType(Slider)).toList();
          expect(matSliders[0].divisions, equals(5));
          expect(matSliders[1].divisions, isNull);

          final cupSliders = tester
              .widgetList<CupertinoSlider>(find.byType(CupertinoSlider))
              .toList();
          expect(cupSliders[0].divisions, equals(5));
          expect(cupSliders[1].divisions, isNull);
        },
      );
    });

    group('ChoicePicker filterable search', () {
      testWidgets(
        'Material ChoicePicker filters options case-insensitively by label '
        'or value',
        (tester) async {
          final bloc = A2uiSurfaceBloc();
          addTearDown(bloc.close);

          final ctx = A2uiComponentContext(
            component: ComponentModel('cp-mat', 'ChoicePicker', const {}),
            props: const {
              'label': 'Fruit',
              'filterable': true,
              'options': [
                {'label': 'Red Apple', 'value': 'apple_id'},
                {'label': 'Yellow Banana', 'value': 'banana_id'},
                {'label': 'Green Pear', 'value': 'pear_id'},
              ],
            },
            surfaceBloc: bloc,
            surfaceId: 's',
            buildChildCallback: (_) => const SizedBox.shrink(),
            buildChildrenCallback: (_) => const [],
          );

          final catalog = A2uiFlutterCatalog.standard();
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(builder: (c) => catalog.build(c, ctx)),
              ),
            ),
          );

          expect(find.byType(TextField), findsOneWidget);
          expect(find.text('Red Apple'), findsOneWidget);
          expect(find.text('Yellow Banana'), findsOneWidget);

          // Filter by value substring (case-insensitive)
          await tester.enterText(find.byType(TextField), 'BANANA_ID');
          await tester.pump();
          expect(find.text('Yellow Banana'), findsOneWidget);
          expect(find.text('Red Apple'), findsNothing);
          expect(find.text('Green Pear'), findsNothing);
        },
      );

      testWidgets(
        'Cupertino ChoicePicker filters options and handles <= 1 remaining '
        'option safely',
        (tester) async {
          final bloc = A2uiSurfaceBloc();
          addTearDown(bloc.close);

          final ctx = A2uiComponentContext(
            component: ComponentModel('cp-cup', 'ChoicePicker', const {}),
            props: const {
              'label': 'Fruit',
              'filterable': true,
              'options': [
                {'label': 'Red Apple', 'value': 'apple_id'},
                {'label': 'Yellow Banana', 'value': 'banana_id'},
              ],
            },
            surfaceBloc: bloc,
            surfaceId: 's',
            buildChildCallback: (_) => const SizedBox.shrink(),
            buildChildrenCallback: (_) => const [],
          );

          final catalog = A2uiFlutterCatalog.cupertino();
          await tester.pumpWidget(
            CupertinoApp(
              home: CupertinoPageScaffold(
                child: Builder(builder: (c) => catalog.build(c, ctx)),
              ),
            ),
          );

          expect(find.byType(CupertinoSearchTextField), findsOneWidget);
          await tester.enterText(
            find.byType(CupertinoSearchTextField),
            'apple',
          );
          await tester.pump();
          expect(find.text('Red Apple'), findsOneWidget);
          expect(find.text('Yellow Banana'), findsNothing);
        },
      );
    });

    group('Icon custom svgPath & SvgPathParser', () {
      test('SvgPathParser parses all SVG path commands and rejects malformed',
          () {
        expect(SvgPathParser.parse(''), isNull);
        expect(SvgPathParser.parse('   '), isNull);
        expect(SvgPathParser.parse('not a path'), isNull);
        expect(SvgPathParser.parse('M 10'), isNull);
        expect(SvgPathParser.parse('M 1e 2'), isNull);
        expect(SvgPathParser.parse('M 0 0 L 1'), isNull);
        expect(SvgPathParser.parse('M 0 0 H'), isNull);
        expect(SvgPathParser.parse('M 0 0 V'), isNull);
        expect(SvgPathParser.parse('M 0 0 C 1 2 3 4 5'), isNull);
        expect(SvgPathParser.parse('M 0 0 S 1 2 3'), isNull);
        expect(SvgPathParser.parse('M 0 0 Q 1 2 3'), isNull);
        expect(SvgPathParser.parse('M 0 0 T 1'), isNull);
        expect(SvgPathParser.parse('M 0 0 A 1 2 0 0 1 5'), isNull);
        expect(SvgPathParser.parse('M 0 0 X 1 2'), isNull);

        const sci = 'M 1e0 2E+0 L 1.5e1 2.0e-1 Z';
        expect(SvgPathParser.parse(sci), isNotNull);

        const complex = 'M 2 2 L 10 2 l 2 2 H 18 h 2 V 10 v 2 '
            'C 20 14 18 16 16 16 c -1 0 -2 1 -2 2 '
            'S 10 20 8 20 s -2 -1 -2 -2 '
            'Q 4 18 4 14 q 0 -2 -2 -2 '
            'T 2 8 t 0 -2 '
            'A 2 2 0 014 4 a 1 1 0 1 0 2 2 Z z';
        final path = SvgPathParser.parse(complex);
        expect(path, isNotNull);
        expect(path!.getBounds().isEmpty, isFalse);

        final painter1 = SvgPathPainter(path: path, color: Colors.black);
        final painter2 = SvgPathPainter(path: path, color: Colors.red);
        expect(painter1.shouldRepaint(painter1), isFalse);
        expect(painter1.shouldRepaint(painter2), isTrue);
      });

      testWidgets(
        'Material and Cupertino Icon render CustomPaint for valid svgPath and '
        'fallback on invalid',
        (tester) async {
          final bloc = A2uiSurfaceBloc();
          addTearDown(bloc.close);

          final validCtx = A2uiComponentContext(
            component: ComponentModel('i1', 'Icon', const {}),
            props: const {
              'name': {'svgPath': 'M 2 2 L 22 2 L 12 22 Z'},
              'size': 32,
              'description': 'Triangle',
            },
            surfaceBloc: bloc,
            surfaceId: 's',
            buildChildCallback: (_) => const SizedBox.shrink(),
            buildChildrenCallback: (_) => const [],
          );

          final invalidCtx = A2uiComponentContext(
            component: ComponentModel('i2', 'Icon', const {}),
            props: const {
              'name': {'svgPath': 'bad-svg'},
            },
            surfaceBloc: bloc,
            surfaceId: 's',
            buildChildCallback: (_) => const SizedBox.shrink(),
            buildChildrenCallback: (_) => const [],
          );

          final mapNameCtx = A2uiComponentContext(
            component: ComponentModel('i3', 'Icon', const {}),
            props: const {
              'name': {'name': 'star'},
            },
            surfaceBloc: bloc,
            surfaceId: 's',
            buildChildCallback: (_) => const SizedBox.shrink(),
            buildChildrenCallback: (_) => const [],
          );

          final matCatalog = A2uiFlutterCatalog.standard();
          final cupCatalog = A2uiFlutterCatalog.cupertino();

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Column(
                  children: [
                    Builder(builder: (c) => matCatalog.build(c, validCtx)),
                    Builder(builder: (c) => matCatalog.build(c, invalidCtx)),
                    Builder(builder: (c) => matCatalog.build(c, mapNameCtx)),
                    Builder(builder: (c) => cupCatalog.build(c, validCtx)),
                    Builder(builder: (c) => cupCatalog.build(c, invalidCtx)),
                    Builder(builder: (c) => cupCatalog.build(c, mapNameCtx)),
                  ],
                ),
              ),
            ),
          );

          expect(find.byType(CustomPaint), findsAtLeastNWidgets(2));
          expect(find.byIcon(Icons.help_outline), findsOneWidget);
          expect(find.byIcon(CupertinoIcons.question_circle), findsOneWidget);
          expect(find.byIcon(Icons.star), findsOneWidget);
          expect(find.byIcon(CupertinoIcons.star_fill), findsOneWidget);
        },
      );
    });

    group('accessibility envelope, metadata, and asBool parity', () {
      testWidgets(
        'A2uiSurfaceView honors accessibility.hidden and wraps label/description in Semantics',
        (tester) async {
          final bloc = A2uiSurfaceBloc();
          addTearDown(bloc.close);

          bloc.add(
            const ProcessJsonMessage({
              'version': '1.0',
              'createSurface': {
                'surfaceId': 'surf_a11y',
                'catalogId': v1CatalogId,
                'components': [
                  {
                    'id': 'root',
                    'component': 'Column',
                    'children': ['txt_hidden', 'txt_sem'],
                  },
                  {
                    'id': 'txt_hidden',
                    'component': 'Text',
                    'text': 'Secret',
                    'accessibility': {'hidden': true},
                  },
                  {
                    'id': 'txt_sem',
                    'component': 'Text',
                    'text': 'Visible',
                    'accessibility': {
                      'label': 'Status Label',
                      'description': 'Shows current status',
                    },
                  },
                ],
              },
            }),
          );

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(body: A2uiSurfaceView(bloc: bloc)),
            ),
          );
          await tester.pump();
          expect(bloc.value, isA<SurfaceReady>());

          expect(find.text('Secret'), findsNothing);
          expect(find.text('Visible'), findsOneWidget);
          final semantics = tester.getSemantics(find.text('Visible'));
          expect(semantics.label, contains('Status Label'));
          expect(semantics.hint, contains('Shows current status'));
        },
      );

      test('A2uiComponentContext.metadata exposes component metadata', () {
        final bloc = A2uiSurfaceBloc();
        addTearDown(bloc.close);
        final component = ComponentModel(
          'c1',
          'Text',
          const {'text': 'hi'},
          metadata: const {
            'extensions': {'origin': 'agent'},
          },
        );
        final ctx = A2uiComponentContext(
          component: component,
          props: const {'text': 'hi'},
          surfaceBloc: bloc,
          surfaceId: 's',
          buildChildCallback: (_) => const SizedBox.shrink(),
          buildChildrenCallback: (_) => const [],
        );
        expect(
          ctx.metadata,
          equals({
            'extensions': {'origin': 'agent'},
          }),
        );
      });

      test('asBool aligns with coerceDynamicBoolean semantics', () {
        expect(asBool(null, defaultValue: true), isTrue);
        expect(asBool(true), isTrue);
        expect(asBool(false), isFalse);
        expect(asBool(const ValidationResult(valid: true)), isTrue);
        expect(
          asBool(const ValidationResult(valid: false, message: 'err')),
          isFalse,
        );
        expect(asBool({'valid': true}), isTrue);
        expect(asBool({'valid': false}), isFalse);
        expect(asBool('TRUE'), isTrue);
        expect(asBool('false'), isFalse);
        expect(asBool(1), isTrue);
        expect(asBool(0), isFalse);
        expect(asBool(double.nan), isFalse);
        expect(asBool(double.infinity), isTrue);
      });
    });
  });
}
