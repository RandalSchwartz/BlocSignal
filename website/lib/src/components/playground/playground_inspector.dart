import 'dart:convert';

import 'package:bloc_signals_genui/bloc_signals_genui.dart';
import 'package:bloc_signals_jaspr/bloc_signals_jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import 'playground_cubit.dart';

/// Real-time state inspector and action event logger for the A2UI playground.
class const PlaygroundInspector({
  required final PlaygroundCubit cubit,
  final PlaygroundState? state,
  super.key,
}) extends StatelessComponent {
  @override
  Component build(BuildContext context) {
    final surfaceBloc = cubit.surfaceBloc;

    return div(classes: 'playground-pane playground-inspector-pane', [
      div(classes: 'pane-header', [
        div(classes: 'pane-title-group', [
          span(classes: 'pane-icon', [Component.text('🔍')]),
          h2(classes: 'pane-title', [
            Component.text('State & Action Inspector'),
          ]),
        ]),
        BlocSignalBuilder<A2uiSurfaceBloc, A2uiSurfaceState>(
          bloc: surfaceBloc,
          builder: (context, surfaceState) => span(
            classes:
                'state-status-badge ${surfaceState.runtimeType.toString().toLowerCase()}',
            [Component.text(surfaceState.runtimeType.toString())],
          ),
        ),
      ]),

      // Live SurfaceBloc State Snapshot
      BlocSignalBuilder<A2uiSurfaceBloc, A2uiSurfaceState>(
        bloc: surfaceBloc,
        builder: (context, surfaceState) => div(classes: 'inspector-section', [
          h3(classes: 'section-heading', [Component.text('SurfaceBloc State')]),
          div(classes: 'state-details-card', [
            div(classes: 'state-meta-row', [
              span(classes: 'meta-key', [Component.text('Active Surface: ')]),
              span(classes: 'meta-val', [
                Component.text(surfaceState.surfaceId ?? 'none'),
              ]),
            ]),
            if (surfaceState is SurfaceReady) ...[
              div(classes: 'state-meta-row', [
                span(classes: 'meta-key', [
                  Component.text('Revision Version: '),
                ]),
                span(classes: 'meta-val', [
                  Component.text('v${surfaceState.version}'),
                ]),
              ]),
              div(classes: 'state-meta-row', [
                span(classes: 'meta-key', [
                  Component.text('Catalog Validation: '),
                ]),
                span(
                  classes:
                      'meta-val ${surfaceState.isValid ? "text-success" : "text-error"}',
                  [
                    Component.text(
                      surfaceState.isValid ? 'Valid ✅' : 'Invalid ❌',
                    ),
                  ],
                ),
              ]),
              if (surfaceState.formValues.isNotEmpty) ...[
                div(classes: 'form-values-block', [
                  span(classes: 'meta-key', [Component.text('Form Values:')]),
                  pre(classes: 'inspector-code-snippet', [
                    Component.text(
                      const JsonEncoder.withIndent('  ')
                          .convert(surfaceState.formValues),
                    ),
                  ]),
                ]),
              ],
            ] else if (surfaceState is SurfaceStreaming) ...[
              div(classes: 'state-meta-row', [
                span(classes: 'meta-key', [
                  Component.text('Messages Processed: '),
                ]),
                span(classes: 'meta-val', [
                  Component.text('${surfaceState.messageCount}'),
                ]),
              ]),
            ] else if (surfaceState is SurfaceError) ...[
              div(classes: 'state-meta-row error-row', [
                span(classes: 'meta-key', [Component.text('Error: ')]),
                span(classes: 'meta-val text-error', [
                  Component.text(surfaceState.error.toString()),
                ]),
              ]),
            ],
          ]),
        ]),
      ),

      // Real-time Action Dispatch Log
      BlocSignalBuilder<PlaygroundCubit, PlaygroundState>(
        bloc: cubit,
        buildWhen: (previous, current) =>
            previous.actionLog != current.actionLog,
        builder: (context, pState) =>
            div(classes: 'inspector-section action-log-section', [
              div(classes: 'action-log-header', [
                h3(classes: 'section-heading', [
                  Component.text('Action Dispatch Log'),
                ]),
                span(classes: 'action-count-badge', [
                  Component.text('${pState.actionLog.length} events'),
                ]),
              ]),

              if (pState.actionLog.isEmpty)
                div(classes: 'empty-log-card', [
                  p([
                    Component.text(
                      'No actions dispatched yet. Click buttons or submit forms in the surface preview to trigger A2UI action events.',
                    ),
                  ]),
                ])
              else
                div(classes: 'action-log-list', [
                  for (final entry in pState.actionLog)
                    div(classes: 'action-entry-card', [
                      div(classes: 'action-entry-header', [
                        span(classes: 'action-entry-name', [
                          Component.text('⚡ ${entry.actionName}'),
                        ]),
                        span(classes: 'action-entry-surface', [
                          Component.text(entry.surfaceId),
                        ]),
                      ]),
                      if (entry.sourceComponentId != null)
                        div(classes: 'action-entry-sub', [
                          Component.text('Trigger: ${entry.sourceComponentId}'),
                        ]),
                      if (entry.payload.isNotEmpty)
                        pre(classes: 'action-payload-json', [
                          Component.text(
                            const JsonEncoder.withIndent('  ')
                                .convert(entry.payload),
                          ),
                        ]),
                    ]),
                ]),
            ]),
      ),
    ]);
  }
}
