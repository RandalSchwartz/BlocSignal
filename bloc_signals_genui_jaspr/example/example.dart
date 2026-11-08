import 'package:bloc_signals_genui/bloc_signals_genui.dart';
import 'package:bloc_signals_genui_jaspr/bloc_signals_genui_jaspr.dart';
import 'package:bloc_signals_jaspr/bloc_signals_jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// Builds a pre-populated [A2uiSurfaceBloc] demonstrating A2UI v0.9 surface
/// creation, data model initialization, and interactive component rendering.
A2uiSurfaceBloc createExampleSurfaceBloc() {
  const basicCatalogId =
      'https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json';

  return A2uiSurfaceBloc(maxSurfaces: 5)
    ..add(
      const ProcessJsonMessage({
        'version': 'v0.9',
        'createSurface': {
          'surfaceId': 'welcome_card',
          'catalogId': basicCatalogId,
        },
      }),
    )
    ..add(
      const ProcessJsonMessage({
        'version': 'v0.9',
        'updateDataModel': {
          'surfaceId': 'welcome_card',
          'path': '/',
          'value': {
            'user': {
              'name': 'Randal L. Schwartz',
            },
          },
        },
      }),
    )
    ..add(
      const ProcessJsonMessage({
        'version': 'v0.9',
        'updateComponents': {
          'surfaceId': 'welcome_card',
          'components': [
            {
              'id': 'root',
              'component': 'Card',
              'child': 'content_col',
            },
            {
              'id': 'content_col',
              'component': 'Column',
              'align': 'stretch',
              'children': [
                'title_txt',
                'divider_1',
                'name_field',
                'submit_btn',
              ],
            },
            {
              'id': 'title_txt',
              'component': 'Text',
              'variant': 'h2',
              'text': 'Welcome to BlocSignal GenUI for Jaspr',
            },
            {
              'id': 'divider_1',
              'component': 'Divider',
            },
            {
              'id': 'name_field',
              'component': 'TextField',
              'label': 'Your Name',
              'value': {'path': '/user/name'},
              'checks': [
                {
                  'condition': {
                    'call': 'required',
                    'args': {
                      'value': {'path': '/user/name'},
                    },
                  },
                  'message': 'Name is required',
                },
              ],
            },
            {
              'id': 'submit_btn',
              'component': 'Button',
              'child': 'btn_label',
              'checks': [
                {
                  'condition': {
                    'call': 'required',
                    'args': {
                      'value': {'path': '/user/name'},
                    },
                  },
                  'message': 'Name is required',
                },
              ],
              'action': {
                'event': {'name': 'submit_greeting'},
              },
            },
            {
              'id': 'btn_label',
              'component': 'Text',
              'text': 'Continue',
            },
          ],
        },
      }),
    );
}

/// Example Jaspr web component rendering an [A2uiSurfaceView] with
/// [A2uiJasprCatalog].
class GenUiJasprExampleApp extends StatelessComponent {
  /// Creates a [GenUiJasprExampleApp].
  const GenUiJasprExampleApp({
    required this.surfaceBloc,
    super.key,
  });

  /// The [A2uiSurfaceBloc] managing generative surfaces.
  final A2uiSurfaceBloc surfaceBloc;

  @override
  Component build(BuildContext context) {
    final catalog = A2uiJasprCatalog.standard();

    return BlocSignalProvider<A2uiSurfaceBloc>.value(
      value: surfaceBloc,
      child: div(
        classes: 'genui-demo-shell',
        [
          const h1([Component.text('A2UI Jaspr Surface View')]),
          A2uiSurfaceView(
            bloc: surfaceBloc,
            catalog: catalog,
          ),
        ],
      ),
    );
  }
}
