import 'package:blocsignal_website/src/models/pub_api_registry.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../docs_callout.dart';
import '../docs_code_block.dart';
import '../docs_toc.dart';

/// Documentation page covering Flutter A2UI rendering in bloc_signals_genui_flutter.
class const DocsPkgGenuiFlutterPage({super.key}) extends StatelessComponent {
  static const List<TocHeading> headings = [
    TocHeading(title: 'Overview & Installation', anchor: 'overview-install'),
    TocHeading(title: 'Rendering with A2uiSurfaceView', anchor: 'surface-view'),
    TocHeading(
      title: 'Extending A2uiFlutterCatalog',
      anchor: 'flutter-catalog',
    ),
    TocHeading(
      title: 'Granular Signal Bindings & Split-Panes',
      anchor: 'signal-bindings',
    ),
    TocHeading(
      title: 'GenUiControllerAdapter Interop',
      anchor: 'controller-adapter',
    ),
  ];

  @override
  Component build(BuildContext context) {
    return article(classes: 'docs-article', [
      header(classes: 'docs-article-header', [
        div(classes: 'docs-badge', [Component.text('📦 Satellite Packages')]),
        h1([Component.text('bloc_signals_genui_flutter')]),
        p(classes: 'docs-lead', [
          Component.text(
            'Declarative Flutter surface views, Material 3 catalog widgets, and 0ms leaf-level signal bindings for Google\'s A2UI Generative UI protocol.',
          ),
        ]),
      ]),

      // 1. Overview & Installation
      section(id: 'overview-install', classes: 'docs-section', [
        h2([Component.text('Overview & Installation')]),
        p([
          Component.text('The bloc_signals_genui_flutter package connects '),
          apiLink(DocSymbol.a2uiSurfaceBloc),
          Component.text(' to Flutter\'s widget tree via '),
          apiLink(DocSymbol.a2uiSurfaceView),
          Component.text(' and '),
          apiLink(DocSymbol.a2uiFlutterCatalog),
          Component.text(
            '. Each rendered component subscribes to its own resolved property signal so user input updates leaf widgets in 0ms without rebuilding the entire surface.',
          ),
        ]),
        const DocsCodeBlock(
          title: 'terminal',
          language: 'bash',
          code: 'flutter pub add bloc_signals_genui_flutter bloc_signals_genui bloc_signals_flutter',
        ),
        const DocsCodeBlock(
          title: 'pubspec.yaml',
          language: 'yaml',
          code: '''
dependencies:
  flutter:
    sdk: flutter
  bloc_signals: ^1.7.0
  bloc_signals_flutter: ^1.5.0
  bloc_signals_genui: ^0.1.2
  bloc_signals_genui_flutter: ^0.1.1
  a2ui_core: ^0.3.0
''',
        ),
      ]),

      // 2. Rendering with A2uiSurfaceView
      section(id: 'surface-view', classes: 'docs-section', [
        h2([Component.text('Rendering with A2uiSurfaceView')]),
        p([
          Component.text('Provide an '),
          apiLink(DocSymbol.a2uiSurfaceBloc),
          Component.text(' and render '),
          apiLink(DocSymbol.a2uiSurfaceView),
          Component.text(
            ' inside your screen. Customize loading skeletons, submission overlays, and validation banners using optional builder callbacks:',
          ),
        ]),
        const DocsCodeBlock(
          title: 'lib/agent_surface_screen.dart',
          dart313Code: '''
import 'package:bloc_signals_genui/bloc_signals_genui.dart';
import 'package:bloc_signals_genui_flutter/bloc_signals_genui_flutter.dart';
import 'package:flutter/material.dart';

class const AgentSurfaceScreen({
  required this.surfaceBloc,
  super.key,
}) extends StatelessWidget {
  final A2uiSurfaceBloc surfaceBloc;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assistant Surface')),
      body: A2uiSurfaceView(
        bloc: surfaceBloc,
        catalog: A2uiFlutterCatalog.standard(),
      ),
    );
  }
}''',
          dart35Code: '''
import 'package:bloc_signals_genui/bloc_signals_genui.dart';
import 'package:bloc_signals_genui_flutter/bloc_signals_genui_flutter.dart';
import 'package:flutter/material.dart';

class AgentSurfaceScreen extends StatelessWidget {
  const AgentSurfaceScreen({
    required this.surfaceBloc,
    super.key,
  });

  final A2uiSurfaceBloc surfaceBloc;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assistant Surface')),
      body: A2uiSurfaceView(
        bloc: surfaceBloc,
        catalog: A2uiFlutterCatalog.standard(),
      ),
    );
  }
}''',
        ),
      ]),

      // 3. Extending A2uiFlutterCatalog
      section(id: 'flutter-catalog', classes: 'docs-section', [
        h2([Component.text('Extending A2uiFlutterCatalog')]),
        p([
          apiLink(DocSymbol.a2uiFlutterCatalog),
          Component.text(
            '.standard() ships with Material 3 builders for Text, Row, Column, Button, TextField, Card, and Divider. '
            'Use copyWith, copyWithout, or registerAll to compose custom widget catalogs with ',
          ),
          apiLink(DocSymbol.a2uiComponentContext),
          Component.text(':'),
        ]),
        const DocsCodeBlock(
          title: 'lib/custom_catalog.dart',
          language: 'dart',
          code: r'''
import 'package:bloc_signals_genui_flutter/bloc_signals_genui_flutter.dart';
import 'package:flutter/material.dart';

final customCatalog = A2uiFlutterCatalog.standard().copyWith({
  'MetricBadge': (context, A2uiComponentContext componentContext) {
    final label = componentContext.props['label'] as String? ?? 'Metric';
    final value = componentContext.props['value']?.toString() ?? '0';
    return ActionChip(
      label: Text('$label: $value'),
      onPressed: () => componentContext.dispatchAction('inspect_metric'),
    );
  },
});''',
        ),
      ]),

      // 4. Granular Signal Bindings & Split-Panes
      section(id: 'signal-bindings', classes: 'docs-section', [
        h2([Component.text('Granular Signal Bindings & Split-Panes')]),
        p([
          Component.text('When surfaceId is omitted, '),
          apiLink(DocSymbol.a2uiSurfaceView),
          Component.text(
            ' reactively subscribes to bloc.activeSurfaceId. To pin multiple independent surfaces side-by-side in a split-pane or tabbed layout, pass an explicit surfaceId to each view:',
          ),
        ]),
        const DocsCodeBlock(
          title: 'lib/split_pane_surfaces.dart',
          language: 'dart',
          code: '''
Row(
  children: [
    Expanded(
      child: A2uiSurfaceView(
        bloc: surfaceBloc,
        surfaceId: 'flight_search',
      ),
    ),
    const VerticalDivider(width: 1),
    Expanded(
      child: A2uiSurfaceView(
        bloc: surfaceBloc,
        surfaceId: 'itinerary_summary',
      ),
    ),
  ],
)''',
        ),
        const DocsCallout(
          type: CalloutType.note,
          title: 'Error Boundary Protection',
          children: [
            p([
              Component.text(
                'Every catalog component rendered by A2uiSurfaceView is wrapped in an isolation boundary and ancestor-path cycle detector, preventing malformed LLM JSON payloads or unrecognized component types from crashing the Flutter widget tree.',
              ),
            ]),
          ],
        ),
      ]),

      // 5. GenUiControllerAdapter Interop
      section(id: 'controller-adapter', classes: 'docs-section', [
        h2([Component.text('GenUiControllerAdapter Interop')]),
        p([
          Component.text('Use '),
          apiLink(DocSymbol.genUiControllerAdapter),
          Component.text(
            ' when bridging an A2uiSurfaceBloc with imperative controller APIs, external chat SDKs, or custom navigation toolbars via selectSurface(id) and closeSurface(id).',
          ),
        ]),
      ]),
    ]);
  }
}
