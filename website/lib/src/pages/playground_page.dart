import 'package:bloc_signals_genui/bloc_signals_genui.dart';
import 'package:bloc_signals_genui_jaspr/bloc_signals_genui_jaspr.dart';
import 'package:bloc_signals_jaspr/bloc_signals_jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../components/footer.dart';
import '../components/navbar.dart';
import '../components/playground/playground_cubit.dart';
import '../components/playground/playground_editor.dart';
import '../components/playground/playground_inspector.dart';
import '../models/app_route.dart';

/// Full-page interactive Generative UI (A2UI) Playground for blocsignal.dev.
class const PlaygroundPage({super.key}) extends StatefulComponent {
  @override
  State<PlaygroundPage> createState() => _PlaygroundPageState();
}

class _PlaygroundPageState() extends State<PlaygroundPage> {
  late final PlaygroundCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = PlaygroundCubit();
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    final surfaceBloc = _cubit.surfaceBloc;

    return div(classes: 'app-root playground-root', [
      const Navbar(currentRoute: AppRoute.playground),

      main_(classes: 'playground-main', [
        // Hero Header
        header(classes: 'playground-hero', [
          div(classes: 'container', [
            div(classes: 'hero-badge', [
              Component.text('🤖 Google A2UI v0.9 • Jaspr Web Components'),
            ]),
            h1(classes: 'hero-title', [
              Component.text('Live Generative UI Playground'),
            ]),
            p(classes: 'hero-lead', [
              Component.text(
                'Stream, parse, and render declarative A2UI JSON components in real-time. '
                'Powered synchronously by bloc_signals_genui state machine and bloc_signals_genui_jaspr HTML DOM catalog.',
              ),
            ]),
          ]),
        ]),

        // 3-Pane Workbench
        div(classes: 'container playground-workbench', [
          // Left Pane: JSON Editor & Streaming Controls
          BlocSignalBuilder<PlaygroundCubit, PlaygroundState>(
            bloc: _cubit,
            builder: (context, state) =>
                PlaygroundEditor(cubit: _cubit, state: state),
          ),

          // Center Pane: Live DOM Surface Preview
          div(classes: 'playground-pane playground-preview-pane', [
            div(classes: 'pane-header', [
              div(classes: 'pane-title-group', [
                span(classes: 'pane-icon', [Component.text('🖥️')]),
                h2(classes: 'pane-title', [
                  Component.text('DOM Surface Preview'),
                ]),
              ]),
              BlocSignalBuilder<A2uiSurfaceBloc, A2uiSurfaceState>(
                bloc: surfaceBloc,
                builder: (context, surfaceState) {
                  final availableSurfaces = surfaceBloc.availableSurfaceIds;
                  return div(classes: 'preview-header-meta', [
                    if (availableSurfaces.length > 1) ...[
                      select(
                        classes: 'surface-select-dropdown',
                        onChange: (dynamic selectedVal) {
                          final id = selectedVal is List
                              ? (selectedVal.isNotEmpty
                                    ? selectedVal.first.toString()
                                    : '')
                              : selectedVal.toString();
                          if (id.isNotEmpty) {
                            _cubit.selectSurface(id);
                          }
                        },
                        [
                          for (final surfId in availableSurfaces)
                            option(
                              value: surfId,
                              selected: surfId == surfaceState.surfaceId,
                              [Component.text('Surface: $surfId')],
                            ),
                        ],
                      ),
                    ] else if (surfaceState.surfaceId != null) ...[
                      span(classes: 'surface-id-pill', [
                        Component.text('ID: ${surfaceState.surfaceId}'),
                      ]),
                    ],
                  ]);
                },
              ),
            ]),

            // Interactive Surface Viewport
            div(classes: 'surface-viewport-frame', [
              div(classes: 'browser-mock-chrome', [
                div(classes: 'mock-dots', [
                  span(classes: 'dot dot-red', []),
                  span(classes: 'dot dot-yellow', []),
                  span(classes: 'dot dot-green', []),
                ]),
                BlocSignalBuilder<A2uiSurfaceBloc, A2uiSurfaceState>(
                  bloc: surfaceBloc,
                  builder: (context, surfaceState) => span(
                    classes: 'mock-address',
                    [
                      Component.text(
                        'a2ui://surface/${surfaceState.surfaceId ?? "active"}',
                      ),
                    ],
                  ),
                ),
              ]),
              div(classes: 'surface-content-area', [
                A2uiSurfaceView(
                  bloc: surfaceBloc,
                  catalog: A2uiJasprCatalog.standard(),
                  placeholderBuilder: (ctx) =>
                      div(classes: 'surface-empty-state', [
                        p([
                          Component.text(
                            'No surface created. Click "Render Instant" or "Stream Chunks" to begin.',
                          ),
                        ]),
                      ]),
                  streamingBuilder: (ctx, streaming) =>
                      div(classes: 'surface-streaming-state', [
                        div(classes: 'streaming-spinner', []),
                        p([
                          Component.text(
                            'Ingesting chunk ${streaming.messageCount}...',
                          ),
                        ]),
                      ]),
                  errorBuilder: (ctx, err) =>
                      div(classes: 'surface-error-alert', [
                        strong([Component.text('Surface Error: ')]),
                        Component.text(err.error.toString()),
                      ]),
                ),
              ]),
            ]),
          ]),

          // Right Pane: State & Action Inspector
          PlaygroundInspector(cubit: _cubit),
        ]),
      ]),

      const Footer(),
    ]);
  }
}
