import 'dart:async';

import 'package:bloc_signals_genui/bloc_signals_genui.dart';
import 'package:bloc_signals_genui_jaspr/bloc_signals_genui_jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_test/jaspr_test.dart';

void main() {
  group('(Issue #478) Jaspr SafePropParser & Component Hardening', () {
    test(
      '(Issue #478) asNonNegativeDouble, asBoundedDouble, and asBoundedInt '
      'clamp out-of-range and negative inputs',
      () {
        expect(asNonNegativeDouble(-5, 1), equals(0.0));
        expect(asNonNegativeDouble(5.5, 1), equals(5.5));
        expect(asNonNegativeDouble('bad', -2), equals(0.0));
        expect(asNonNegativeDouble('bad', double.nan), equals(0.0));
        expect(asNonNegativeDouble(double.infinity, 3), equals(3.0));
        expect(asBoundedDouble(-10, min: 0, max: 24, defaultValue: 1), 0.0);
        expect(
          asBoundedDouble(double.nan, min: 1, max: 10, defaultValue: 5),
          5.0,
        );
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

    testComponents(
      '(Issue #478) TextField enforces clamped maxlength on input and '
      'textarea, and ChoicePicker scopes radio name',
      (tester) async {
        final bloc = A2uiSurfaceBloc();
        addTearDown(bloc.close);

        A2uiComponentContext makeCtx(
          String id,
          String type,
          Map<String, dynamic> props, {
          String surfaceId = 'surf_a',
          String dataPath = '/',
          String? siblingDisambiguator,
        }) {
          return A2uiComponentContext(
            component: ComponentModel(id, type, props),
            props: props,
            surfaceBloc: bloc,
            surfaceId: surfaceId,
            dataPath: dataPath,
            siblingDisambiguator: siblingDisambiguator,
            buildChildCallback: (_) => const div([]),
            buildChildrenCallback: (_) => const [],
          );
        }

        tester.pumpComponent(
          Builder(
            builder: (context) {
              return div([
                buildA2uiTextField(
                  context,
                  makeCtx('tf_in_range', 'TextField', const {
                    'maxLength': 12,
                  }),
                ),
                buildA2uiTextField(
                  context,
                  makeCtx('tf_low', 'TextField', const {
                    'maxLength': -5,
                  }),
                ),
                buildA2uiTextField(
                  context,
                  makeCtx('tf_high_long', 'TextField', const {
                    'variant': 'longText',
                    'maxLength': 999999,
                  }),
                ),
                buildA2uiChoicePicker(
                  context,
                  makeCtx(
                    'cp1',
                    'ChoicePicker',
                    const {
                      'options': [
                        {'label': 'One', 'value': '1'},
                        {'label': 'Two', 'value': '2'},
                      ],
                    },
                    surfaceId: 'surf_1',
                    dataPath: '/items/0',
                    siblingDisambiguator: '1',
                  ),
                ),
              ]);
            },
          ),
        );

        final textInputs = find
            .byComponentPredicate(
              (c) => c is input<String>,
            )
            .evaluate()
            .map((e) => e.component as input<String>)
            .toList();
        expect(textInputs, hasLength(2));
        expect(textInputs[0].attributes?['maxlength'], equals('12'));
        expect(textInputs[1].attributes?['maxlength'], equals('1'));

        final textareas = find
            .byComponentPredicate(
              (c) => c is textarea,
            )
            .evaluate()
            .map((e) => e.component as textarea)
            .toList();
        expect(textareas, hasLength(1));
        expect(textareas.single.attributes?['maxlength'], equals('10000'));

        final radios = find
            .byComponentPredicate(
              (c) => c is input<bool>,
            )
            .evaluate()
            .map((e) => e.component as input<bool>)
            .toList();
        expect(radios, hasLength(2));
        for (final radio in radios) {
          expect(
            radio.name,
            equals('a2ui_choice_surf_1_/items/0_cp1_1'),
          );
        }
      },
    );

    testComponents(
      '(Issue #478) Card, Divider, Icon, and buildWeightedChildren clamp '
      'numeric props and validate SVG path grammar, length, commands, and '
      'coords',
      (tester) async {
        final bloc = A2uiSurfaceBloc(catalogs: [MinimalCatalog()]);
        addTearDown(bloc.close);

        bloc
          ..add(
            ProcessJsonMessage({
              'version': 'v0.9',
              'createSurface': {
                'surfaceId': 's_props',
                'catalogId': MinimalCatalog().id,
              },
            }),
          )
          ..add(
            const ProcessJsonMessage({
              'version': 'v0.9',
              'updateComponents': {
                'surfaceId': 's_props',
                'components': [
                  {'id': 'root', 'component': 'Text', 'text': 'Parent'},
                  {
                    'id': 'weighted_child',
                    'component': 'Text',
                    'text': 'Weighted',
                    'weight': 99999,
                  },
                ],
              },
            }),
          );
        await Future<void>.microtask(() {});

        A2uiComponentContext makeCtx(
          String id,
          String type,
          Map<String, dynamic> props,
        ) {
          return A2uiComponentContext(
            component: ComponentModel(id, type, props),
            props: props,
            surfaceBloc: bloc,
            surfaceId: 's_props',
            buildChildCallback: (_) => const div([]),
            buildChildrenCallback: (ids) =>
                ids.map((id) => div([Component.text(id)])).toList(),
          );
        }

        final longValid = 'M 0 0 ${'L 1 1 ' * 2000}';
        final manyImplicit = 'M 0 0 ${'1 1 ' * 600}';

        tester.pumpComponent(
          Builder(
            builder: (context) {
              final weighted = makeCtx('row1', 'Row', const {})
                  .buildWeightedChildren(const ['weighted_child']);
              return div([
                buildA2uiCard(
                  context,
                  makeCtx('c_neg', 'Card', const {'elevation': -10}),
                ),
                buildA2uiCard(
                  context,
                  makeCtx('c_hi', 'Card', const {'elevation': 999}),
                ),
                buildA2uiDivider(
                  context,
                  makeCtx('d_h', 'Divider', const {
                    'thickness': -5,
                    'height': 9999,
                  }),
                ),
                buildA2uiDivider(
                  context,
                  makeCtx('d_v', 'Divider', const {
                    'axis': 'vertical',
                    'thickness': 999,
                    'width': 9999,
                  }),
                ),
                buildA2uiDivider(
                  context,
                  makeCtx('d_v_lo', 'Divider', const {
                    'axis': 'vertical',
                    'thickness': -5,
                    'height': -10,
                  }),
                ),
                // Valid SVG path -> renders <svg>
                buildA2uiIcon(
                  context,
                  makeCtx('i_ok', 'Icon', const {
                    'name': {'svgPath': 'M 2 2 L 22 2 L 12 22 Z'},
                    'size': 9999,
                  }),
                ),
                buildA2uiIcon(
                  context,
                  makeCtx('i_glyph_lo', 'Icon', const {
                    'name': 'star',
                    'size': -5,
                  }),
                ),
                buildA2uiIcon(
                  context,
                  makeCtx('i_glyph_hi', 'Icon', const {
                    'name': 'star',
                    'size': 9999,
                  }),
                ),
                // Invalid SVG paths -> must all fall back to glyph '?'
                buildA2uiIcon(
                  context,
                  makeCtx('i_script', 'Icon', const {
                    'name': {'svgPath': 'M 0 0 <script>alert(1)</script>'},
                    'size': -5,
                  }),
                ),
                buildA2uiIcon(
                  context,
                  makeCtx('i_long', 'Icon', {
                    'name': {'svgPath': longValid},
                  }),
                ),
                buildA2uiIcon(
                  context,
                  makeCtx('i_implicit', 'Icon', {
                    'name': {'svgPath': manyImplicit},
                  }),
                ),
                buildA2uiIcon(
                  context,
                  makeCtx('i_coord', 'Icon', const {
                    'name': {'svgPath': 'M 0 0 L 1000000 0'},
                  }),
                ),
                buildA2uiIcon(
                  context,
                  makeCtx('i_bad1', 'Icon', const {
                    'name': {'svgPath': 'M 0 0 eeee'},
                  }),
                ),
                buildA2uiIcon(
                  context,
                  makeCtx('i_bad2', 'Icon', const {
                    'name': {'svgPath': 'M 0 0 L'},
                  }),
                ),
                buildA2uiIcon(
                  context,
                  makeCtx('i_bad3', 'Icon', const {
                    'name': {'svgPath': 'M --- +++'},
                  }),
                ),
                ...weighted,
              ]);
            },
          ),
        );

        // Only the 1 valid SVG icon renders <svg>; the 7 invalid ones fall back
        // to '?'
        final svgs = find
            .byComponentPredicate((c) => c is svg)
            .evaluate()
            .map((e) => e.component as svg)
            .toList();
        expect(svgs, hasLength(1));
        expect(svgs.single.width?.value, equals('256px'));
        expect(svgs.single.height?.value, equals('256px'));
        expect(find.text('?'), findsNComponents(7));

        // Glyph icons clamp font-size to [1, 256]
        final glyphIcons = find
            .byComponentPredicate(
              (c) =>
                  c is span &&
                  c.classes == 'a2ui-icon' &&
                  c.attributes?['data-icon'] == 'star',
            )
            .evaluate()
            .map((e) => e.component as span)
            .toList();
        expect(glyphIcons, hasLength(2));
        expect(glyphIcons[0].styles?.properties['font-size'], equals('1px'));
        expect(glyphIcons[1].styles?.properties['font-size'], equals('256px'));

        // Cards: elevation clamped to [0, 24]
        final cards = find
            .byComponentPredicate(
              (c) => c is div && c.classes == 'a2ui-card',
            )
            .evaluate()
            .map((e) => e.component as div)
            .toList();
        expect(cards, hasLength(2));
        expect(cards[0].styles?.properties['box-shadow'], contains('0px 0px'));
        expect(
          cards[1].styles?.properties['box-shadow'],
          contains('24px 48px'),
        );

        // Dividers: exact clamped CSS thickness and height/width bounds
        final hDiv = find
            .byComponentPredicate(
              (c) => c is hr && (c.classes?.contains('a2ui-divider') ?? false),
            )
            .evaluate()
            .single
            .component as hr;
        expect(hDiv.styles?.properties['border-top-width'], equals('0px'));
        expect(hDiv.styles?.properties['margin-top'], equals('256px'));

        final vDivs = find
            .byComponentPredicate(
              (c) =>
                  c is div &&
                  (c.classes?.contains('a2ui-divider-vertical') ?? false),
            )
            .evaluate()
            .map((e) => e.component as div)
            .toList();
        expect(vDivs, hasLength(2));
        expect(vDivs[0].styles?.properties['width'], equals('64px'));
        expect(vDivs[0].styles?.properties['height'], equals('512px'));
        expect(vDivs[1].styles?.properties['width'], equals('0px'));
        expect(vDivs[1].styles?.properties['height'], equals('0px'));

        // Weighted child: flex-grow clamped to <= 1000.0
        final weightedDivs = find
            .byComponentPredicate(
              (c) => c is div && c.classes == 'a2ui-weighted-child',
            )
            .evaluate()
            .map((e) => e.component as div)
            .toList();
        expect(weightedDivs, hasLength(1));
        expect(
          weightedDivs.single.styles?.properties['flex-grow'],
          equals('1000'),
        );
      },
    );

    test(
      '(Issue #478) triggerAction catches NodeAction Future Exception '
      'rejections safely',
      () async {
        final bloc = A2uiSurfaceBloc();
        addTearDown(bloc.close);

        final errors = <Object>[];
        await runZonedGuarded(
          () async {
            A2uiComponentContext(
              component: ComponentModel('b1', 'Button', const {}),
              props: {
                'action': ([ActionDispatchOptions? _]) async {
                  throw const FormatException('boom');
                },
              },
              surfaceBloc: bloc,
              surfaceId: 's1',
              buildChildCallback: (_) => const div([]),
              buildChildrenCallback: (_) => const [],
            ).triggerAction();
            await pumpEventQueue();
          },
          (error, _) => errors.add(error),
        );
        expect(errors, isEmpty);

        final fatalCompleter = Completer<Object>();
        runZonedGuarded(
          () => A2uiComponentContext(
            component: ComponentModel('b2', 'Button', const {}),
            props: {
              'action': ([ActionDispatchOptions? _]) =>
                  Future<void>.error(StateError('fatal')),
            },
            surfaceBloc: bloc,
            surfaceId: 's1',
            buildChildCallback: (_) => const div([]),
            buildChildrenCallback: (_) => const [],
          ).triggerAction(),
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

    testComponents(
      '(Issue #478) A2uiSurfaceView propagates siblingDisambiguator through '
      'nested duplicate containers wrapping duplicate ChoicePickers on both '
      'NodeResolver and BoundComponent paths',
      (tester) async {
        const basicCatalogId =
            'https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json';

        Future<void> verifyNestedDuplicates({required bool useRoot}) async {
          final bloc = A2uiSurfaceBloc();
          addTearDown(bloc.close);

          final rootId = useRoot ? 'root' : 'col_top';
          final surfaceId = useRoot ? 's_dup_node' : 's_dup_bound';
          bloc
            ..add(
              ProcessJsonMessage({
                'version': 'v0.9',
                'createSurface': {
                  'surfaceId': surfaceId,
                  'catalogId': basicCatalogId,
                },
              }),
            )
            ..add(
              ProcessJsonMessage({
                'version': 'v0.9',
                'updateComponents': {
                  'surfaceId': surfaceId,
                  'components': [
                    {
                      'id': rootId,
                      'component': 'Column',
                      'children': const ['card1', 'card1'],
                    },
                    const {
                      'id': 'card1',
                      'component': 'Card',
                      'child': 'inner_col',
                    },
                    const {
                      'id': 'inner_col',
                      'component': 'Column',
                      'children': ['cp', 'cp'],
                    },
                    const {
                      'id': 'cp',
                      'component': 'ChoicePicker',
                      'value': ['a'],
                      'options': [
                        {'label': 'Opt A', 'value': 'a'},
                        {'label': 'Opt B', 'value': 'b'},
                      ],
                    },
                  ],
                },
              }),
            );
          await Future<void>.microtask(() {});
          expect(bloc.stateValue, isA<SurfaceReady>());

          tester.pumpComponent(
            A2uiSurfaceView(
              bloc: bloc,
              surfaceId: surfaceId,
              catalog: A2uiJasprCatalog.standard(),
            ),
          );
          await tester.pump();

          final radios = find
              .byComponentPredicate((c) => c is input<bool>)
              .evaluate()
              .map((e) => e.component as input<bool>)
              .toList();
          // 2 cards * 2 pickers * 2 options = 8 radios, 4 distinct names
          expect(radios, hasLength(8));
          final radioNames = radios.map((r) => r.name).toSet();
          expect(radioNames, hasLength(4));
          for (final name in radioNames) {
            expect(name, startsWith('a2ui_choice_${surfaceId}_/_'));
          }
        }

        await verifyNestedDuplicates(useRoot: true);
        await verifyNestedDuplicates(useRoot: false);
      },
    );

    testComponents(
      '(Issue #478) A2uiModal isolates render budget across open/close '
      'cycles under tight nodeBudget on both NodeResolver and BoundComponent '
      'paths',
      (tester) async {
        const basicCatalogId =
            'https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json';

        Future<void> verifyModalCycles({required bool useRoot}) async {
          final bloc = A2uiSurfaceBloc();
          addTearDown(bloc.close);

          final rootId = useRoot ? 'root' : 'col_top';
          final surfaceId = useRoot ? 's_modal_node' : 's_modal_bound';
          bloc
            ..add(
              ProcessJsonMessage({
                'version': 'v0.9',
                'createSurface': {
                  'surfaceId': surfaceId,
                  'catalogId': basicCatalogId,
                },
              }),
            )
            ..add(
              ProcessJsonMessage({
                'version': 'v0.9',
                'updateComponents': {
                  'surfaceId': surfaceId,
                  'components': [
                    {
                      'id': rootId,
                      'component': 'Column',
                      'children': const ['m1', 'filler'],
                    },
                    const {
                      'id': 'm1',
                      'component': 'Modal',
                      'trigger': 'trig',
                      'content': 'modal_col',
                    },
                    const {
                      'id': 'trig',
                      'component': 'Text',
                      'text': 'Open Modal',
                    },
                    const {
                      'id': 'filler',
                      'component': 'Text',
                      'text': 'Filler',
                    },
                    const {
                      'id': 'modal_col',
                      'component': 'Column',
                      'children': ['mc1', 'mc2', 'mc3'],
                    },
                    const {
                      'id': 'mc1',
                      'component': 'Text',
                      'text': 'Modal Body 1',
                    },
                    const {
                      'id': 'mc2',
                      'component': 'Text',
                      'text': 'Modal Body 2',
                    },
                    const {
                      'id': 'mc3',
                      'component': 'Text',
                      'text': 'Modal Body 3',
                    },
                  ],
                },
              }),
            );
          await Future<void>.microtask(() {});
          expect(bloc.stateValue, isA<SurfaceReady>());

          tester.pumpComponent(
            A2uiSurfaceView(
              bloc: bloc,
              surfaceId: surfaceId,
              catalog: A2uiJasprCatalog.standard(),
              nodeBudget: 6,
            ),
          );
          await tester.pump();

          expect(find.text('Open Modal'), findsOneComponent);
          expect(find.text('Modal Body 1'), findsNothing);

          // Cycle 1: Open -> verify -> Close -> verify
          await tester.click(
            find.byComponentPredicate(
              (c) => c is div && c.classes == 'a2ui-modal-trigger',
            ),
          );
          expect(find.text('Modal Body 1'), findsOneComponent);
          expect(find.text('Modal Body 3'), findsOneComponent);

          await tester.click(
            find.byComponentPredicate(
              (c) => c is button && c.classes == 'a2ui-modal-close',
            ),
          );
          expect(find.text('Modal Body 1'), findsNothing);

          // Cycle 2: Re-open -> verify fresh budget
          await tester.click(
            find.byComponentPredicate(
              (c) => c is div && c.classes == 'a2ui-modal-trigger',
            ),
          );
          expect(find.text('Modal Body 1'), findsOneComponent);
          expect(find.text('Modal Body 3'), findsOneComponent);
        }

        await verifyModalCycles(useRoot: true);
        await verifyModalCycles(useRoot: false);

        // Verify buildIsolatedChild delegates to buildChildCallback when
        // buildIsolatedChildCallback is null.
        final bloc = A2uiSurfaceBloc();
        addTearDown(bloc.close);
        final fallbackCtx = A2uiComponentContext(
          component: ComponentModel('m_fb', 'Modal', const {}),
          props: const {},
          surfaceBloc: bloc,
          surfaceId: 's1',
          buildChildCallback: (id) => div([Component.text('child:$id')]),
          buildChildrenCallback: (_) => const [],
        );
        final delegated = fallbackCtx.buildIsolatedChild('c1');
        expect(delegated, isA<div>());
      },
    );

    testComponents(
      '(Issue #478) A2uiIcon _SvgPathValidator covers all SVG command '
      'families, scientific notation, arc flags, post-Z tokens, and bounds',
      (tester) async {
        final bloc = A2uiSurfaceBloc();
        addTearDown(bloc.close);

        A2uiComponentContext makeIconCtx(String id, String svgPath) {
          return A2uiComponentContext(
            component: ComponentModel(id, 'Icon', const {}),
            props: {
              'name': {'svgPath': svgPath},
            },
            surfaceBloc: bloc,
            surfaceId: 's_svg',
            buildChildCallback: (_) => const div([]),
            buildChildrenCallback: (_) => const [],
          );
        }

        const validAllFamilies = 'M 1e0,2E-1 L 5 5 l 1 1 H 10 h 1 V 10 v 1 '
            'C 1 2 3 4 5 6 c 1 1 2 2 3 3 '
            'S 4 5 6 7 s 1 1 2 2 '
            'Q 2 3 4 5 q 1 1 2 2 '
            'T 8 9 t 1 1 '
            'A 5 5 0 0 1 15 15 a 2 2 45 1 0 3 3 Z';
        const validDecimal = 'M 1.5 2.5 L 10.25 .75 Z';

        final invalidPaths = <String>[
          'M 200000 0',
          'M 0 0 H 200000',
          'M 0 0 V 200000',
          'M 0 0 C 200000 0 1 1 2 2',
          'M 0 0 S 200000 0 2 2',
          'M 0 0 Q 200000 0 2 2',
          'M 0 0 T 200000 0',
          'M 0 0 A 200000 5 0 0 1 10 10',
          'M 0 0 A 5 5 0 2 1 10 10',
          'M 0 0 A 5 5 0 0 1 200000 10',
          'M 0 0 A 1 2 0',
          'M 0 0 Z 5 5',
          'M 0 0 H',
          'M 0 0 V',
          'M 0 0 C 1 2 3 4 5',
          'M 0 0 S 1 2 3',
          'M 0 0 A 1 2 0 0 1 3',
          'M 0 0 L .',
          'M 0 0 L 1e999 0',
          'M 0 0 L 1e+',
          'M 0 0 X 1 1',
          'M 0 0 ${'L 1 1 ' * 511}Z',
        ];

        tester.pumpComponent(
          Builder(
            builder: (context) => div([
              buildA2uiIcon(context, makeIconCtx('ok_all', validAllFamilies)),
              buildA2uiIcon(context, makeIconCtx('ok_dec', validDecimal)),
              for (var i = 0; i < invalidPaths.length; i++)
                buildA2uiIcon(
                  context,
                  makeIconCtx('bad_$i', invalidPaths[i]),
                ),
            ]),
          ),
        );

        expect(find.tag('svg'), findsNComponents(2));
        expect(find.text('?'), findsNComponents(invalidPaths.length));
      },
    );

    testComponents(
      '(Issue #478) A2uiSurfaceView disambiguates error fallback keys for '
      'duplicated throwing sibling components on NodeResolver and '
      'BoundComponent paths',
      (tester) async {
        const basicCatalogId =
            'https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json';

        final throwingCatalog = A2uiJasprCatalog.standard().copyWith({
          'Text': (_, __) => throw StateError('boom'),
        });

        Future<void> verifyThrowingSiblings({required bool useRoot}) async {
          final bloc = A2uiSurfaceBloc();
          addTearDown(bloc.close);

          final rootId = useRoot ? 'root' : 'col_err';
          final surfaceId = useRoot ? 's_err_node' : 's_err_bound';
          bloc
            ..add(
              ProcessJsonMessage({
                'version': 'v0.9',
                'createSurface': {
                  'surfaceId': surfaceId,
                  'catalogId': basicCatalogId,
                },
              }),
            )
            ..add(
              ProcessJsonMessage({
                'version': 'v0.9',
                'updateComponents': {
                  'surfaceId': surfaceId,
                  'components': [
                    {
                      'id': rootId,
                      'component': 'Column',
                      'children': const ['card_e', 'card_e'],
                    },
                    const {
                      'id': 'card_e',
                      'component': 'Card',
                      'child': 'bad_txt',
                    },
                    const {
                      'id': 'bad_txt',
                      'component': 'Text',
                      'text': 'Fail',
                    },
                  ],
                },
              }),
            );
          await Future<void>.microtask(() {});
          expect(bloc.stateValue, isA<SurfaceReady>());

          tester.pumpComponent(
            A2uiSurfaceView(
              bloc: bloc,
              surfaceId: surfaceId,
              catalog: throwingCatalog,
            ),
          );
          await tester.pump();

          final errorKeys = find
              .byComponentPredicate(
                (c) =>
                    c is div &&
                    c.key is ValueKey<String> &&
                    (c.key! as ValueKey<String>)
                        .value
                        .startsWith('a2ui_error_bad_txt'),
              )
              .evaluate()
              .map((e) => (e.component.key! as ValueKey<String>).value)
              .toSet();
          expect(errorKeys, hasLength(2));
        }

        await verifyThrowingSiblings(useRoot: true);
        await verifyThrowingSiblings(useRoot: false);
      },
    );
  });
}
