import 'package:blocsignal_website/src/models/pub_api_registry.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../docs_callout.dart';
import '../docs_code_block.dart';
import '../docs_toc.dart';

/// Documentation page covering the pure-Dart A2UI state machine in bloc_signals_genui.
class const DocsPkgGenuiPage({super.key}) extends StatelessComponent {
  static const List<TocHeading> headings = [
    TocHeading(title: 'Overview & Installation', anchor: 'overview-install'),
    TocHeading(title: 'A2uiSurfaceBloc State Machine', anchor: 'surface-bloc'),
    TocHeading(
      title: 'Streaming Ingestion & Concurrency',
      anchor: 'streaming-ingestion',
    ),
    TocHeading(
      title: '0ms Form Mutations & Action Responses',
      anchor: 'form-actions',
    ),
    TocHeading(
      title: 'Multi-Surface Navigation & LRU Retention',
      anchor: 'multi-surface',
    ),
  ];

  @override
  Component build(BuildContext context) {
    return article(classes: 'docs-article', [
      header(classes: 'docs-article-header', [
        div(classes: 'docs-badge', [Component.text('📦 Satellite Packages')]),
        h1([Component.text('bloc_signals_genui')]),
        p(classes: 'docs-lead', [
          Component.text(
            'Pure-Dart A2UI (Agent-to-User Interface) streaming state machine and Generative UI runtime adapter with 0ms synchronous form state and bounded surface retention.',
          ),
        ]),
      ]),

      // 1. Overview & Installation
      section(id: 'overview-install', classes: 'docs-section', [
        h2([Component.text('Overview & Installation')]),
        p([
          Component.text(
            'The bloc_signals_genui package bridges Google\'s A2UI v0.9 and v1.0 declarative UI protocol with BlocSignal reactive architecture. '
            'Because it is pure Dart with zero Flutter dependency, ',
          ),
          apiLink(DocSymbol.a2uiSurfaceBloc),
          Component.text(
            ' runs identically across CLI tools, backend orchestrators, Jaspr web apps, and Flutter clients.',
          ),
        ]),
        const DocsCodeBlock(
          title: 'terminal',
          language: 'bash',
          code: 'dart pub add bloc_signals_genui bloc_signals',
        ),
        const DocsCodeBlock(
          title: 'pubspec.yaml',
          language: 'yaml',
          code: '''
dependencies:
  bloc_signals: ^1.7.0
  bloc_signals_genui: ^0.1.2
  a2ui_core: ^0.3.0
''',
        ),
      ]),

      // 2. A2uiSurfaceBloc State Machine
      section(id: 'surface-bloc', classes: 'docs-section', [
        h2([Component.text('A2uiSurfaceBloc State Machine')]),
        p([
          apiLink(DocSymbol.a2uiSurfaceBloc),
          Component.text(' registers '),
          apiLink(DocSymbol.standardCatalog),
          Component.text(
            ', BasicCatalog.v0_9(), and BasicCatalog.v1_0() out of the box and models the surface lifecycle through the sealed ',
          ),
          apiLink(DocSymbol.a2uiSurfaceState),
          Component.text(' hierarchy and '),
          apiLink(DocSymbol.a2uiSurfaceEvent),
          Component.text(' envelopes:'),
        ]),
        ul([
          li([
            strong([
              code([Component.text('SurfaceInitial')]),
            ]),
            Component.text(
              ': Initial state before any stream connection or after all surfaces are closed.',
            ),
          ]),
          li([
            strong([
              code([Component.text('SurfaceStreaming')]),
            ]),
            Component.text(
              ': Chunks are actively arriving or a surface has been created while awaiting initial components.',
            ),
          ]),
          li([
            strong([
              code([Component.text('SurfaceReady')]),
            ]),
            Component.text(
              ': Surface has populated components and is ready for user interaction, carrying a per-surface monotonic version counter.',
            ),
          ]),
          li([
            strong([
              code([Component.text('SurfaceSubmitting')]),
            ]),
            Component.text(
              ': User triggered an action button; holds the pending action name and payload.',
            ),
          ]),
          li([
            strong([
              code([Component.text('SurfaceError')]),
            ]),
            Component.text(
              ': Stream parsing error, missing surface target, or network failure routed through onError().',
            ),
          ]),
        ]),
      ]),

      // 3. Streaming Ingestion & Concurrency
      section(id: 'streaming-ingestion', classes: 'docs-section', [
        h2([Component.text('Streaming Ingestion & Concurrency')]),
        p([
          Component.text(
            'Dispatch IngestStream to consume SSE or WebSocket JSON message streams from an LLM agent. '
            'In-flight streams are protected by the restartable() concurrency transformer so any new user prompt immediately cancels stale streams:',
          ),
        ]),
        const DocsCodeBlock(
          title: 'lib/agent_session.dart',
          language: 'dart',
          code: r'''
import 'dart:async';
import 'package:bloc_signals_genui/bloc_signals_genui.dart';

void runAgentSession(Stream<Map<String, dynamic>> wireStream) {
  final surfaceBloc = A2uiSurfaceBloc(
    maxSurfaces: 10,
    maxResponseHistory: 100,
  );

  surfaceBloc.state.subscribe((state) {
    switch (state) {
      case SurfaceInitial():
        print('Waiting for agent stream...');
      case SurfaceStreaming(:final messageCount):
        print('Streaming ($messageCount chunks)...');
      case SurfaceReady(:final surfaceId, :final version):
        print('Surface $surfaceId ready (v$version)');
      case SurfaceSubmitting(:final actionName):
        print('Submitting $actionName...');
      case SurfaceError(:final error):
        print('Surface error: $error');
    }
  });

  surfaceBloc.add(IngestStream(wireStream));
}''',
        ),
      ]),

      // 4. 0ms Form Mutations & Action Responses
      section(id: 'form-actions', classes: 'docs-section', [
        h2([Component.text('0ms Form Mutations & Action Responses')]),
        p([
          Component.text(
            'Form input changes dispatch UpdateFormField to mutate the underlying DataModel synchronously in 0ms. '
            'When the user triggers an action via SubmitAction, validated form values are packaged into a structured ',
          ),
          apiLink(DocSymbol.a2uiActionResponse),
          Component.text(' emitted on actionResponses:'),
        ]),
        const DocsCodeBlock(
          title: 'lib/form_submission.dart',
          language: 'dart',
          code: r'''
// 1. Listen for validated user action responses to forward to your LLM tool handler:
surfaceBloc.actionResponses.listen((A2uiActionResponse response) {
  final name = response.getFormValue<String>('/user/name');
  final toolPayload = response.toToolResult();
  print('Forwarding action ${response.actionName} for $name: $toolPayload');
});

// 2. Update form fields synchronously in the current frame:
surfaceBloc.add(
  const UpdateFormField(
    path: '/user/name',
    value: 'Randal L. Schwartz',
  ),
);

// 3. Submit action and complete or cancel when the agent responds:
surfaceBloc.add(
  const SubmitAction(
    actionName: 'save_profile',
    sourceComponentId: 'save_btn',
  ),
);
surfaceBloc.add(const CompleteAction());''',
        ),
        const DocsCallout(
          type: CalloutType.warning,
          title: 'Zero-Chunk Stream Rollback (SCAR-GENUI-3)',
          children: [
            p([
              Component.text(
                'In conversational LLM APIs (for example Gemini or Firebase Genkit), turns strictly alternate between user and model. '
                'If you optimistically append a user turn before calling IngestStream and the stream fails with zero chunks, prune that optimistic user turn before retrying.',
              ),
            ]),
          ],
        ),
      ]),

      // 5. Multi-Surface Navigation & LRU Retention
      section(id: 'multi-surface', classes: 'docs-section', [
        h2([Component.text('Multi-Surface Navigation & LRU Retention')]),
        p([
          apiLink(DocSymbol.a2uiSurfaceBloc),
          Component.text(
            ' decouples active navigation coordinates (activeSurfaceId) from per-surface content revisions. '
            'Dispatch SelectSurface to switch the active surface without bumping component versions, or CloseSurface to evict a surface and promote the most-recently-accessed survivor.',
          ),
        ]),
      ]),
    ]);
  }
}
