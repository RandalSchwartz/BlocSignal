import 'package:bloc_signals_genui/bloc_signals_genui.dart';
import 'package:bloc_signals_genui_jaspr/bloc_signals_genui_jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_test/jaspr_test.dart';

void main() {
  group('(Issue #436) Standard BasicCatalog 16 components & upgrades', () {
    late A2uiSurfaceBloc bloc;

    setUp(() {
      bloc = A2uiSurfaceBloc(catalogs: [MinimalCatalog()])
        ..add(
          ProcessJsonMessage({
            'version': 'v0.9',
            'createSurface': {
              'surfaceId': 's1',
              'catalogId': MinimalCatalog().id,
            },
          }),
        );
    });

    tearDown(() async {
      await bloc.close();
    });

    A2uiComponentContext makeContext(
      String id,
      String type,
      Map<String, dynamic> props, {
      Map<String, dynamic>? modelProps,
      Component Function(String)? buildChild,
      List<Component> Function(List<String>)? buildChildren,
    }) {
      return A2uiComponentContext(
        component: ComponentModel(id, type, modelProps ?? props),
        props: props,
        surfaceBloc: bloc,
        surfaceId: 's1',
        buildChildCallback: buildChild ?? Component.text,
        buildChildrenCallback: buildChildren ??
            (childIds) => childIds.map(Component.text).toList(),
      );
    }

    testComponents('Button invokes NodeAction via triggerAction',
        (tester) async {
      var called = false;
      Future<void> nodeAction([ActionDispatchOptions? options]) async {
        called = true;
      }

      final ctx = makeContext(
        'btn_node',
        'Button',
        {
          'action': nodeAction,
        },
        modelProps: const {
          'action': {
            'functionCall': {'call': 'doWork', 'args': <String, Object?>{}},
          },
        },
      );

      tester.pumpComponent(
        Builder(builder: (context) => buildA2uiButton(context, ctx)),
      );

      await tester.click(find.tag('button'));
      await Future<void>.microtask(() {});
      expect(called, isTrue);
    });

    testComponents('Row and Column apply buildWeightedChildren',
        (tester) async {
      bloc.add(
        const ProcessJsonMessage({
          'version': 'v0.9',
          'updateComponents': {
            'surfaceId': 's1',
            'components': [
              {
                'id': 'row_1',
                'component': 'Row',
                'children': ['w1', 'w2'],
              },
              {
                'id': 'w1',
                'component': 'Text',
                'text': 'Weighted',
                'weight': 3,
              },
              {'id': 'w2', 'component': 'Text', 'text': 'Plain'},
            ],
          },
        }),
      );

      final rowCtx = makeContext('row_1', 'Row', const {
        'children': ['w1', 'w2'],
      });
      tester.pumpComponent(
        Builder(builder: (context) => buildA2uiRow(context, rowCtx)),
      );
      expect(
        find.byComponentPredicate(
          (component) =>
              component is div &&
              (component.classes?.contains('a2ui-weighted-child') ?? false),
        ),
        findsOneComponent,
      );

      final colCtx = makeContext('col_1', 'Column', const {
        'children': ['w1', 'w2'],
      });
      tester.pumpComponent(
        Builder(builder: (context) => buildA2uiColumn(context, colCtx)),
      );
      expect(
        find.byComponentPredicate(
          (component) =>
              component is div &&
              (component.classes?.contains('a2ui-weighted-child') ?? false),
        ),
        findsOneComponent,
      );
    });

    testComponents('List renders vertical and horizontal layouts',
        (tester) async {
      final verticalCtx = makeContext('list_v', 'List', const {
        'children': ['item_1', 'item_2'],
        'direction': 'vertical',
        'align': 'center',
      });
      tester.pumpComponent(
        Builder(builder: (context) => buildA2uiList(context, verticalCtx)),
      );
      expect(
        find.byComponentPredicate(
          (component) =>
              component is div &&
              (component.classes?.contains('a2ui-list-vertical') ?? false),
        ),
        findsOneComponent,
      );
      expect(find.text('item_1'), findsOneComponent);
      expect(find.text('item_2'), findsOneComponent);

      final horizontalCtx = makeContext('list_h', 'List', const {
        'children': ['item_a'],
        'axis': 'horizontal',
        'align': 'end',
      });
      tester.pumpComponent(
        Builder(builder: (context) => buildA2uiList(context, horizontalCtx)),
      );
      expect(
        find.byComponentPredicate(
          (component) =>
              component is div &&
              (component.classes?.contains('a2ui-list-horizontal') ?? false),
        ),
        findsOneComponent,
      );
      expect(find.text('item_a'), findsOneComponent);
    });

    testComponents('Tabs renders active panel and switches on tab click',
        (tester) async {
      final emptyCtx = makeContext(
        'tabs_empty',
        'Tabs',
        const {'tabs': <Object?>[]},
      );
      tester.pumpComponent(
        Builder(builder: (context) => buildA2uiTabs(context, emptyCtx)),
      );
      expect(
        find.byComponentPredicate(
          (component) =>
              component is div &&
              (component.classes?.contains('a2ui-tabs') ?? false),
        ),
        findsNothing,
      );

      final tabsCtx = makeContext(
        'tabs_1',
        'Tabs',
        const {
          'tabItems': [
            {'title': 'First', 'child': 'panel_1'},
            {'title': 'Second', 'child': 'panel_2'},
          ],
        },
        buildChild: (id) => Component.text('Content of $id'),
      );

      tester.pumpComponent(
        Builder(builder: (context) => buildA2uiTabs(context, tabsCtx)),
      );

      expect(find.text('Content of panel_1'), findsOneComponent);
      expect(find.text('Content of panel_2'), findsNothing);

      final secondTab = find
          .byComponentPredicate(
            (component) =>
                component is button &&
                (component.classes?.contains('a2ui-tab') ?? false),
          )
          .evaluate()
          .elementAt(1)
          .component as button;
      secondTab.onClick?.call();
      await tester.pump();
      expect(find.text('Content of panel_2'), findsOneComponent);
      expect(find.text('Content of panel_1'), findsNothing);
    });

    testComponents('Modal toggles overlay on trigger click and close',
        (tester) async {
      final emptyCtx = makeContext('modal_empty', 'Modal', const {});
      tester.pumpComponent(
        Builder(builder: (context) => buildA2uiModal(context, emptyCtx)),
      );
      expect(
        find.byComponentPredicate(
          (component) =>
              component is div &&
              (component.classes?.contains('a2ui-modal') ?? false),
        ),
        findsNothing,
      );

      final modalCtx = makeContext(
        'modal_1',
        'Modal',
        const {
          'trigger': 'open_btn',
          'content': 'modal_body',
        },
        buildChild: (id) => Component.text('Child:$id'),
      );

      tester.pumpComponent(
        Builder(builder: (context) => buildA2uiModal(context, modalCtx)),
      );

      expect(find.text('Child:open_btn'), findsOneComponent);
      expect(find.text('Child:modal_body'), findsNothing);

      await tester.click(
        find.byComponentPredicate(
          (component) =>
              component is div &&
              (component.classes?.contains('a2ui-modal-trigger') ?? false),
        ),
      );
      expect(find.text('Child:modal_body'), findsOneComponent);

      await tester.click(
        find.byComponentPredicate(
          (component) =>
              component is button &&
              (component.classes?.contains('a2ui-modal-close') ?? false),
        ),
      );
      expect(find.text('Child:modal_body'), findsNothing);
    });

    testComponents('Icon renders standard icon, svgPath, and aria-label',
        (tester) async {
      final strIconCtx = makeContext('icon_str', 'Icon', const {
        'name': 'check',
        'size': 20,
        'description': 'Verified',
      });
      tester.pumpComponent(
        Builder(builder: (context) => buildA2uiIcon(context, strIconCtx)),
      );
      expect(
        find.byComponentPredicate(
          (component) =>
              component is span &&
              (component.classes?.contains('a2ui-icon') ?? false) &&
              component.attributes?['aria-label'] == 'Verified',
        ),
        findsOneComponent,
      );

      final stdCtx = makeContext('icon_1', 'Icon', const {
        'name': {'name': 'check'},
        'size': 20,
      });
      tester.pumpComponent(
        Builder(builder: (context) => buildA2uiIcon(context, stdCtx)),
      );
      expect(
        find.byComponentPredicate(
          (component) =>
              component is span &&
              (component.classes?.contains('a2ui-icon') ?? false) &&
              component.attributes?['aria-hidden'] == 'true',
        ),
        findsOneComponent,
      );

      final svgCtx = makeContext('icon_svg', 'Icon', const {
        'name': {'svgPath': 'M10 10 H 90 V 90 H 10 Z'},
        'size': 32,
        'description': 'Custom square',
      });
      tester.pumpComponent(
        Builder(builder: (context) => buildA2uiIcon(context, svgCtx)),
      );
      expect(find.tag('svg'), findsOneComponent);
      expect(find.tag('path'), findsOneComponent);
    });

    testComponents(
        'Image validates http/https URLs, applies fit/variant classes, '
        'and falls back on invalid URL', (tester) async {
      final validCtx = makeContext('img_1', 'Image', const {
        'url': 'https://example.com/photo.png',
        'description': 'Example photo',
        'fit': 'cover',
        'variant': 'avatar',
      });
      tester.pumpComponent(
        Builder(builder: (context) => buildA2uiImage(context, validCtx)),
      );
      expect(find.tag('img'), findsOneComponent);
      expect(
        find.byComponentPredicate(
          (component) =>
              component is img &&
              (component.classes?.contains('a2ui-image-fit-cover') ?? false) &&
              (component.classes?.contains('a2ui-image-variant-avatar') ??
                  false),
        ),
        findsOneComponent,
      );

      final unsafeCtx = makeContext('img_unsafe', 'Image', const {
        'url': 'javascript:alert(1)',
        'description': 'Blocked image',
      });
      tester.pumpComponent(
        Builder(builder: (context) => buildA2uiImage(context, unsafeCtx)),
      );
      expect(find.tag('img'), findsNothing);
      expect(
        find.byComponentPredicate(
          (component) =>
              component is div &&
              (component.classes?.contains('a2ui-image-fallback') ?? false),
        ),
        findsOneComponent,
      );
    });

    testComponents(
        'CheckBox binds boolean value and displays validation errors',
        (tester) async {
      final ctx = makeContext('cb_1', 'CheckBox', const {
        'label': 'Accept terms',
        'value': true,
        'isValid': false,
        'validationErrors': ['Must accept terms'],
      });

      tester.pumpComponent(
        Builder(builder: (context) => buildA2uiCheckBox(context, ctx)),
      );

      expect(find.text('Accept terms'), findsOneComponent);
      expect(find.text('Must accept terms'), findsOneComponent);
      final checkboxFinder =
          find.byComponentPredicate((component) => component is input<bool>);
      expect(checkboxFinder, findsOneComponent);

      final checkboxEl =
          checkboxFinder.evaluate().single.component as input<bool>;
      checkboxEl.onChange?.call(false);

      final ready = bloc.getSurfaceReady('s1')!;
      expect(ready.surface.dataModel.get('/cb_1'), isFalse);
    });

    testComponents(
        'ChoicePicker supports mutuallyExclusive, multipleSelection, chips, '
        'filterable, and validation errors', (tester) async {
      final ctx = makeContext('cp_1', 'ChoicePicker', const {
        'label': 'Pick colors',
        'variant': 'multipleSelection',
        'displayStyle': 'chips',
        'filterable': true,
        'value': ['red'],
        'options': [
          {'label': 'Red', 'value': 'red'},
          {'label': 'Blue', 'value': 'blue'},
        ],
        'isValid': false,
        'validationErrors': ['Pick at least two'],
      });

      tester.pumpComponent(
        Builder(builder: (context) => buildA2uiChoicePicker(context, ctx)),
      );

      expect(find.text('Pick colors'), findsOneComponent);
      expect(find.text('Pick at least two'), findsOneComponent);
      expect(find.text('Red'), findsOneComponent);
      expect(find.text('Blue'), findsOneComponent);

      // Filter to Blue only
      final filterEl = find
          .byComponentPredicate((component) => component is input<String>)
          .evaluate()
          .single
          .component as input<String>;
      filterEl.onInput?.call('blu');
      await tester.pump();
      expect(find.text('Blue'), findsOneComponent);
      expect(find.text('Red'), findsNothing);

      // Click Blue chip -> adds 'blue' to ['red']
      final chips = find
          .byComponentPredicate((component) => component is button)
          .evaluate()
          .map((el) => el.component as button)
          .toList();
      chips.first.onClick?.call();
      await tester.pump();
      expect(
        bloc.getSurfaceReady('s1')!.surface.dataModel.get('/cp_1'),
        equals(['red', 'blue']),
      );

      // Deselect Red chip -> removes 'red'
      final redCtx = makeContext('cp_1b', 'ChoicePicker', const {
        'variant': 'multipleSelection',
        'displayStyle': 'chips',
        'value': 'red',
        'options': [
          {'label': 'Red', 'value': 'red'},
        ],
      });
      tester.pumpComponent(
        Builder(builder: (context) => buildA2uiChoicePicker(context, redCtx)),
      );
      (find
              .byComponentPredicate((component) => component is button)
              .evaluate()
              .single
              .component as button)
          .onClick
          ?.call();
      expect(
        bloc.getSurfaceReady('s1')!.surface.dataModel.get('/cp_1b'),
        isEmpty,
      );

      // Mutually exclusive checkbox/radio variant
      final singleCtx = makeContext('cp_2', 'ChoicePicker', const {
        'variant': 'mutuallyExclusive',
        'displayStyle': 'checkbox',
        'value': ['a'],
        'options': [
          {'label': 'Alpha', 'value': 'a'},
          {'label': 'Beta', 'value': 'b'},
        ],
      });
      tester.pumpComponent(
        Builder(
          builder: (context) => buildA2uiChoicePicker(context, singleCtx),
        ),
      );
      expect(find.text('Alpha'), findsOneComponent);
      expect(find.text('Beta'), findsOneComponent);
      final radioInputs = find
          .byComponentPredicate((component) => component is input<bool>)
          .evaluate()
          .map((el) => el.component as input<bool>)
          .toList();
      radioInputs.last.onChange?.call(true);
      expect(
        bloc.getSurfaceReady('s1')!.surface.dataModel.get('/cp_2'),
        equals(['b']),
      );
    });

    testComponents(
        'Slider maps steps to step attribute and binds numeric value',
        (tester) async {
      final ctx = makeContext('sl_1', 'Slider', const {
        'label': 'Volume',
        'min': 0,
        'max': 100,
        'steps': 4,
        'value': 50,
        'isValid': false,
        'validationErrors': ['Too loud'],
      });

      tester.pumpComponent(
        Builder(builder: (context) => buildA2uiSlider(context, ctx)),
      );

      expect(find.text('Volume'), findsOneComponent);
      expect(find.text('Too loud'), findsOneComponent);
      final sliderFinder = find.byComponentPredicate(
        (component) =>
            component is input &&
            component.attributes?['step'] == '25.0' &&
            component.attributes?['min'] == '0.0' &&
            component.attributes?['max'] == '100.0',
      );
      expect(sliderFinder, findsOneComponent);

      final sliderEl =
          sliderFinder.evaluate().single.component as input<String>;
      sliderEl.onInput?.call('75');
      final ready = bloc.getSurfaceReady('s1')!;
      expect(ready.surface.dataModel.get('/sl_1'), equals(75.0));
    });

    testComponents(
        'DateTimeInput maps enableDate/enableTime to input types and binds '
        'value', (tester) async {
      final dateOnlyCtx = makeContext('dt_date', 'DateTimeInput', const {
        'label': 'Birthday',
        'enableDate': true,
        'enableTime': false,
        'min': '2000-01-01',
        'max': '2030-12-31',
        'value': '2026-05-01',
        'isValid': false,
        'validationErrors': ['Required'],
      });
      tester.pumpComponent(
        Builder(
          builder: (context) => buildA2uiDateTimeInput(context, dateOnlyCtx),
        ),
      );
      expect(find.text('Birthday'), findsOneComponent);
      expect(find.text('Required'), findsOneComponent);
      final dateInputFinder = find.byComponentPredicate(
        (component) => component is input && component.type == InputType.date,
      );
      expect(dateInputFinder, findsOneComponent);

      final dateEl =
          dateInputFinder.evaluate().single.component as input<String>;
      dateEl.onInput?.call('2026-06-15');
      expect(
        bloc.getSurfaceReady('s1')!.surface.dataModel.get('/dt_date'),
        equals('2026-06-15'),
      );

      final timeOnlyCtx = makeContext('dt_time', 'DateTimeInput', const {
        'enableDate': false,
        'enableTime': true,
      });
      tester.pumpComponent(
        Builder(
          builder: (context) => buildA2uiDateTimeInput(context, timeOnlyCtx),
        ),
      );
      expect(
        find.byComponentPredicate(
          (component) => component is input && component.type == InputType.time,
        ),
        findsOneComponent,
      );

      final dateTimeCtx = makeContext('dt_both', 'DateTimeInput', const {
        'enableDate': true,
        'enableTime': true,
      });
      tester.pumpComponent(
        Builder(
          builder: (context) => buildA2uiDateTimeInput(context, dateTimeCtx),
        ),
      );
      expect(
        find.byComponentPredicate(
          (component) =>
              component is input && component.type == InputType.dateTimeLocal,
        ),
        findsOneComponent,
      );
    });
  });
}
