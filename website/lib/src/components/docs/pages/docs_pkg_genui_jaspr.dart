import 'package:blocsignal_website/src/models/pub_api_registry.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../docs_callout.dart';
import '../docs_code_block.dart';
import '../docs_toc.dart';

/// Documentation page covering Jaspr web A2UI rendering in bloc_signals_genui_jaspr.
class const DocsPkgGenuiJasprPage({super.key}) extends StatelessComponent {
  static const List<TocHeading> headings = [
    TocHeading(title: 'Overview & Installation', anchor: 'overview-install'),
    TocHeading(title: 'A2uiSurfaceView DOM Component', anchor: 'surface-view'),
    TocHeading(
      title: 'Standard Component Suite',
      anchor: 'standard-components',
    ),
    TocHeading(
      title: 'Custom Component Handlers & A2uiJasprCatalog',
      anchor: 'custom-components',
    ),
    TocHeading(
      title: 'Synchronous Form Mutations & Action Dispatch',
      anchor: 'form-actions',
    ),
    TocHeading(title: 'Styling & Theme Integration', anchor: 'styling-themes'),
  ];

  @override
  Component build(BuildContext context) {
    return article(classes: 'docs-article', [
      header(classes: 'docs-article-header', [
        div(classes: 'docs-badge', [Component.text('📦 Satellite Packages')]),
        h1([Component.text('bloc_signals_genui_jaspr')]),
        p(classes: 'docs-lead', [
          Component.text(
            'Declarative Jaspr web components, HTML DOM catalog adapters, and reactive surface views for Google\'s A2UI Generative UI protocol.',
          ),
        ]),
      ]),

      // 1. Overview & Installation
      section(id: 'overview-install', classes: 'docs-section', [
        h2([Component.text('Overview & Installation')]),
        p([
          Component.text('The bloc_signals_genui_jaspr package connects '),
          apiLink(DocSymbol.a2uiSurfaceBloc),
          Component.text(
            ' to the HTML DOM using Jaspr web components. It provides production-ready Web DOM renderers for standard A2UI components like Text, Button, Card, Column, Row, TextField, and Divider.',
          ),
        ]),
        const DocsCodeBlock(
          title: 'terminal',
          language: 'bash',
          code: 'dart pub add bloc_signals_genui bloc_signals_genui_jaspr',
        ),
        p([
          Component.text(
            'Add both the pure-Dart state machine (bloc_signals_genui) and the Jaspr DOM bindings (bloc_signals_genui_jaspr) to your web project dependencies.',
          ),
        ]),
      ]),

      // 2. A2uiSurfaceView DOM Component
      section(id: 'surface-view', classes: 'docs-section', [
        h2([Component.text('A2uiSurfaceView DOM Component')]),
        p([
          Component.text(
            'Mounting an A2UI surface in Jaspr requires only instantiating ',
          ),
          apiLink(DocSymbol.a2uiJasprSurfaceView),
          Component.text(' with an active surface bloc:'),
        ]),
        const DocsCodeBlock(
          title: 'surface_view_example.dart',
          language: 'dart',
          code: '''import 'package:bloc_signals_genui/bloc_signals_genui.dart';
import 'package:bloc_signals_genui_jaspr/bloc_signals_genui_jaspr.dart';
import 'package:jaspr/jaspr.dart';

Component buildSurface(A2uiSurfaceBloc bloc) {
  return A2uiSurfaceView(
    bloc: bloc,
    catalog: A2uiJasprCatalog.standard(),
  );
}''',
        ),
        p([
          Component.text(
            'A2uiSurfaceView automatically observes surface transitions and renders the appropriate UI: an empty placeholder for SurfaceInitial, a skeleton for SurfaceStreaming, and interactive HTML elements for SurfaceReady.',
          ),
        ]),
      ]),

      // 3. Standard Component Suite
      section(id: 'standard-components', classes: 'docs-section', [
        h2([Component.text('Standard Component Suite')]),
        p([
          Component.text(
            'The standard catalog includes DOM-native renderers for 7 core A2UI components:',
          ),
        ]),
        ul([
          li([
            strong([Component.text('Text: ')]),
            Component.text(
              'Semantic typography headers (h1-h5), caption, and body text.',
            ),
          ]),
          li([
            strong([Component.text('Button: ')]),
            Component.text(
              'Interactive actions with primary and borderless variants.',
            ),
          ]),
          li([
            strong([Component.text('Card: ')]),
            Component.text(
              'Containers with elevation box shadows, radius, and padding.',
            ),
          ]),
          li([
            strong([Component.text('Column & Row: ')]),
            Component.text(
              'Flexbox layout containers with alignment and distribution.',
            ),
          ]),
          li([
            strong([Component.text('TextField: ')]),
            Component.text(
              'Single-line and multi-line inputs with two-way data model synchronization.',
            ),
          ]),
          li([
            strong([Component.text('Divider: ')]),
            Component.text('Horizontal rule separating sections.'),
          ]),
        ]),
      ]),

      // 4. Custom Component Handlers & A2uiJasprCatalog
      section(id: 'custom-components', classes: 'docs-section', [
        h2([Component.text('Custom Component Handlers & A2uiJasprCatalog')]),
        p([
          Component.text('Extend '),
          apiLink(DocSymbol.a2uiJasprCatalog),
          Component.text(
            ' to register custom domain components in your catalog:',
          ),
        ]),
        const DocsCodeBlock(
          title: 'custom_catalog_example.dart',
          language: 'dart',
          code: '''import 'package:bloc_signals_genui_jaspr/bloc_signals_genui_jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

A2uiJasprCatalog createCustomCatalog() {
  final catalog = A2uiJasprCatalog.standard();

  catalog.register('MetricBadge', (context, componentContext) {
    final label = componentContext.props['label']?.toString() ?? '';
    final value = componentContext.props['value']?.toString() ?? '';

    return div(classes: 'metric-badge', [
      span(classes: 'badge-label', [Component.text(label)]),
      span(classes: 'badge-value', [Component.text(value)]),
    ]);
  });

  return catalog;
}''',
        ),
      ]),

      // 5. Synchronous Form Mutations & Action Dispatch
      section(id: 'form-actions', classes: 'docs-section', [
        h2([Component.text('Synchronous Form Mutations & Action Dispatch')]),
        p([
          Component.text(
            'Form inputs write directly to the surface DataModel with 0ms synchronous latency. Action submissions packaging structured form values and context are dispatched directly to the host bloc:',
          ),
        ]),
        const DocsCodeBlock(
          title: 'action_dispatch_example.dart',
          language: 'dart',
          code: '''import 'package:bloc_signals_genui_jaspr/bloc_signals_genui_jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

Component buildActionButton(A2uiComponentContext ctx) {
  return button(
    classes: 'btn-submit',
    onClick: () {
      ctx.dispatchAction(
        'submitOrder',
        context: {'orderId': '123'},
      );
    },
    [Component.text('Submit Order')],
  );
}''',
        ),
        const DocsCallout(
          type: CalloutType.tip,
          title: 'Production Tip',
          children: [
            p([
              Component.text(
                'Listen to A2uiSurfaceBloc.actionResponses to bridge client interactions to remote agent orchestrators or LLM inference loops.',
              ),
            ]),
          ],
        ),
      ]),

      // 6. Styling & Theme Integration
      section(id: 'styling-themes', classes: 'docs-section', [
        h2([Component.text('Styling & Theme Integration')]),
        p([
          Component.text(
            'All DOM elements rendered by bloc_signals_genui_jaspr include standard CSS class names (for example a2ui-card, a2ui-button, a2ui-text, a2ui-input) making them straightforward to style using standard CSS or CSS modules.',
          ),
        ]),
      ]),
    ]);
  }
}
