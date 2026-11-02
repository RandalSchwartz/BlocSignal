import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import 'playground_cubit.dart';
import 'playground_scenarios.dart';

/// Interactive JSON editor and scenario controller for the A2UI playground.
class const PlaygroundEditor({
  required final PlaygroundCubit cubit,
  required final PlaygroundState state,
  super.key,
}) extends StatelessComponent {
  @override
  Component build(BuildContext context) {
    return div(classes: 'playground-pane playground-editor-pane', [
      div(classes: 'pane-header', [
        div(classes: 'pane-title-group', [
          span(classes: 'pane-icon', [Component.text('📝')]),
          h2(classes: 'pane-title', [Component.text('A2UI Message Editor')]),
        ]),
        span(classes: 'pane-badge', [
          Component.text(state.isStreaming ? 'Streaming...' : 'Ready'),
        ]),
      ]),

      // Scenario Selector & Description
      div(classes: 'scenario-selector-bar', [
        label(classes: 'scenario-label', htmlFor: 'scenario-select', [
          Component.text('Preloaded Scenario:'),
        ]),
        select(
          id: 'scenario-select',
          classes: 'scenario-dropdown',
          onChange: (dynamic value) {
            final valStr = value is List
                ? (value.isNotEmpty ? value.first.toString() : '')
                : value.toString();
            final match = PlaygroundScenarios.all.firstWhere(
              (s) => s.id == valStr,
              orElse: () => PlaygroundScenarios.flightBooking,
            );
            cubit.selectScenario(match);
          },
          [
            for (final scenario in PlaygroundScenarios.all)
              option(
                value: scenario.id,
                selected: scenario.id == state.selectedScenario.id,
                [Component.text(scenario.name)],
              ),
          ],
        ),
      ]),
      p(classes: 'scenario-desc', [
        Component.text(state.selectedScenario.description),
      ]),

      // Syntax Error Banner
      if (state.parseError != null)
        div(classes: 'editor-error-banner', [
          span(classes: 'error-icon', [Component.text('⚠️ ')]),
          span(classes: 'error-text', [Component.text(state.parseError!)]),
        ]),

      // JSON Code Editor Textarea
      div(classes: 'editor-textarea-container', [
        textarea(
          classes: 'editor-textarea',
          attributes: {
            'aria-label': 'A2UI JSON Messages',
            'rows': '16',
            'spellcheck': 'false',
          },
          onInput: (newVal) => cubit.updateJson(newVal),
          [Component.text(state.rawJson)],
        ),
      ]),

      // Action Controls Bar
      div(classes: 'editor-actions-bar', [
        button(
          classes: 'btn btn-primary btn-render',
          onClick: () => cubit.renderInstant(),
          [Component.text('Render Instant ⚡')],
        ),
        if (!state.isStreaming)
          button(
            classes: 'btn btn-secondary btn-stream',
            onClick: () => cubit.startStreaming(),
            [Component.text('Stream Chunks 🌊')],
          )
        else
          button(
            classes: 'btn btn-danger btn-cancel',
            onClick: () => cubit.cancelStreaming(),
            [Component.text('Cancel Stream ⏹')],
          ),
        button(
          classes: 'btn btn-ghost btn-reset',
          onClick: () => cubit.reset(),
          [Component.text('Reset 🔄')],
        ),
      ]),
    ]);
  }
}
