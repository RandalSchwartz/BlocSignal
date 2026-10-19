// Example CLI script prints streaming A2UI state updates to stdout.
// ignore_for_file: avoid_print

import 'dart:async';

import 'package:bloc_signals_genui/bloc_signals_genui.dart';

void main() async {
  // 1. Instantiate the A2UI surface state machine with bounded retention
  final bloc = A2uiSurfaceBloc(
    maxSurfaces: 5,
    maxResponseHistory: 50,
  );

  // 2. Subscribe to action responses for agent tool execution
  final responseCompleter = Completer<void>();
  final responseSub = bloc.actionResponses.listen((response) {
    print('Agent tool payload: ${response.toToolResult()}');
    if (!responseCompleter.isCompleted) {
      responseCompleter.complete();
    }
  });

  // 3. Observe state transitions and signal when SurfaceReady is reached
  final readyCompleter = Completer<void>();
  final disposeStateListener = bloc.state.subscribe((state) {
    if (state is SurfaceReady && !readyCompleter.isCompleted) {
      readyCompleter.complete();
    }
  });

  // 4. Ingest a streaming sequence of A2UI wire messages
  final stream = Stream<Map<String, dynamic>>.fromIterable([
    {
      'version': 'v0.9',
      'createSurface': {
        'surfaceId': 'profile_editor',
        'catalogId':
            'https://a2ui.org/specification/v0_9/catalogs/minimal/minimal_catalog.json',
      },
    },
    {
      'version': 'v0.9',
      'updateComponents': {
        'surfaceId': 'profile_editor',
        'components': [
          {
            'id': 'root',
            'component': 'Column',
            'children': ['header_txt', 'name_input', 'save_btn'],
          },
          {
            'id': 'header_txt',
            'component': 'Text',
            'text': 'Edit Developer Profile',
          },
          {
            'id': 'name_input',
            'component': 'TextField',
            'label': 'Display Name',
            'value': {'path': '/user/name'},
          },
          {
            'id': 'save_btn',
            'component': 'Button',
            'child': 'save_label',
            'action': {
              'event': {'name': 'save_profile'},
            },
          },
          {
            'id': 'save_label',
            'component': 'Text',
            'text': 'Save',
          },
        ],
      },
    },
  ]);

  bloc.add(IngestStream(stream));

  // Wait for the stream to finish and transition to SurfaceReady
  await readyCompleter.future;
  disposeStateListener();
  print('Active surface: ${bloc.activeSurfaceIdValue}');

  // 5. Mutate form state synchronously in 0ms
  bloc.add(
    const UpdateFormField(
      path: '/user/name',
      value: 'Randal L. Schwartz',
    ),
  );

  // 6. Submit an interactive user action back to the agent
  bloc.add(
    const SubmitAction(
      actionName: 'save_profile',
      sourceComponentId: 'save_btn',
      context: {'source': 'cli_example'},
    ),
  );
  await responseCompleter.future;

  // 7. Complete the submission lifecycle
  bloc.add(const CompleteAction(surfaceId: 'profile_editor'));

  await responseSub.cancel();
  await bloc.close();
}
