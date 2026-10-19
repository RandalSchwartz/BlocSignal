import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:bloc_signals_genui/bloc_signals_genui.dart';
import 'package:bloc_signals_genui_flutter/bloc_signals_genui_flutter.dart';
import 'package:flutter/material.dart';

void main() {
  final surfaceBloc = A2uiSurfaceBloc(maxSurfaces: 5)
    ..add(
      const ProcessJsonMessage({
        'version': 'v0.9',
        'createSurface': {
          'surfaceId': 'welcome_card',
          'catalogId':
              'https://a2ui.org/specification/v0_9/catalogs/minimal/minimal_catalog.json',
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
              'children': ['title_txt', 'name_field', 'submit_btn'],
            },
            {
              'id': 'title_txt',
              'component': 'Text',
              'text': 'Welcome to BlocSignal GenUI',
            },
            {
              'id': 'name_field',
              'component': 'TextField',
              'label': 'Your Name',
              'value': {'path': '/user/name'},
            },
            {
              'id': 'submit_btn',
              'component': 'Button',
              'child': 'btn_label',
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
            child: A2uiSurfaceView(
              bloc: surfaceBloc,
              catalog: catalog,
            ),
          ),
        ),
      ),
    );
  }
}
