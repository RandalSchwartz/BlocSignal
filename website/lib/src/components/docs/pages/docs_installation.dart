import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../docs_code_block.dart';
import '../docs_toc.dart';

class const DocsInstallationPage({super.key}) extends StatelessComponent {
  static const List<TocHeading> headings = [
    TocHeading(title: 'Quick Installation', anchor: 'quick-installation'),
    TocHeading(title: 'Package Matrix', anchor: 'package-matrix'),
    TocHeading(
      title: 'SDK Versioning & Compatibility',
      anchor: 'sdk-compatibility',
    ),
    TocHeading(title: 'Linter & Static Analysis', anchor: 'linter-setup'),
  ];

  @override
  Component build(BuildContext context) {
    return article(classes: 'docs-article', [
      header(classes: 'docs-article-header', [
        div(classes: 'docs-badge', [Component.text('🚀 Getting Started')]),
        h1([Component.text('Installation & Package Matrix')]),
        p(classes: 'docs-lead', [
          Component.text(
            'Add BlocSignal to your Flutter, Jaspr web, or pure Dart project with modular, tree-shakeable packages.',
          ),
        ]),
      ]),

      // 1. Quick Installation
      section(id: 'quick-installation', classes: 'docs-section', [
        h2([Component.text('Quick Installation')]),
        p([
          Component.text(
            'Choose the package tailored to your target platform:',
          ),
        ]),

        h3([Component.text('For Flutter Applications')]),
        const DocsCodeBlock(
          title: 'terminal',
          language: 'bash',
          code: 'flutter pub add bloc_signals_flutter bloc_signals',
        ),

        h3([Component.text('For Pure Dart / Server Projects')]),
        const DocsCodeBlock(
          title: 'terminal',
          language: 'bash',
          code: 'dart pub add bloc_signals',
        ),

        h3([Component.text('For Jaspr Web Applications')]),
        const DocsCodeBlock(
          title: 'terminal',
          language: 'bash',
          code: 'dart pub add bloc_signals_jaspr bloc_signals',
        ),
      ]),

      // 2. Package Matrix
      section(id: 'package-matrix', classes: 'docs-section', [
        h2([Component.text('Package Matrix')]),
        p([
          Component.text(
            'BlocSignal provides a modular monorepo structure. You only import what your application uses:',
          ),
        ]),
        div(classes: 'docs-table-wrapper', [
          table(classes: 'docs-table', [
            thead([
              tr([
                th([Component.text('Package')]),
                th([Component.text('Version')]),
                th([Component.text('Description')]),
                th([Component.text('Platform')]),
              ]),
            ]),
            tbody([
              tr([
                td([
                  a(
                    href: 'https://pub.dev/packages/bloc_signals',
                    target: Target.blank,
                    classes: 'docs-table-link',
                    [Component.text('bloc_signals')],
                  ),
                ]),
                td([Component.text('^1.1.0')]),
                td([
                  Component.text(
                    'Core Pure Dart state containers (BlocSignal, CubitSignal, Transformers, Observers).',
                  ),
                ]),
                td([Component.text('Dart 3.5+ / All')]),
              ]),
              tr([
                td([
                  a(
                    href: 'https://pub.dev/packages/bloc_signals_flutter',
                    target: Target.blank,
                    classes: 'docs-table-link',
                    [Component.text('bloc_signals_flutter')],
                  ),
                ]),
                td([Component.text('^1.2.0')]),
                td([
                  Component.text(
                    'Flutter bindings, O(1) providers, builders, listeners, selectors, and context extensions.',
                  ),
                ]),
                td([Component.text('Flutter 3.22+ / UI')]),
              ]),
              tr([
                td([
                  a(
                    href: 'https://pub.dev/packages/bloc_signals_jaspr',
                    target: Target.blank,
                    classes: 'docs-table-link',
                    [Component.text('bloc_signals_jaspr')],
                  ),
                ]),
                td([Component.text('^1.0.0+1')]),
                td([
                  Component.text(
                    'Jaspr web component integration, InheritedComponent providers, builders, and listeners.',
                  ),
                ]),
                td([Component.text('Jaspr Web / SSR')]),
              ]),
              tr([
                td([
                  a(
                    href: 'https://pub.dev/packages/bloc_signals_test',
                    target: Target.blank,
                    classes: 'docs-table-link',
                    [Component.text('bloc_signals_test')],
                  ),
                ]),
                td([Component.text('^1.0.0')]),
                td([
                  Component.text(
                    'Declarative unit testing utilities and test observers for state assertions.',
                  ),
                ]),
                td([Component.text('Test / Dev')]),
              ]),
              tr([
                td([
                  a(
                    href: 'https://pub.dev/packages/bloc_signals_lint',
                    target: Target.blank,
                    classes: 'docs-table-link',
                    [Component.text('bloc_signals_lint')],
                  ),
                ]),
                td([Component.text('^1.0.0')]),
                td([
                  Component.text(
                    'Custom analyzer lints and automated IDE quick-fixes for enforcing best practices.',
                  ),
                ]),
                td([Component.text('Analyzer / Tooling')]),
              ]),
              tr([
                td([
                  a(
                    href: 'https://pub.dev/packages/bloc_signals_hydrate',
                    target: Target.blank,
                    classes: 'docs-table-link',
                    [Component.text('bloc_signals_hydrate')],
                  ),
                ]),
                td([Component.text('^1.0.1')]),
                td([
                  Component.text(
                    'Synchronous frame 1 state persistence across app restarts.',
                  ),
                ]),
                td([Component.text('Dart / Flutter')]),
              ]),
              tr([
                td([
                  a(
                    href: 'https://pub.dev/packages/bloc_signals_replay',
                    target: Target.blank,
                    classes: 'docs-table-link',
                    [Component.text('bloc_signals_replay')],
                  ),
                ]),
                td([Component.text('^1.0.0')]),
                td([
                  Component.text(
                    'Undo and redo state history management with customizable bounds.',
                  ),
                ]),
                td([Component.text('Dart / Flutter')]),
              ]),
              tr([
                td([
                  a(
                    href: 'https://pub.dev/packages/bloc_signals_riverpod',
                    target: Target.blank,
                    classes: 'docs-table-link',
                    [Component.text('bloc_signals_riverpod')],
                  ),
                ]),
                td([Component.text('^1.1.0')]),
                td([
                  Component.text(
                    'Bidirectional read-and-mutate Riverpod 2 & 3 interoperability adapters.',
                  ),
                ]),
                td([Component.text('Dart / Flutter')]),
              ]),
              tr([
                td([
                  a(
                    href: 'https://pub.dev/packages/bloc_signals_bloc',
                    target: Target.blank,
                    classes: 'docs-table-link',
                    [Component.text('bloc_signals_bloc')],
                  ),
                ]),
                td([Component.text('^1.0.0')]),
                td([
                  Component.text(
                    'Bidirectional classic BLoC 8 & 9 interoperability adapters and event bridges.',
                  ),
                ]),
                td([Component.text('Dart / Flutter')]),
              ]),
              tr([
                td([
                  a(
                    href: 'https://pub.dev/packages/bloc_signals_otel',
                    target: Target.blank,
                    classes: 'docs-table-link',
                    [Component.text('bloc_signals_otel')],
                  ),
                ]),
                td([Component.text('^1.0.0+1')]),
                td([
                  Component.text(
                    'OpenTelemetry distributed tracing and event telemetry.',
                  ),
                ]),
                td([Component.text('Dart / Server / UI')]),
              ]),
              tr([
                td([
                  a(
                    href: 'https://pub.dev/packages/bloc_signals_devtools',
                    target: Target.blank,
                    classes: 'docs-table-link',
                    [Component.text('bloc_signals_devtools')],
                  ),
                ]),
                td([Component.text('^1.0.0')]),
                td([
                  Component.text(
                    'Custom Flutter DevTools extension for timeline visualization and memory leak detection.',
                  ),
                ]),
                td([Component.text('DevTools')]),
              ]),
            ]),
          ]),
        ]),
      ]),

      // 3. SDK Versioning & Compatibility
      section(id: 'sdk-compatibility', classes: 'docs-section', [
        h2([Component.text('SDK Versioning & Compatibility')]),
        p([
          Component.text(
            'BlocSignal enforces a strict SDK baseline to ensure broad compatibility:',
          ),
        ]),
        ul(classes: 'docs-list', [
          li([
            strong([Component.text('Published Packages: ')]),
            Component.text(
              'Target sdk: ^3.5.0, making them fully compatible with all stable Flutter channels (3.22+).',
            ),
          ]),
          li([
            strong([Component.text('Modern Language Support: ')]),
            Component.text(
              'Applications running Dart 3.13+ can fully utilize primary constructors and constructor shorthands when defining BlocSignal subclasses.',
            ),
          ]),
        ]),
      ]),

      // 4. Linter Setup
      section(id: 'linter-setup', classes: 'docs-section', [
        h2([Component.text('Linter & Static Analysis Setup')]),
        p([
          Component.text(
            'Add bloc_signals_lint to your dev_dependencies for automatic IDE diagnostics and quick-fixes:',
          ),
        ]),
        const DocsCodeBlock(
          title: 'analysis_options.yaml',
          language: 'yaml',
          code: '''
plugins:
  custom_lint:

custom_lint:
  rules:
    - avoid_duplicate_event_handlers
    - require_super_on_event
    - avoid_stream_transformers_on_bloc_signal
    - avoid_direct_signal_mutation_outside_bloc
    - avoid_emit_in_build
    - prefer_bloc_signal_provider_read_in_callbacks
''',
        ),
      ]),
    ]);
  }
}
