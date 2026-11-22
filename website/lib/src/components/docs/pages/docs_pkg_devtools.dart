import 'package:blocsignal_website/src/models/pub_api_registry.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../docs_callout.dart';
import '../docs_code_block.dart';
import '../docs_toc.dart';

/// Documentation page covering Flutter DevTools integration with bloc_signals_devtools.
class const DocsPkgDevtoolsPage({super.key}) extends StatelessComponent {
  static const List<TocHeading> headings = [
    TocHeading(title: 'Overview & Setup', anchor: 'overview-setup'),
    TocHeading(
      title: 'DevToolsBlocSignalObserver',
      anchor: 'devtools-observer',
    ),
    TocHeading(title: 'Instance Tree Inspector', anchor: 'instance-tree'),
    TocHeading(title: 'Live State Diff Viewer', anchor: 'state-diffs'),
    TocHeading(title: 'Memory Leak Detector', anchor: 'leak-detector'),
    TocHeading(
      title: 'Timeline Tracing & Profiling',
      anchor: 'timeline-tracing',
    ),
    TocHeading(
      title: 'Redaction, Caps & Hardening',
      anchor: 'redaction-hardening',
    ),
  ];

  @override
  Component build(BuildContext context) {
    return article(classes: 'docs-article', [
      header(classes: 'docs-article-header', [
        div(classes: 'docs-badge', [Component.text('📦 Satellite Packages')]),
        h1([Component.text('bloc_signals_devtools')]),
        p(classes: 'docs-lead', [
          Component.text(
            'Interactive Flutter DevTools extension and VM service telemetry for inspecting active state containers, transitions, and memory lifecycle.',
          ),
        ]),
      ]),

      // 1. Overview & Setup
      section(id: 'overview-setup', classes: 'docs-section', [
        h2([Component.text('Overview & Setup')]),
        p([
          Component.text(
            'The bloc_signals_devtools package provides a dedicated tab inside Flutter DevTools. '
            'It connects directly to the Dart VM Service to display real-time diagnostics, state trees, and event timelines.',
          ),
        ]),
        const DocsCodeBlock(
          title: 'terminal',
          language: 'bash',
          code: 'flutter pub add bloc_signals_devtools bloc_signals --dev',
        ),
      ]),

      // 2. DevToolsBlocSignalObserver
      section(id: 'devtools-observer', classes: 'docs-section', [
        h2([Component.text('DevToolsBlocSignalObserver')]),
        p([
          Component.text('Enable DevTools telemetry by attaching '),
          apiLink(DocSymbol.devToolsBlocSignalObserver),
          Component.text(' in debug mode (backed by '),
          apiLink(DocSymbol.devToolsService),
          Component.text(
            ', which enforces release-mode isEnabled guards cleanly without debug-only side-effecting assertions). When chaining a previousObserver, DevToolsBlocSignalObserver isolates previousObserver exceptions across all 8 lifecycle hooks via bloc.onError() while safeguarding onError from recursive exceptions:',
          ),
        ]),
        const DocsCodeBlock(
          title: 'lib/main.dart',
          language: 'dart',
          code: '''
import 'package:bloc_signals/bloc_signals.dart';
import 'package:flutter/foundation.dart';

void main() {
  if (kDebugMode) {
    // Posts telemetry events to the Dart VM Service via dart:developer
    BlocSignalObserver.observer = DevToolsBlocSignalObserver();
  }

  runApp(const MyApp());
}''',
        ),
      ]),

      // 3. Instance Tree Inspector
      section(id: 'instance-tree', classes: 'docs-section', [
        h2([Component.text('Instance Tree Inspector')]),
        p([
          Component.text(
            'View all currently active CubitSignal and BlocSignal instances grouped by class type. '
            'Inspect their current state values, creation timestamps, and lifecycle status in real time.',
          ),
        ]),
      ]),

      // 4. Live State Diff Viewer
      section(id: 'state-diffs', classes: 'docs-section', [
        h2([Component.text('Live State Diff Viewer')]),
        p([
          Component.text(
            'Every time an event triggers a transition, the DevTools tab highlights exact JSON field differences '
            'between previous and current state values with color-coded diffs.',
          ),
        ]),
      ]),

      // 5. Memory Leak Detector
      section(id: 'leak-detector', classes: 'docs-section', [
        h2([Component.text('Memory Leak Detector Badge')]),
        p([
          Component.text(
            'The leak detector automatically flags containers that receive events after close() has been called, '
            'or instances that remain un-garbage-collected after their parent widget has unmounted. ',
          ),
          apiLink(DocSymbol.devToolsService),
          Component.text(
            ' automatically evicts container history entries via Finalizer<int> and dead WeakReference pruning upon GC, '
            'scopes typed registerEventDeserializer<T>() registrations by container type while preserving unscoped eventName fallbacks, '
            'and enforces a 64 KB dispatch payload cap (DevToolsService.kMaxDispatchPayloadLength = 65536) on BlocSignalMixin targets.',
          ),
        ]),
        const DocsCallout(
          type: CalloutType.important,
          title: 'Production Zero-Overhead',
          children: [
            p([
              Component.text(
                'DevToolsBlocSignalObserver relies on dart:developer postEvent calls which are automatically stripped '
                'in release builds, guaranteeing zero runtime overhead in production.',
              ),
            ]),
          ],
        ),
      ]),

      // 6. Timeline Tracing & Profiling
      section(id: 'timeline-tracing', classes: 'docs-section', [
        h2([Component.text('Timeline Tracing & Profiling')]),
        p([
          Component.text(
            'State transitions and event handler durations are registered as Timeline events. '
            'You can correlate state mutations directly with Flutter UI frame rendering in the DevTools Performance profiler.',
          ),
        ]),
      ]),

      // 7. Redaction, Caps & Hardening
      section(id: 'redaction-hardening', classes: 'docs-section', [
        h2([Component.text('Redaction, Caps & Hardening')]),
        p([
          apiLink(DocSymbol.devToolsBlocSignalObserver),
          Component.text(' and '),
          apiLink(DocSymbol.devToolsService),
          Component.text(
            '.instance.configure(...) support stateRedactor, eventRedactor, errorRedactor, stackTraceRedactor, '
            'and maxPayloadLength (defaulting to 4096 UTF-16 code units, preserving surrogate pairs and appending ...[truncated] when exceeded). '
            'Redactor exceptions are isolated cleanly (falling back to <redaction_error> without aborting transitions), while returning null from '
            'stateRedactor, eventRedactor, or errorRedactor omits the value (using [REDACTED] for handleDispatch RPC error responses).',
          ),
        ]),
        p([
          apiLink(DocSymbol.devToolsService),
          Component.text(
            '.sanitizeMetadata recursively normalizes double.nan, double.infinity, double.negativeInfinity, and nested or cyclic Map/Iterable '
            'structures (maxDepth = 8) so VM Service payloads stay jsonEncode-safe, while DevToolsService.isEnabled guards all RPC handlers and '
            'BlocSignalsDevToolsController/UI widgets harden payload decoding with safe type checks, generation fencing, and _isDisposed guards.',
          ),
        ]),
        const DocsCodeBlock(
          title: 'lib/main.dart',
          language: 'dart',
          code: '''
BlocSignalObserver.observer = DevToolsBlocSignalObserver(
  stateRedactor: (bloc, state) => '[REDACTED_STATE]',
  eventRedactor: (bloc, event) => event?.runtimeType.toString(),
  errorRedactor: (bloc, error) => 'SanitizedError',
  stackTraceRedactor: (stack) => stack.toString().split('\\n').take(5).join('\\n'),
  maxPayloadLength: 2048,
);''',
        ),
      ]),
    ]);
  }
}
