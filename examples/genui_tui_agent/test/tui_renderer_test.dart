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

    group('(Issue #430) ANSI and control character sanitization', () {
      test('sanitize strips CSI, OSC, single-char ESC, and C0/C1 control chars '
          'while preserving tabs, newlines, and normal text', () {
        expect(TuiRenderer.sanitize(null), isEmpty);
        expect(TuiRenderer.sanitize(42), '42');
        expect(TuiRenderer.sanitize('\x1B[31mAlert\x1B[0m\x07'), 'Alert');
        expect(TuiRenderer.sanitize('\x1B[2J\x1B[1;1HCleared'), 'Cleared');
        expect(TuiRenderer.sanitize('\x1B]0;Evil Title\x07Safe'), 'Safe');
        expect(TuiRenderer.sanitize('\x1B]52;c;SGVsbG8=\x1B\\Text'), 'Text');
        expect(TuiRenderer.sanitize('\x1BcReset'), 'Reset');
        expect(
          TuiRenderer.sanitize('A\x00B\x08C\x0BD\x1FE\x7FF\x80G\x9FH'),
          'ABCDEFGH',
        );
        expect(
          TuiRenderer.sanitize('Line1\tCol2\nLine2'),
          'Line1\tCol2\nLine2',
        );
      });

      test('renderState strips ANSI and control sequences from all dynamic '
          'top-level states and form values', () {
        final streaming = TuiRenderer.renderState(
          const SurfaceStreaming(
            surfaceId: '\x1B[31msurf_stream\x1B[0m\x07',
            messageCount: 1,
          ),
        );
        expect(streaming, contains('surf_stream'));
        expect(streaming, isNot(contains('\x1B[31m')));
        expect(streaming, isNot(contains('\x07')));

        final submitting = TuiRenderer.renderState(
          const SurfaceSubmitting(
            surfaceId: '\x1B[2Jsurf_sub',
            actionName: '\x1B]0;pwn\x07book_flight',
            sourceComponentId: 'btn1',
          ),
        );
        expect(submitting, contains('surf_sub'));
        expect(submitting, contains('book_flight'));
        expect(submitting, isNot(contains('\x1B[2J')));
        expect(submitting, isNot(contains('\x1B]0;')));
        expect(submitting, isNot(contains('\x07')));

        final error = TuiRenderer.renderState(
          const SurfaceError(
            error: '\x1B[31mbad_error\x07\x7F',
            surfaceId: '\x1B[2Ksurf_err',
          ),
        );
        expect(error, contains('bad_error'));
        expect(error, contains('surf_err'));
        expect(error, isNot(contains('\x1B[31m')));
        expect(error, isNot(contains('\x1B[2K')));
        expect(error, isNot(contains('\x07')));
        expect(error, isNot(contains('\x7F')));
      });

      test('renderState strips ANSI and control sequences from all '
          'rendered component properties and form entries', () {
        final surface = SurfaceModel<ComponentApi>(
          '\x1B[31msurf_id\x1B[0m',
          defaultCatalog: BasicCatalog.v0_9(),
        );
        surface.componentsModel.addComponent(
          ComponentModel('t_h1', 'Text', const {
            'text': '\x1B[31mHeading\x07',
            'variant': 'h1',
          }),
        );
        surface.componentsModel.addComponent(
          ComponentModel('t_body', 'Text', const {'text': '\x1B[2JBody\x7F'}),
        );
        surface.componentsModel.addComponent(
          ComponentModel('b1', 'Button', const {
            'action': {'name': '\x1B]0;title\x07BtnAction'},
          }),
        );
        surface.componentsModel.addComponent(
          ComponentModel('tf1', 'TextField', const {
            'label': '\x1B[31mFieldLabel',
            'value': '\x1B[32mFieldVal\x07',
          }),
        );
        surface.componentsModel.addComponent(
          ComponentModel('cb1', 'CheckBox', const {
            'label': '\x1B[33mCheckLabel',
            'value': true,
          }),
        );
        surface.componentsModel.addComponent(
          ComponentModel('cp1', 'ChoicePicker', const {
            'label': '\x1B[34mPickLabel',
            'value': ['\x1B[35mOptA'],
          }),
        );
        surface.componentsModel.addComponent(
          ComponentModel('sl1', 'Slider', const {
            'label': '\x1B[36mSlideLabel',
            'value': '\x1B[31m50',
            'min': '\x1B[31m0',
            'max': '\x1B[31m100',
          }),
        );
        surface.componentsModel.addComponent(
          ComponentModel('dt1', 'DateTimeInput', const {
            'label': '\x1B[31mDateLabel',
            'value': '\x1B[32m2026-11-15',
          }),
        );
        surface.componentsModel.addComponent(
          ComponentModel('ic1', 'Icon', const {'name': '\x1B[31mflight_icon'}),
        );
        surface.componentsModel.addComponent(
          ComponentModel('im1', 'Image', const {
            'description': '\x1B[31mImgDesc',
            'url': '\x1B]0;u\x07https://example.com/a.png',
          }),
        );
        surface.componentsModel.addComponent(
          ComponentModel('vd1', 'Video', const {
            'url': '\x1B[31mhttps://example.com/v.mp4',
          }),
        );
        surface.componentsModel.addComponent(
          ComponentModel('ap1', 'AudioPlayer', const {
            'description': '\x1B[31mAudDesc',
            'url': '\x1B[32mhttps://example.com/a.mp3',
          }),
        );
        surface.componentsModel.addComponent(
          ComponentModel('ls1', 'List', const {
            'direction': '\x1B[31mhorizontal',
            'children': {
              'componentId': '\x1B[31mtpl_id',
              'path': '\x1B[32m/items',
            },
          }),
        );
        surface.componentsModel.addComponent(
          ComponentModel('tb1', 'Tabs', const {
            'tabs': [
              {'title': '\x1B[31mTabOne'},
              {'title': '\x1B[32mTabTwo\x07'},
            ],
          }),
        );
        surface.componentsModel.addComponent(
          ComponentModel('md1', 'Modal', const {
            'trigger': '\x1B[31mOpenModal',
          }),
        );
        surface.componentsModel.addComponent(
          ComponentModel('\x1B[31mu_id', '\x1B[32mCustomWidget', const {}),
        );

        final output = TuiRenderer.renderState(
          SurfaceReady(
            surfaceId: '\x1B[31msurf_id\x1B[0m',
            surface: surface,
            formValues: const {'\x1B[31mfKey\x07': '\x1B[32mfVal\x7F'},
          ),
        );

        // Injected escape payloads must be completely stripped
        expect(output, isNot(contains('\x1B[31m')));
        expect(output, isNot(contains('\x1B[2J')));
        expect(output, isNot(contains('\x1B]0;')));
        expect(output, isNot(contains('\x07')));
        expect(output, isNot(contains('\x7F')));

        // Safe text content must remain intact
        for (final expected in const [
          'surf_id',
          'Heading',
          'Body',
          'BtnAction',
          'FieldLabel: FieldVal',
          'CheckLabel',
          'PickLabel (OptA)',
          'SlideLabel: 50 (0..100)',
          'DateLabel: 2026-11-15',
          'flight_icon',
          'ImgDesc (https://example.com/a.png)',
          'https://example.com/v.mp4',
          'AudDesc (https://example.com/a.mp3)',
          '[List (horizontal, template: tpl_id @ /items)]',
          'TabOne | TabTwo',
          'OpenModal',
          'CustomWidget (id: u_id)',
          'fKey',
          'fVal',
        ]) {
          expect(output, contains(expected));
        }
      });
    });
  });
}
