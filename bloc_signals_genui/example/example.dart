// Example CLI script prints streaming A2UI state updates to stdout.
// ignore_for_file: avoid_print

import 'dart:async';

import 'package:bloc_signals_genui/bloc_signals_genui.dart';

void main() async {
  const basicCatalogId =
      'https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json';

  // 1. Instantiate the A2UI surface state machine with bounded retention
  late final A2uiSurfaceBloc bloc;
  bloc = A2uiSurfaceBloc(
    maxSurfaces: 5,
    maxResponseHistory: 50,
    outboundListener: (message) {
      // Loopback mock responder for outbound callAgentFunction RPC envelopes
      if (message is CallAgentFunctionMessage) {
        bloc.add(
          ProcessMessage(
            AgentFunctionResponseMessage(
              version: 'v1.0',
              response: A2uiFunctionResponse.value(
                message.functionCallId,
                'Verified Developer Badge',
              ),
            ),
          ),
        );
      }
    },
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

  // 4. Ingest a streaming sequence of A2UI v0.9 BasicCatalog wire messages
  // with ChildList template expansion and CheckRule validation
  final stream = Stream<Map<String, dynamic>>.fromIterable([
    {
      'version': 'v0.9',
      'createSurface': {
        'surfaceId': 'profile_editor',
        'catalogId': basicCatalogId,
      },
    },
    {
      'version': 'v0.9',
      'updateDataModel': {
        'surfaceId': 'profile_editor',
        'path': '/',
        'value': {
          'user': {
            'name': '',
            'role': ['Maintainer'],
            'notifications': true,
          },
          'skills': [
            {'title': 'Dart 3.5+'},
            {'title': 'BlocSignal'},
          ],
        },
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
            'children': [
              'header_txt',
              'name_input',
              'role_picker',
              'notify_check',
              'skills_list',
              'save_btn',
            ],
          },
          {
            'id': 'header_txt',
            'component': 'Text',
            'variant': 'h2',
            'text': 'Edit Developer Profile',
          },
          {
            'id': 'name_input',
            'component': 'TextField',
            'label': 'Display Name',
            'value': {'path': '/user/name'},
            'checks': [
              {
                'condition': {
                  'call': 'required',
                  'args': {
                    'value': {'path': '/user/name'},
                  },
                },
                'message': 'Display name is required',
              },
            ],
          },
          {
            'id': 'role_picker',
            'component': 'ChoicePicker',
            'label': 'Team Role',
            'variant': 'mutuallyExclusive',
            'options': [
              {'label': 'Contributor', 'value': 'Contributor'},
              {'label': 'Maintainer', 'value': 'Maintainer'},
            ],
            'value': {'path': '/user/role'},
          },
          {
            'id': 'notify_check',
            'component': 'CheckBox',
            'label': 'Enable Release Notifications',
            'value': {'path': '/user/notifications'},
          },
          {
            'id': 'skills_list',
            'component': 'List',
            'children': {
              'componentId': 'skill_item',
              'path': '/skills',
            },
          },
          {
            'id': 'skill_item',
            'component': 'Text',
            'text': {'path': 'title'},
          },
          {
            'id': 'save_btn',
            'component': 'Button',
            'child': 'save_label',
            'checks': [
              {
                'condition': {
                  'call': 'required',
                  'args': {
                    'value': {'path': '/user/name'},
                  },
                },
                'message': 'Display name is required',
              },
            ],
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

  // 5. Inspect NodeResolver template expansion over /skills
  final ready = bloc.value as SurfaceReady;
  final resolver = NodeResolver<ComponentApi>(ready.surface);
  print('Resolved root node state: ${resolver.rootNode.value?.state}');
  resolver.dispose();

  // 6. Mutate form state synchronously in 0ms
  bloc.add(
    const UpdateFormField(
      path: '/user/name',
      value: 'Randal L. Schwartz',
    ),
  );

  // 7. Invoke bidirectional RPC on the agent
  final badge = await bloc.callAgentFunction(
    'profile_editor',
    FunctionCall(
      call: 'verifyDeveloperBadge',
      args: const {'handle': '@RandalSchwartz'},
    ),
  );
  print('Agent RPC result: $badge');

  // 8. Submit an interactive user action back to the agent
  bloc.add(
    const SubmitAction(
      actionName: 'save_profile',
      sourceComponentId: 'save_btn',
      context: {'source': 'cli_example'},
    ),
  );
  await responseCompleter.future;

  // 9. Complete the submission lifecycle
  bloc.add(const CompleteAction(surfaceId: 'profile_editor'));

  await responseSub.cancel();
  await bloc.close();
}
