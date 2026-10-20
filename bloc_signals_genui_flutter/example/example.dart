import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:bloc_signals_genui/bloc_signals_genui.dart';
import 'package:bloc_signals_genui_flutter/bloc_signals_genui_flutter.dart';
import 'package:flutter/material.dart';

void main() {
  const basicCatalogId =
      'https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json';

  final surfaceBloc = A2uiSurfaceBloc(maxSurfaces: 5)
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
              'tier': ['Pro'],
              'subscribeUpdates': true,
            },
            'features': [
              {'label': '0ms Synchronous Signal Reactivity'},
              {'label': 'NodeResolver ChildList Templates'},
              {'label': 'CheckRule Form Validation'},
            ],
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
                'features_list',
                'name_field',
                'tier_picker',
                'updates_checkbox',
                'submit_btn',
              ],
            },
            {
              'id': 'title_txt',
              'component': 'Text',
              'variant': 'h2',
              'text': 'Welcome to BlocSignal GenUI',
            },
            {
              'id': 'features_list',
              'component': 'List',
              'children': {
                'componentId': 'feature_row',
                'path': '/features',
              },
            },
            {
              'id': 'feature_row',
              'component': 'Text',
              'variant': 'caption',
              'text': {'path': 'label'},
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
              'id': 'tier_picker',
              'component': 'ChoicePicker',
              'label': 'Plan Tier',
              'variant': 'mutuallyExclusive',
              'displayStyle': 'chips',
              'options': [
                {'label': 'Starter', 'value': 'Starter'},
                {'label': 'Pro', 'value': 'Pro'},
                {'label': 'Enterprise', 'value': 'Enterprise'},
              ],
              'value': {'path': '/user/tier'},
            },
            {
              'id': 'updates_checkbox',
              'component': 'CheckBox',
              'label': 'Subscribe to release notes',
              'value': {'path': '/user/subscribeUpdates'},
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

  runApp(GenUiExampleApp(surfaceBloc: surfaceBloc));
}

/// Example Flutter application rendering an [A2uiSurfaceView] with
/// [A2uiFlutterCatalog].
class GenUiExampleApp extends StatelessWidget {
  /// Creates a [GenUiExampleApp].
  const GenUiExampleApp({
    required this.surfaceBloc,
    super.key,
  });

  /// The [A2uiSurfaceBloc] managing generative surfaces.
  final A2uiSurfaceBloc surfaceBloc;

  @override
  Widget build(BuildContext context) {
    final catalog = A2uiFlutterCatalog.standard();

    return BlocSignalProvider<A2uiSurfaceBloc>.value(
      value: surfaceBloc,
      child: MaterialApp(
        title: 'BlocSignal GenUI Demo',
        home: Scaffold(
          appBar: AppBar(title: const Text('A2UI Surface View')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: A2uiSurfaceView(
                bloc: surfaceBloc,
                catalog: catalog,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
