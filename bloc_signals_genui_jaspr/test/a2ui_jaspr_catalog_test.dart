import 'package:bloc_signals_genui/bloc_signals_genui.dart';
import 'package:bloc_signals_genui_jaspr/bloc_signals_genui_jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_test/jaspr_test.dart';

void main() {
  group('A2uiJasprCatalog registry tests', () {
    test('standard catalog contains 7 core primitives', () {
      final catalog = A2uiJasprCatalog.standard();
      final types = catalog.registeredTypes.toSet();

      expect(
        types,
        containsAll([
          'Text',
          'Row',
          'Column',
          'Button',
          'TextField',
          'Card',
          'Divider',
        ]),
      );
      expect(catalog.hasBuilder('Text'), isTrue);
      expect(catalog.hasBuilder('NonExistent'), isFalse);
    });

    test('register, registerAll, copyWith, and copyWithout work correctly', () {
      final catalog = A2uiJasprCatalog();
      expect(catalog.registeredTypes, isEmpty);

      catalog.register('Custom', (context, compCtx) => const div([]));
      expect(catalog.hasBuilder('Custom'), isTrue);

      catalog.registerAll({
        'A': (context, compCtx) => const div([]),
        'B': (context, compCtx) => const div([]),
      });
      expect(catalog.registeredTypes, containsAll(['Custom', 'A', 'B']));

      final copied = catalog.copyWith({
        'C': (context, compCtx) => const div([]),
      });
      expect(copied.hasBuilder('C'), isTrue);
      expect(catalog.hasBuilder('C'), isFalse);

      final pruned = copied.copyWithout(['A', 'Custom']);
      expect(pruned.hasBuilder('A'), isFalse);
      expect(pruned.hasBuilder('Custom'), isFalse);
      expect(pruned.hasBuilder('B'), isTrue);
      expect(pruned.hasBuilder('C'), isTrue);
    });

    testComponents(
        'build returns unknown component fallback for unregistered type',
        (tester) async {
      final catalog = A2uiJasprCatalog();
      final comp = ComponentModel('unknown_1', 'UnknownType', const {});
      final bloc = A2uiSurfaceBloc(catalogs: [MinimalCatalog()]);

      final compCtx = A2uiComponentContext(
        component: comp,
        props: const {},
        surfaceBloc: bloc,
        surfaceId: 's1',
        buildChildCallback: (_) => const div([]),
        buildChildrenCallback: (_) => const [],
      );

      tester.pumpComponent(
        Builder(
          builder: (context) => catalog.build(context, compCtx),
        ),
      );

      expect(
        find.text('Unknown A2UI Component: <UnknownType>'),
        findsOneComponent,
      );
      await bloc.close();
    });
  });

  group('Standard component builders tests', () {
    late A2uiSurfaceBloc bloc;

    setUp(() {
      bloc = A2uiSurfaceBloc(catalogs: [MinimalCatalog()]);
    });

    tearDown(() async {
      await bloc.close();
    });

    testComponents('buildA2uiText renders all typography variants',
        (tester) async {
      final variants = [
        'h1',
        'h2',
        'h3',
        'h4',
        'h5',
        'title',
        'caption',
        'body',
        'unknown_variant',
      ];

      for (final variant in variants) {
        final comp = ComponentModel(
          'txt_$variant',
          'Text',
          {'text': 'Sample $variant', 'variant': variant},
        );

        final compCtx = A2uiComponentContext(
          component: comp,
          props: {'text': 'Sample $variant', 'variant': variant},
          surfaceBloc: bloc,
          surfaceId: 's1',
          buildChildCallback: (_) => const div([]),
          buildChildrenCallback: (_) => const [],
        );

        tester.pumpComponent(
          Builder(builder: (context) => buildA2uiText(context, compCtx)),
        );

        expect(find.text('Sample $variant'), findsOneComponent);
      }
    });

    testComponents(
        'buildA2uiButton renders primary, borderless, disabled, and '
        'dispatches action', (tester) async {
      // 1. Primary enabled button with Map action and context
      final btnModel1 = ComponentModel(
        'btn_1',
        'Button',
        const {
          'action': {
            'event': {
              'name': 'customSubmit',
              'context': {'field': 'val'},
            },
          },
        },
      );

      final compCtx1 = A2uiComponentContext(
        component: btnModel1,
        props: {
          'variant': 'primary',
          'enabled': true,
          'action': {
            'event': {
              'name': 'customSubmit',
              'context': {'field': 'val'},
            },
          },
        },
        surfaceBloc: bloc,
        surfaceId: 's1',
        buildChildCallback: (_) => const div([]),
        buildChildrenCallback: (_) => const [],
      );

      late BuildContext testContext;
      tester.pumpComponent(
        Builder(
          builder: (context) {
            testContext = context;
            return buildA2uiButton(context, compCtx1);
          },
        ),
      );

      expect(find.text('Action'), findsOneComponent);
      final rendered1 = buildA2uiButton(testContext, compCtx1) as button;
      rendered1.onClick?.call();

      // 2. Borderless button with string action and child ID
      final btnModel2 = ComponentModel(
        'btn_2',
        'Button',
        const {'action': 'simpleAction'},
      );

      final compCtx2 = A2uiComponentContext(
        component: btnModel2,
        props: const {
          'variant': 'borderless',
          'enabled': true,
          'child': 'btn_child_txt',
          'action': 'simpleAction',
        },
        surfaceBloc: bloc,
        surfaceId: 's1',
        buildChildCallback: (id) => const Component.text('Custom Child Text'),
        buildChildrenCallback: (_) => const [],
      );

      tester.pumpComponent(
        Builder(builder: (context) => buildA2uiButton(context, compCtx2)),
      );

      expect(find.text('Custom Child Text'), findsOneComponent);
      final rendered2 = buildA2uiButton(testContext, compCtx2) as button;
      rendered2.onClick?.call();

      // 3. Disabled button when isValid is false
      final btnModel3 = ComponentModel(
        'btn_3',
        'Button',
        const {'action': 'disabledAction'},
      );

      final compCtx3 = A2uiComponentContext(
        component: btnModel3,
        props: const {
          'isValid': false,
          'enabled': true,
        },
        surfaceBloc: bloc,
        surfaceId: 's1',
        buildChildCallback: (_) => const div([]),
        buildChildrenCallback: (_) => const [],
      );

      tester.pumpComponent(
        Builder(builder: (context) => buildA2uiButton(context, compCtx3)),
      );
      final rendered3 = buildA2uiButton(testContext, compCtx3) as button;
      expect(rendered3.onClick, isNull);

      // 4. Button with action having direct name and context
      final btnModel4 = ComponentModel(
        'btn_4',
        'Button',
        const {
          'action': {
            'name': 'actionWithName',
            'context': {'abc': 123},
          },
        },
      );

      final compCtx4 = A2uiComponentContext(
        component: btnModel4,
        props: {
          'action': {
            'name': 'actionWithName',
            'context': {'abc': 123},
          },
        },
        surfaceBloc: bloc,
        surfaceId: 's1',
        buildChildCallback: (_) => const div([]),
        buildChildrenCallback: (_) => const [],
      );

      tester.pumpComponent(
        Builder(builder: (context) => buildA2uiButton(context, compCtx4)),
      );
      final rendered4 = buildA2uiButton(testContext, compCtx4) as button;
      rendered4.onClick?.call();

      // 5. Button with action having event map without name, and root context
      final btnModel5 = ComponentModel('btn_5', 'Button', const {});
      final compCtx5 = A2uiComponentContext(
        component: btnModel5,
        props: {
          'action': {
            'event': <String, dynamic>{},
            'context': {'rootKey': 'rootVal'},
          },
        },
        surfaceBloc: bloc,
        surfaceId: 's1',
        buildChildCallback: (_) => const div([]),
        buildChildrenCallback: (_) => const [],
      );
      final rendered5 = buildA2uiButton(testContext, compCtx5) as button;
      rendered5.onClick?.call();

      // 6. Button with fallback to modelAction and null rawAction
      final btnModel6 = ComponentModel(
        'btn_6',
        'Button',
        const {'action': 'fromModelAction'},
      );
      final compCtx6 = A2uiComponentContext(
        component: btnModel6,
        props: const {},
        surfaceBloc: bloc,
        surfaceId: 's1',
        buildChildCallback: (_) => const div([]),
        buildChildrenCallback: (_) => const [],
      );
      final rendered6 = buildA2uiButton(testContext, compCtx6) as button;
      rendered6.onClick?.call();

      // 7. Button with no action anywhere
      final btnModel7 = ComponentModel('btn_7', 'Button', const {});
      final compCtx7 = A2uiComponentContext(
        component: btnModel7,
        props: const {},
        surfaceBloc: bloc,
        surfaceId: 's1',
        buildChildCallback: (_) => const div([]),
        buildChildrenCallback: (_) => const [],
      );
      final rendered7 = buildA2uiButton(testContext, compCtx7) as button;
      rendered7.onClick?.call();
    });

    testComponents(
        'buildA2uiTextField renders text, longText, obscured, number, '
        'and labels', (tester) async {
      // 1. Short text with label and placeholder
      final comp1 = ComponentModel('tf_1', 'TextField', const {});
      final compCtx1 = A2uiComponentContext(
        component: comp1,
        props: const {
          'value': 'Current Value',
          'label': 'Username',
          'placeholder': 'Enter username',
          'helperText': 'Your public handle',
          'variant': 'shortText',
        },
        surfaceBloc: bloc,
        surfaceId: 's1',
        buildChildCallback: (_) => const div([]),
        buildChildrenCallback: (_) => const [],
      );

      late BuildContext testContext;
      tester.pumpComponent(
        Builder(
          builder: (context) {
            testContext = context;
            return buildA2uiTextField(context, compCtx1);
          },
        ),
      );

      expect(find.text('Username'), findsOneComponent);
      expect(find.text('Your public handle'), findsOneComponent);

      // 2. Long text with textarea and errorText
      final comp2 = ComponentModel('tf_2', 'TextField', const {});
      final compCtx2 = A2uiComponentContext(
        component: comp2,
        props: const {
          'value': 'Multiline body text',
          'variant': 'longText',
          'errorText': 'Explicit error message',
        },
        surfaceBloc: bloc,
        surfaceId: 's1',
        buildChildCallback: (_) => const div([]),
        buildChildrenCallback: (_) => const [],
      );

      tester.pumpComponent(
        Builder(builder: (context) => buildA2uiTextField(context, compCtx2)),
      );

      expect(find.text('Explicit error message'), findsOneComponent);

      // 3. Obscured password with validationErrors fallback
      final comp3 = ComponentModel('tf_3', 'TextField', const {});
      final compCtx3 = A2uiComponentContext(
        component: comp3,
        props: const {
          'value': 'secret',
          'variant': 'obscured',
          'validationErrors': ['Validation error fallback'],
        },
        surfaceBloc: bloc,
        surfaceId: 's1',
        buildChildCallback: (_) => const div([]),
        buildChildrenCallback: (_) => const [],
      );

      tester.pumpComponent(
        Builder(builder: (context) => buildA2uiTextField(context, compCtx3)),
      );

      expect(find.text('Validation error fallback'), findsOneComponent);

      // 4. Number input variant
      final comp4 = ComponentModel('tf_4', 'TextField', const {});
      final compCtx4 = A2uiComponentContext(
        component: comp4,
        props: const {
          'value': '42',
          'variant': 'number',
        },
        surfaceBloc: bloc,
        surfaceId: 's1',
        buildChildCallback: (_) => const div([]),
        buildChildrenCallback: (_) => const [],
      );

      tester.pumpComponent(
        Builder(builder: (context) => buildA2uiTextField(context, compCtx4)),
      );

      final renderedLong = buildA2uiTextField(testContext, compCtx2) as div;
      final txtArea = renderedLong.children.whereType<textarea>().first;
      txtArea.onInput?.call('New long text');

      final renderedShort = buildA2uiTextField(testContext, compCtx1) as div;
      final inputEl = renderedShort.children.whereType<input<String>>().first;
      inputEl.onInput?.call('New short text');
    });

    testComponents(
        'buildA2uiCard renders single child, multiple children, '
        'and empty content', (tester) async {
      // Single child
      final comp1 = ComponentModel('card_1', 'Card', const {'child': 'c_1'});
      final compCtx1 = A2uiComponentContext(
        component: comp1,
        props: const {'child': 'c_1', 'elevation': 3.0},
        surfaceBloc: bloc,
        surfaceId: 's1',
        buildChildCallback: (id) => const Component.text('Card Child Text'),
        buildChildrenCallback: (_) => const [],
      );

      tester.pumpComponent(
        Builder(builder: (context) => buildA2uiCard(context, compCtx1)),
      );

      expect(find.text('Card Child Text'), findsOneComponent);

      // Multiple children
      final comp2 = ComponentModel(
        'card_2',
        'Card',
        const {
          'children': ['c_1', 'c_2'],
        },
      );
      final compCtx2 = A2uiComponentContext(
        component: comp2,
        props: const {
          'children': ['c_1', 'c_2'],
        },
        surfaceBloc: bloc,
        surfaceId: 's1',
        buildChildCallback: (_) => const div([]),
        buildChildrenCallback: (ids) => ids.map(Component.text).toList(),
      );

      tester.pumpComponent(
        Builder(builder: (context) => buildA2uiCard(context, compCtx2)),
      );

      expect(find.text('c_1'), findsOneComponent);
      expect(find.text('c_2'), findsOneComponent);

      // Empty
      final comp3 = ComponentModel('card_3', 'Card', const {});
      final compCtx3 = A2uiComponentContext(
        component: comp3,
        props: const {},
        surfaceBloc: bloc,
        surfaceId: 's1',
        buildChildCallback: (_) => const div([]),
        buildChildrenCallback: (_) => const [],
      );

      tester.pumpComponent(
        Builder(builder: (context) => buildA2uiCard(context, compCtx3)),
      );
    });

    testComponents(
        'buildA2uiColumn and buildA2uiRow render flex layout with '
        'alignment options', (tester) async {
      final compCol = ComponentModel('col_1', 'Column', const {
        'children': ['col_item_1'],
        'justify': 'spaceBetween',
        'align': 'stretch',
      });
      final compCtxCol = A2uiComponentContext(
        component: compCol,
        props: const {
          'children': ['col_item_1'],
          'justify': 'spaceBetween',
          'align': 'stretch',
        },
        surfaceBloc: bloc,
        surfaceId: 's1',
        buildChildCallback: (_) => const div([]),
        buildChildrenCallback: (ids) => ids.map(Component.text).toList(),
      );

      tester.pumpComponent(
        Builder(builder: (context) => buildA2uiColumn(context, compCtxCol)),
      );

      expect(find.text('col_item_1'), findsOneComponent);

      final compRow = ComponentModel('row_1', 'Row', const {
        'children': ['row_item_1'],
        'mainAxisAlignment': 'center',
        'crossAxisAlignment': 'start',
      });
      final compCtxRow = A2uiComponentContext(
        component: compRow,
        props: const {
          'children': ['row_item_1'],
          'mainAxisAlignment': 'center',
          'crossAxisAlignment': 'start',
        },
        surfaceBloc: bloc,
        surfaceId: 's1',
        buildChildCallback: (_) => const div([]),
        buildChildrenCallback: (ids) => ids.map(Component.text).toList(),
      );

      tester.pumpComponent(
        Builder(builder: (context) => buildA2uiRow(context, compCtxRow)),
      );

      expect(find.text('row_item_1'), findsOneComponent);

      final justifies = [
        'end',
        'spaceBetween',
        'spaceAround',
        'spaceEvenly',
        'other',
      ];
      final aligns = ['end', 'stretch', 'other'];
      for (final j in justifies) {
        for (final a in aligns) {
          final comp =
              ComponentModel('r_${j}_$a', 'Row', {'justify': j, 'align': a});
          final ctx = A2uiComponentContext(
            component: comp,
            props: {'justify': j, 'align': a},
            surfaceBloc: bloc,
            surfaceId: 's1',
            buildChildCallback: (_) => const div([]),
            buildChildrenCallback: (_) => const [],
          );
          tester.pumpComponent(
            Builder(builder: (c) => buildA2uiRow(c, ctx)),
          );
        }
      }
    });

    testComponents('buildA2uiDivider renders horizontal and vertical dividers',
        (tester) async {
      final compHoriz = ComponentModel('div_h', 'Divider', const {
        'axis': 'horizontal',
        'thickness': 2.0,
        'height': 24.0,
      });
      final compCtxHoriz = A2uiComponentContext(
        component: compHoriz,
        props: const {
          'axis': 'horizontal',
          'thickness': 2.0,
          'height': 24.0,
        },
        surfaceBloc: bloc,
        surfaceId: 's1',
        buildChildCallback: (_) => const div([]),
        buildChildrenCallback: (_) => const [],
      );

      tester.pumpComponent(
        Builder(builder: (context) => buildA2uiDivider(context, compCtxHoriz)),
      );

      final compVert = ComponentModel('div_v', 'Divider', const {
        'axis': 'vertical',
        'thickness': 1.0,
        'height': 30.0,
      });
      final compCtxVert = A2uiComponentContext(
        component: compVert,
        props: const {
          'axis': 'vertical',
          'thickness': 1.0,
          'height': 30.0,
        },
        surfaceBloc: bloc,
        surfaceId: 's1',
        buildChildCallback: (_) => const div([]),
        buildChildrenCallback: (_) => const [],
      );

      tester.pumpComponent(
        Builder(builder: (context) => buildA2uiDivider(context, compCtxVert)),
      );
    });
  });
}
