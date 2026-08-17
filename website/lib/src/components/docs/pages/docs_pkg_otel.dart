import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../docs_callout.dart';
import '../docs_code_block.dart';
import '../docs_toc.dart';

/// Documentation page covering OpenTelemetry distributed tracing with bloc_signals_otel.
class const DocsPkgOtelPage({super.key}) extends StatelessComponent {
  static const List<TocHeading> headings = [
    TocHeading(title: 'Overview & Installation', anchor: 'overview-install'),
    TocHeading(title: 'OtelBlocSignalObserver', anchor: 'otel-observer'),
    TocHeading(title: 'Span Lifecycle & Hierarchy', anchor: 'span-lifecycle'),
    TocHeading(
      title: 'Span Correlation on Errors',
      anchor: 'error-correlation',
    ),
    TocHeading(title: 'Memory Leak Prevention', anchor: 'leak-prevention'),
  ];

  @override
  Component build(BuildContext context) {
    return article(classes: 'docs-article', [
      header(classes: 'docs-article-header', [
        div(classes: 'docs-badge', [Component.text('📦 Satellite Packages')]),
        h1([Component.text('bloc_signals_otel')]),
        p(classes: 'docs-lead', [
          Component.text(
            'Enterprise OpenTelemetry distributed tracing and observability for BlocSignal and CubitSignal pipelines.',
          ),
        ]),
      ]),

      // 1. Overview & Installation
      section(id: 'overview-install', classes: 'docs-section', [
        h2([Component.text('Overview & Installation')]),
        p([
          Component.text(
            'The bloc_signals_otel package transforms your state layer into an observable telemetry source. '
            'It instruments container creation, event dispatches, state transitions, and asynchronous operational exceptions '
            'into standard OpenTelemetry Spans ready for export to Jaeger, Grafana Tempo, Datadog, or Cloud Trace.',
          ),
        ]),
        const DocsCodeBlock(
          title: 'terminal',
          language: 'bash',
          code: 'dart pub add bloc_signals_otel bloc_signals opentelemetry',
        ),
      ]),

      // 2. OtelBlocSignalObserver
      section(id: 'otel-observer', classes: 'docs-section', [
        h2([Component.text('OtelBlocSignalObserver Setup')]),
        p([
          Component.text(
            'Attach the observer to the global BlocSignalObserver delegate during app bootstrap:',
          ),
        ]),
        const DocsCodeBlock(
          title: 'lib/main.dart',
          language: 'dart',
          code: '''
import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_otel/bloc_signals_otel.dart';
import 'package:opentelemetry/opentelemetry.dart';

void main() {
  final tracer = globalTracerProvider.getTracer('my_app_tracer');

  // Register the OpenTelemetry observer
  BlocSignalObserver.observer = OtelBlocSignalObserver(
    tracer: tracer,
    maxActiveSpans: 100, // Bound active span maps against memory leaks
  );

  runApp();
}''',
        ),
      ]),

      // 3. Span Lifecycle & Hierarchy
      section(id: 'span-lifecycle', classes: 'docs-section', [
        h2([Component.text('Span Lifecycle & Hierarchy')]),
        p([
          Component.text(
            'The observer generates standard OpenTelemetry spans across the state lifecycle:',
          ),
        ]),
        ul([
          li([
            strong([Component.text('Container Span (onCreate → onClose)')]),
            Component.text(
              ': Represents the full active lifespan of the Cubit or Bloc instance.',
            ),
          ]),
          li([
            strong([Component.text('Event Span (onEvent → onTransition)')]),
            Component.text(
              ': Measures the exact time taken to process an event and compute the next state.',
            ),
          ]),
          li([
            strong([
              Component.text('Transition Span (onChange / onTransition)'),
            ]),
            Component.text(
              ': Records the previous state, next state, and transition latency.',
            ),
          ]),
        ]),
      ]),

      // 4. Span Correlation on Errors
      section(id: 'error-correlation', classes: 'docs-section', [
        h2([Component.text('Span Correlation on Errors')]),
        p([
          Component.text(
            'When an asynchronous operational exception occurs during event handling, OtelBlocSignalObserver '
            'uses identity hash matching to attach the error and stack trace directly to the currently active event span, '
            'rather than emitting disconnected, orphaned error traces.',
          ),
        ]),
        const DocsCallout(
          type: CalloutType.tip,
          title: 'Direct Error Tracing',
          children: [
            p([
              Component.text(
                'This guarantees that distributed trace viewers display the failing event and the causing exception within the exact same flamegraph hierarchy.',
              ),
            ]),
          ],
        ),
      ]),

      // 5. Memory Leak Prevention
      section(id: 'leak-prevention', classes: 'docs-section', [
        h2([Component.text('Memory Leak Prevention')]),
        p([
          Component.text(
            'In high-throughput systems, some events may be de-duplicated or dropped (for example via droppable() transformers). '
            'To prevent un-ended spans from accumulating in memory indefinitely, OtelBlocSignalObserver caps internal span maps '
            '(default 100 entries) with automatic LRU eviction and enforces flush on onClose().',
          ),
        ]),
      ]),
    ]);
  }
}
