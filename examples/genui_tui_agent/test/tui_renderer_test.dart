import 'package:bloc_signals_genui/bloc_signals_genui.dart';
import 'package:genui_tui_agent/src/tui_renderer.dart';
import 'package:test/test.dart';

void main() {
  group('TuiRenderer', () {
    test('renders all states without throwing', () {
      expect(
        TuiRenderer.renderState(const SurfaceInitial()),
        contains('A2UI Terminal Client'),
      );
      expect(
        TuiRenderer.renderState(
          const SurfaceStreaming(surfaceId: 's1', messageCount: 3),
        ),
        contains('s1'),
      );
      expect(
        TuiRenderer.renderState(
          const SurfaceSubmitting(
            surfaceId: 's1',
            actionName: 'submit',
            sourceComponentId: 'btn1',
          ),
        ),
        contains('submit'),
      );
      expect(
        TuiRenderer.renderState(
          const SurfaceError(error: 'test error', surfaceId: 's1'),
        ),
        contains('test error'),
      );
    });

    test('renders surface model with components and forms', () {
      final surface = SurfaceModel<ComponentApi>(
        'test_surf',
        defaultCatalog: MinimalCatalog(),
      );
      surface.componentsModel.addComponent(
        ComponentModel('t1', 'Text', {'text': 'Header', 'variant': 'h1'}),
      );
      surface.componentsModel.addComponent(
        ComponentModel('tf1', 'TextField', {'label': 'Name'}),
      );
      surface.componentsModel.addComponent(
        ComponentModel('b1', 'Button', {
          'action': {'name': 'doWork'},
        }),
      );
      surface.componentsModel.addComponent(ComponentModel('c1', 'Column', {}));
      surface.componentsModel.addComponent(ComponentModel('r1', 'Row', {}));
      surface.componentsModel.addComponent(
        ComponentModel('u1', 'UnknownCustom', {}),
      );

      final output = TuiRenderer.renderState(
        SurfaceReady(
          surfaceId: 'test_surf',
          surface: surface,
          formValues: const {'name': 'Merlyn'},
        ),
      );

      expect(output, contains('Header'));
      expect(output, contains('Name'));
      expect(output, contains('doWork'));
      expect(output, contains('Merlyn'));
    });

    test('(Issue #373) TuiRenderer renders all 16 BasicCatalog v0.9/v1.0 '
        'components and ChildList template expansion', () {
      final surface = SurfaceModel<ComponentApi>(
        'basic_v09_surf',
        defaultCatalog: BasicCatalog.v0_9(),
      );
      surface.dataModel.set('/flights', const [
        {'flightNumber': 'PR-774', 'airline': 'Pacific Rim'},
        {'flightNumber': 'PR-882', 'airline': 'Pacific Rim'},
      ]);
      surface.dataModel.set('/priority', true);

      final examples =
          <
            ({
              String id,
              String type,
              Map<String, Object?> props,
              String expectedSubstring,
            })
          >[
            (
              id: 'cb1',
              type: 'CheckBox',
              props: const {'label': 'Priority Boarding', 'value': true},
              expectedSubstring: '[x] Priority Boarding',
            ),
            (
              id: 'cb2',
              type: 'CheckBox',
              props: const {'label': 'Checked Bag', 'value': false},
              expectedSubstring: '[ ] Checked Bag',
            ),
            (
              id: 'cb3',
              type: 'CheckBox',
              props: const {
                'label': 'Bound Priority',
                'value': {'path': '/priority'},
              },
              expectedSubstring: '[x] Bound Priority',
            ),
            (
              id: 'cp1',
              type: 'ChoicePicker',
              props: const {
                'label': 'Cabin Tier',
                'value': ['Business'],
                'options': [
                  {'label': 'Economy', 'value': 'Economy'},
                  {'label': 'Business', 'value': 'Business'},
                ],
              },
              expectedSubstring: 'Cabin Tier',
            ),
            (
              id: 'sl1',
              type: 'Slider',
              props: const {
                'label': 'Extra Legroom',
                'value': 50,
                'min': 0,
                'max': 100,
              },
              expectedSubstring: 'Extra Legroom: 50',
            ),
            (
              id: 'dt1',
              type: 'DateTimeInput',
              props: const {'label': 'Departure Date', 'value': '2026-11-15'},
              expectedSubstring: 'Departure Date: 2026-11-15',
            ),
            (
              id: 'ic1',
              type: 'Icon',
              props: const {'name': 'flight_takeoff'},
              expectedSubstring: 'flight_takeoff',
            ),
            (
              id: 'im1',
              type: 'Image',
              props: const {
                'url': 'https://example.com/jet.png',
                'description': 'Boeing 787',
              },
              expectedSubstring: 'Boeing 787',
            ),
            (
              id: 'cd1',
              type: 'Card',
              props: const {'elevation': 2},
              expectedSubstring: '[Card]',
            ),
            (
              id: 'dv1',
              type: 'Divider',
              props: const {'axis': 'horizontal'},
              expectedSubstring: '────',
            ),
            (
              id: 'ls1',
              type: 'List',
              props: const {
                'direction': 'vertical',
                'children': {'componentId': 'item_tpl', 'path': '/flights'},
              },
              expectedSubstring: '[List',
            ),
            (
              id: 'tb1',
              type: 'Tabs',
              props: const {
                'tabs': [
                  {'title': 'Flights', 'child': 't1'},
                  {'title': 'Hotels', 'child': 't1'},
                ],
              },
              expectedSubstring: 'Flights | Hotels',
            ),
            (
              id: 'md1',
              type: 'Modal',
              props: const {'trigger': 'btn_open', 'content': 't1'},
              expectedSubstring: '[Modal',
            ),
            (
              id: 'vd1',
              type: 'Video',
              props: const {'url': 'https://example.com/safety.mp4'},
              expectedSubstring: 'safety.mp4',
            ),
            (
              id: 'ap1',
              type: 'AudioPlayer',
              props: const {
                'url': 'https://example.com/chime.mp3',
                'description': 'Boarding Chime',
              },
              expectedSubstring: 'Boarding Chime',
            ),
          ];

      for (final ex in examples) {
        surface.componentsModel.addComponent(
          ComponentModel(ex.id, ex.type, ex.props),
        );
      }

      final output = TuiRenderer.renderState(
        SurfaceReady(
          surfaceId: 'basic_v09_surf',
          surface: surface,
          formValues: const {'priority': true},
        ),
      );

      for (final ex in examples) {
        expect(
          output,
          contains(ex.expectedSubstring),
          reason: 'Expected ${ex.type} to render "${ex.expectedSubstring}"',
        );
      }
    });
  });
}
