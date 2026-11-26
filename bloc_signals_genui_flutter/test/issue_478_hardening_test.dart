import 'dart:async';

import 'package:bloc_signals_genui/bloc_signals_genui.dart';
import 'package:bloc_signals_genui_flutter/bloc_signals_genui_flutter.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/safe_prop_parser.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/svg_path_parser.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/widgets/cupertino/cupertino_choice_picker.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/widgets/cupertino/cupertino_divider.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/widgets/cupertino/cupertino_icon.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/widgets/cupertino/cupertino_tabs.dart';
import 'package:bloc_signals_genui_flutter/src/catalog/widgets/cupertino/cupertino_text_field.dart';
// Preserves sdk: ^3.5.0 compatibility on Flutter <3.47.
// ignore: deprecated_member_use
import 'package:flutter/cupertino.dart';
// Preserves sdk: ^3.5.0 compatibility on Flutter <3.47.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('(Issue #478) SafePropParser & SvgPathParser Bounds', () {
    test(
      '(Issue #478) asNonNegativeDouble, asBoundedDouble, and asBoundedInt '
      'clamp out-of-range and negative inputs',
      () {
        expect(asNonNegativeDouble(-5, 1), equals(0.0));
        expect(asNonNegativeDouble(double.nan, 2), equals(2.0));
        expect(asBoundedDouble(-10, min: 0, max: 24, defaultValue: 1), 0.0);
        expect(
          asBoundedDouble(999999, min: 1, max: 256, defaultValue: 24),
          256.0,
        );
        expect(asBoundedInt(-5, min: 1, max: 100, defaultValue: 10), 1);
        expect(
          asBoundedInt(500000, min: 1, max: 10000, defaultValue: 10),
          10000,
        );
      },
    );

    test(
      '(Issue #478) SvgPathParser rejects oversized strings, excessive '
      'command counts, and out-of-range coordinates',
      () {
        // Oversized string (> 8192)
        final longPath = 'M 0 0 ${'L 1 1 ' * 2000}';
        expect(SvgPathParser.parse(longPath), isNull);

        // Excessive command count (> 512) within string length limit
        final manyCommands = 'M 0 0 ${'L1 1' * 600}';
        expect(manyCommands.length, lessThanOrEqualTo(8192));
        expect(SvgPathParser.parse(manyCommands), isNull);

        // Out-of-range coordinates across all command families
        expect(SvgPathParser.parse('M 200000 0'), isNull);
        expect(SvgPathParser.parse('M 0 0 L 1000000 0'), isNull);
        expect(SvgPathParser.parse('M 0 0 L -1000000 0'), isNull);
        expect(SvgPathParser.parse('M 0 0 H 200000'), isNull);
        expect(SvgPathParser.parse('M 0 0 V 200000'), isNull);
        expect(SvgPathParser.parse('M 0 0 C 200000 0 1 1 2 2'), isNull);
        expect(SvgPathParser.parse('M 0 0 S 200000 0 2 2'), isNull);
        expect(SvgPathParser.parse('M 0 0 Q 200000 0 2 2'), isNull);
        expect(SvgPathParser.parse('M 0 0 T 200000 0'), isNull);
        expect(SvgPathParser.parse('M 0 0 A 200000 5 0 0 1 10 10'), isNull);
        expect(SvgPathParser.parse('M 0 0 A 5 5 0 0 1 200000 10'), isNull);

        // Command quota exhaustion on trailing Z/z
        final zOverQuota = 'M 0 0 ${'L 1 1 ' * 511}Z';
        expect(SvgPathParser.parse(zOverQuota), isNull);
      },
    );
  });

  group('(Issue #478) Flutter Catalog Prop Bounds & Widget Hardening', () {
    late A2uiSurfaceBloc bloc;

    setUp(() {
      bloc = A2uiSurfaceBloc();
    });

    tearDown(() async {
      await bloc.close();
    });

    A2uiComponentContext makeContext(
      String id,
      String type,
      Map<String, dynamic> props, {
      Widget Function(String)? buildChild,
    }) {
      return A2uiComponentContext(
        component: ComponentModel(id, type, props),
        props: props,
        surfaceBloc: bloc,
        surfaceId: 's1',
        buildChildCallback: buildChild ?? (_) => const SizedBox.shrink(),
        buildChildrenCallback: (ids) => ids
            .map<Widget>(buildChild ?? (_) => const SizedBox.shrink())
            .toList(),
      );
    }

    testWidgets(
      '(Issue #478) Card, Divider, CupertinoDivider, Icon, CupertinoIcon, and '
      'buildWeightedChildren clamp lower and upper bounds',
      (tester) async {
        final catalog = MinimalCatalog();
        final weightedBloc = A2uiSurfaceBloc(catalogs: [catalog]);
        addTearDown(weightedBloc.close);

        weightedBloc
          ..add(
            ProcessJsonMessage({
              'version': 'v0.9',
              'createSurface': {
                'surfaceId': 's_w',
                'catalogId': catalog.id,
              },
            }),
          )
          ..add(
            const ProcessJsonMessage({
              'version': 'v0.9',
              'updateComponents': {
                'surfaceId': 's_w',
                'components': [
                  {'id': 'root', 'component': 'Text', 'text': 'Root'},
                  {
                    'id': 'w1',
                    'component': 'Text',
                    'text': 'Weighted',
                    'weight': 99999,
                  },
                ],
              },
            }),
          );
        await Future<void>.microtask(() {});

        final weightedCtx = A2uiComponentContext(
          component: ComponentModel('row1', 'Row', const {}),
          props: const {},
          surfaceBloc: weightedBloc,
          surfaceId: 's_w',
          buildChildCallback: (_) => const SizedBox.shrink(),
          buildChildrenCallback: (ids) => ids.map(Text.new).toList(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    Builder(
                      builder: (ctx) => buildA2uiCard(
                        ctx,
                        makeContext('c_lo', 'Card', const {'elevation': -50}),
                      ),
                    ),
                    Builder(
                      builder: (ctx) => buildA2uiCard(
                        ctx,
                        makeContext('c_hi', 'Card', const {'elevation': 999}),
                      ),
                    ),
                    Builder(
                      builder: (ctx) => buildA2uiDivider(
                        ctx,
                        makeContext('d1', 'Divider', const {
                          'thickness': -5,
                          'height': -10,
                        }),
                      ),
                    ),
                    Builder(
                      builder: (ctx) => buildA2uiDivider(
                        ctx,
                        makeContext('d1_hi', 'Divider', const {
                          'thickness': 999,
                          'height': 9999,
                        }),
                      ),
                    ),
                    Builder(
                      builder: (ctx) => buildA2uiDivider(
                        ctx,
                        makeContext('d1_v_lo', 'Divider', const {
                          'axis': 'vertical',
                          'thickness': -5,
                          'width': -10,
                        }),
                      ),
                    ),
                    Builder(
                      builder: (ctx) => buildA2uiDivider(
                        ctx,
                        makeContext('d1_v', 'Divider', const {
                          'axis': 'vertical',
                          'thickness': 999,
                          'width': 9999,
                        }),
                      ),
                    ),
                    Builder(
                      builder: (ctx) => buildCupertinoDivider(
                        ctx,
                        makeContext('d2_h', 'Divider', const {
                          'thickness': -5,
                          'height': -10,
                        }),
                      ),
                    ),
                    Builder(
                      builder: (ctx) => buildCupertinoDivider(
                        ctx,
                        makeContext('d2_h_hi', 'Divider', const {
                          'thickness': 999,
                          'height': 9999,
                        }),
                      ),
                    ),
                    Builder(
                      builder: (ctx) => buildCupertinoDivider(
                        ctx,
                        makeContext('d2_v_lo', 'Divider', const {
                          'axis': 'vertical',
                          'thickness': -5,
                          'width': -10,
                        }),
                      ),
                    ),
                    Builder(
                      builder: (ctx) => buildCupertinoDivider(
                        ctx,
                        makeContext('d2_v', 'Divider', const {
                          'axis': 'vertical',
                          'thickness': 999,
                          'width': 9999,
                        }),
                      ),
                    ),
                    Builder(
                      builder: (ctx) => buildA2uiIcon(
                        ctx,
                        makeContext('i1_lo', 'Icon', const {
                          'name': 'star',
                          'size': -10,
                        }),
                      ),
                    ),
                    Builder(
                      builder: (ctx) => buildA2uiIcon(
                        ctx,
                        makeContext('i1_hi', 'Icon', const {
                          'name': 'star',
                          'size': 99999,
                        }),
                      ),
                    ),
                    Builder(
                      builder: (ctx) => buildA2uiIcon(
                        ctx,
                        makeContext('i1_svg', 'Icon', const {
                          'name': {'svgPath': 'M 2 2 L 22 2 L 12 22 Z'},
                          'size': 99999,
                        }),
                      ),
                    ),
                    Builder(
                      builder: (ctx) => buildCupertinoIcon(
                        ctx,
                        makeContext('i2_lo', 'Icon', const {
                          'name': 'star',
                          'size': -10,
                        }),
                      ),
                    ),
                    Builder(
                      builder: (ctx) => buildCupertinoIcon(
                        ctx,
                        makeContext('i2_hi', 'Icon', const {
                          'name': 'star',
                          'size': 99999,
                        }),
                      ),
                    ),
                    Builder(
                      builder: (ctx) => buildCupertinoIcon(
                        ctx,
                        makeContext('i2_svg', 'Icon', const {
                          'name': {'svgPath': 'M 2 2 L 22 2 L 12 22 Z'},
                          'size': -10,
                        }),
                      ),
                    ),
                    Row(
                      children: weightedCtx.buildWeightedChildren(const ['w1']),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        final cards = tester.widgetList<Card>(find.byType(Card)).toList();
        expect(cards[0].elevation, equals(0.0));
        expect(cards[1].elevation, equals(24.0));

        final dividers =
            tester.widgetList<Divider>(find.byType(Divider)).toList();
        expect(dividers, hasLength(2));
        expect(dividers[0].thickness, equals(0.0));
        expect(dividers[0].height, equals(0.0));
        expect(dividers[1].thickness, equals(64.0));
        expect(dividers[1].height, equals(512.0));

        final vDividers = tester
            .widgetList<VerticalDivider>(find.byType(VerticalDivider))
            .toList();
        expect(vDividers, hasLength(2));
        expect(vDividers[0].thickness, equals(0.0));
        expect(vDividers[0].width, equals(0.0));
        expect(vDividers[1].thickness, equals(64.0));
        expect(vDividers[1].width, equals(512.0));

        expect(
          find.byWidgetPredicate(
            (w) => w is SizedBox && w.height == 0.0 && w.width == null,
          ),
          findsNWidgets(2),
        );
        expect(
          find.byWidgetPredicate(
            (w) => w is SizedBox && w.height == 512.0 && w.width == null,
          ),
          findsNWidgets(2),
        );
        expect(
          find.byWidgetPredicate(
            (w) => w is SizedBox && w.width == 0.0 && w.height == null,
          ),
          findsNWidgets(2),
        );
        expect(
          tester.widgetList<SizedBox>(
            find.byWidgetPredicate((w) => w is SizedBox && w.width == 512.0),
          ),
          hasLength(2),
        );

        // CupertinoDivider inner Container thickness clamping (0.0 and 64.0)
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.constraints?.minHeight == 0.0 &&
                w.constraints?.maxHeight == 0.0,
          ),
          findsWidgets,
        );
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.constraints?.minHeight == 64.0 &&
                w.constraints?.maxHeight == 64.0,
          ),
          findsWidgets,
        );
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.constraints?.minWidth == 0.0 &&
                w.constraints?.maxWidth == 0.0,
          ),
          findsWidgets,
        );
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.constraints?.minWidth == 64.0 &&
                w.constraints?.maxWidth == 64.0,
          ),
          findsWidgets,
        );

        final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
        expect(icons, hasLength(4));
        expect(icons[0].size, equals(1.0));
        expect(icons[1].size, equals(256.0));
        expect(icons[2].size, equals(1.0));
        expect(icons[3].size, equals(256.0));

        final svgPaints = tester
            .widgetList<CustomPaint>(
              find.byWidgetPredicate(
                (w) => w is CustomPaint && w.painter is SvgPathPainter,
              ),
            )
            .toList();
        expect(svgPaints, hasLength(2));
        expect(svgPaints[0].size, equals(const Size.square(256)));
        expect(svgPaints[1].size, equals(const Size.square(1)));

        final flexible = tester.widget<Flexible>(find.byType(Flexible));
        expect(flexible.flex, equals(1000));
      },
    );

    testWidgets(
      '(Issue #478) TextField and CupertinoTextField clamp maxLength bounds '
      'to [1, 10000]',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    Builder(
                      builder: (ctx) => buildA2uiTextField(
                        ctx,
                        makeContext('tf1', 'TextField', const {'maxLength': 5}),
                      ),
                    ),
                    Builder(
                      builder: (ctx) => buildA2uiTextField(
                        ctx,
                        makeContext(
                          'tf_lo',
                          'TextField',
                          const {'maxLength': 0},
                        ),
                      ),
                    ),
                    Builder(
                      builder: (ctx) => buildA2uiTextField(
                        ctx,
                        makeContext(
                          'tf_hi',
                          'TextField',
                          const {'maxLength': 99999},
                        ),
                      ),
                    ),
                    Builder(
                      builder: (ctx) => buildCupertinoTextField(
                        ctx,
                        makeContext(
                          'ctf1',
                          'TextField',
                          const {'maxLength': 5},
                        ),
                      ),
                    ),
                    Builder(
                      builder: (ctx) => buildCupertinoTextField(
                        ctx,
                        makeContext(
                          'ctf_lo',
                          'TextField',
                          const {'maxLength': -3},
                        ),
                      ),
                    ),
                    Builder(
                      builder: (ctx) => buildCupertinoTextField(
                        ctx,
                        makeContext(
                          'ctf_hi',
                          'TextField',
                          const {'maxLength': 99999},
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        final tfs =
            tester.widgetList<TextField>(find.byType(TextField)).toList();
        expect(tfs[0].maxLength, equals(5));
        expect(tfs[1].maxLength, equals(1));
        expect(tfs[2].maxLength, equals(10000));

        final ctfs = tester
            .widgetList<CupertinoTextField>(find.byType(CupertinoTextField))
            .toList();
        expect(ctfs[0].maxLength, equals(5));
        expect(ctfs[1].maxLength, equals(1));
        expect(ctfs[2].maxLength, equals(10000));
      },
    );

    testWidgets(
      '(Issue #478) CupertinoChoicePicker falls back cleanly on duplicate '
      'option values and >5 options; CupertinoTabs falls back when <2 tabs',
      (tester) async {
        await tester.pumpWidget(
          CupertinoApp(
            home: CupertinoPageScaffold(
              child: Column(
                children: [
                  Builder(
                    builder: (ctx) => buildCupertinoChoicePicker(
                      ctx,
                      makeContext('cp_dup', 'ChoicePicker', const {
                        'options': [
                          {'label': 'A1', 'value': 'dup'},
                          {'label': 'A2', 'value': 'dup'},
                        ],
                      }),
                    ),
                  ),
                  Builder(
                    builder: (ctx) => buildCupertinoChoicePicker(
                      ctx,
                      makeContext('cp_many', 'ChoicePicker', {
                        'options': [
                          for (var i = 0; i < 6; i++)
                            {'label': 'Opt $i', 'value': 'opt_$i'},
                        ],
                      }),
                    ),
                  ),
                  Builder(
                    builder: (ctx) => buildCupertinoTabs(
                      ctx,
                      makeContext('tabs_one', 'Tabs', const {
                        'tabs': [
                          {'title': 'Only', 'child': 'c1'},
                        ],
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(
          find.byType(CupertinoSlidingSegmentedControl<String>),
          findsNothing,
        );
        expect(
          find.byType(CupertinoSlidingSegmentedControl<int>),
          findsNothing,
        );
      },
    );

    testWidgets(
      '(Issue #478) A2uiModal and CupertinoModal isolate render budget across '
      'opens on A2uiSurfaceView',
      (tester) async {
        Future<void> verifyModalIsolation({
          required A2uiFlutterCatalog catalog,
          required bool isCupertino,
        }) async {
          const basicCatalogId =
              'https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json';
          final surfaceBloc = A2uiSurfaceBloc();
          addTearDown(surfaceBloc.close);

          surfaceBloc
            ..add(
              const ProcessJsonMessage({
                'version': 'v0.9',
                'createSurface': {
                  'surfaceId': 's_modal',
                  'catalogId': basicCatalogId,
                },
              }),
            )
            ..add(
              const ProcessJsonMessage({
                'version': 'v0.9',
                'updateComponents': {
                  'surfaceId': 's_modal',
                  'components': [
                    {
                      'id': 'root',
                      'component': 'Column',
                      'children': ['m1', 'filler'],
                    },
                    {
                      'id': 'm1',
                      'component': 'Modal',
                      'trigger': 'trig',
                      'content': 'modal_col',
                    },
                    {'id': 'trig', 'component': 'Text', 'text': 'Open Modal'},
                    {'id': 'filler', 'component': 'Text', 'text': 'Filler'},
                    {
                      'id': 'modal_col',
                      'component': 'Column',
                      'children': ['mc1', 'mc2', 'mc3'],
                    },
                    {'id': 'mc1', 'component': 'Text', 'text': 'Modal Body 1'},
                    {'id': 'mc2', 'component': 'Text', 'text': 'Modal Body 2'},
                    {'id': 'mc3', 'component': 'Text', 'text': 'Modal Body 3'},
                  ],
                },
              }),
            );
          await Future<void>.microtask(() {});
          expect(surfaceBloc.stateValue, isA<SurfaceReady>());

          // nodeBudget: 6 allows root + m1 + trig + filler (4 nodes) on the
          // parent surface; modal_col + mc1 + mc2 + mc3 (4 nodes) would exceed
          // 6 unless buildIsolatedChild allocates a fresh _RenderBudget.
          final view = A2uiSurfaceView(
            bloc: surfaceBloc,
            surfaceId: 's_modal',
            catalog: catalog,
            nodeBudget: 6,
          );

          await tester.pumpWidget(
            isCupertino
                ? CupertinoApp(home: CupertinoPageScaffold(child: view))
                : MaterialApp(home: Scaffold(body: view)),
          );
          await tester.pump();

          expect(find.text('Open Modal'), findsOneWidget);

          // First open
          await tester.tap(find.text('Open Modal'));
          await tester.pumpAndSettle();
          expect(find.text('Modal Body 1'), findsOneWidget);
          expect(find.text('Modal Body 2'), findsOneWidget);

          // Dismiss and re-open to verify fresh budget on second open
          await tester.tapAt(const Offset(5, 5));
          await tester.pumpAndSettle();
          expect(find.text('Modal Body 1'), findsNothing);

          await tester.tap(find.text('Open Modal'));
          await tester.pumpAndSettle();
          expect(find.text('Modal Body 1'), findsOneWidget);
          expect(find.text('Modal Body 2'), findsOneWidget);
        }

        await verifyModalIsolation(
          catalog: A2uiFlutterCatalog.standard(),
          isCupertino: false,
        );
        await verifyModalIsolation(
          catalog: A2uiFlutterCatalog.cupertino(),
          isCupertino: true,
        );

        // Verify buildIsolatedChild fallback when buildIsolatedChildCallback
        // is null.
        final fallbackCtx = makeContext(
          'm_fallback',
          'Modal',
          const {'trigger': 't1', 'content': 'c1'},
          buildChild: Text.new,
        );
        final fallbackWidget = fallbackCtx.buildIsolatedChild('c1');
        expect(fallbackWidget, isA<Text>());

        // Verify _BoundComponentWidgetState path (surface without 'root')
        const basicCatalogId =
            'https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json';
        final boundBloc = A2uiSurfaceBloc();
        addTearDown(boundBloc.close);
        boundBloc
          ..add(
            const ProcessJsonMessage({
              'version': 'v0.9',
              'createSurface': {
                'surfaceId': 's_bound',
                'catalogId': basicCatalogId,
              },
            }),
          )
          ..add(
            const ProcessJsonMessage({
              'version': 'v0.9',
              'updateComponents': {
                'surfaceId': 's_bound',
                'components': [
                  {
                    'id': 'col_top',
                    'component': 'Column',
                    'children': ['m_b', 'f_b'],
                  },
                  {
                    'id': 'm_b',
                    'component': 'Modal',
                    'trigger': 'trig_b',
                    'content': 'modal_col_b',
                  },
                  {'id': 'trig_b', 'component': 'Text', 'text': 'Open Bound'},
                  {'id': 'f_b', 'component': 'Text', 'text': 'Filler Bound'},
                  {
                    'id': 'modal_col_b',
                    'component': 'Column',
                    'children': ['mb1', 'mb2', 'mb3'],
                  },
                  {'id': 'mb1', 'component': 'Text', 'text': 'Bound Body 1'},
                  {'id': 'mb2', 'component': 'Text', 'text': 'Bound Body 2'},
                  {'id': 'mb3', 'component': 'Text', 'text': 'Bound Body 3'},
                ],
              },
            }),
          );
        await Future<void>.microtask(() {});

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: A2uiSurfaceView(
                bloc: boundBloc,
                surfaceId: 's_bound',
                catalog: A2uiFlutterCatalog.standard(),
                nodeBudget: 6,
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.tap(find.text('Open Bound'));
        await tester.pumpAndSettle();
        expect(find.text('Bound Body 1'), findsOneWidget);
        expect(find.text('Bound Body 3'), findsOneWidget);
      },
    );

    test(
      '(Issue #478) triggerAction catches NodeAction Future Exception '
      'rejections safely and propagates fatal Error subtypes',
      () async {
        final errors = <Object>[];
        await runZonedGuarded(
          () async {
            makeContext('b1', 'Button', {
              'action': ([ActionDispatchOptions? _]) async {
                throw const FormatException('boom');
              },
            }).triggerAction();
            await pumpEventQueue();
          },
          (error, stack) => errors.add(error),
        );
        expect(errors, isEmpty);

        final fatalCompleter = Completer<Object>();
        runZonedGuarded(
          () => makeContext('b2', 'Button', {
            'action': ([ActionDispatchOptions? _]) =>
                Future<void>.error(StateError('fatal')),
          }).triggerAction(),
          (error, _) {
            if (!fatalCompleter.isCompleted) {
              fatalCompleter.complete(error);
            }
          },
        );
        expect(
          await fatalCompleter.future.timeout(const Duration(seconds: 2)),
          isA<StateError>(),
        );
      },
    );
  });
}
