import 'package:blocsignal_website/src/models/pub_api_registry.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../docs_callout.dart';
import '../docs_code_block.dart';
import '../docs_toc.dart';

/// Documentation page covering lifecycle hooks and global observers in BlocSignal.
class const DocsLifecycleAndObserversPage({super.key})
    extends StatelessComponent {
  static const List<TocHeading> headings = [
    TocHeading(
      title: 'BlocSignalObserver Contract',
      anchor: 'observer-contract',
    ),
    TocHeading(
      title: 'Lifecycle Hook Reference',
      anchor: 'lifecycle-hook-reference',
    ),
    TocHeading(title: 'Change vs. Transition', anchor: 'change-vs-transition'),
    TocHeading(title: 'OpenTelemetry Spans', anchor: 'opentelemetry-tracing'),
    TocHeading(title: 'DevTools Integration', anchor: 'devtools-integration'),
  ];

  @override
  Component build(BuildContext context) {
    return article(classes: 'docs-article', [
      header(classes: 'docs-article-header', [
        div(classes: 'docs-badge', [Component.text('🧠 Core Concepts')]),
        h1([Component.text('Lifecycle & Observers')]),
        p(classes: 'docs-lead', [
          Component.text(
            'Monitor, trace, and instrument state containers across your application using ',
          ),
          apiLink(DocSymbol.blocSignalObserver),
          Component.text(', OpenTelemetry spans, and DevTools hooks.'),
        ]),
      ]),

      // 1. BlocSignalObserver Contract
      section(id: 'observer-contract', classes: 'docs-section', [
        h2([Component.text('BlocSignalObserver Contract')]),
        p([
          apiLink(DocSymbol.blocSignalObserver),
          Component.text(
            ' provides a global inspection interface to observe container creation, event dispatching, '
            'state changes, transitions, errors, and disposal across the entire application lifecycle.',
          ),
        ]),
        const DocsCodeBlock(
          filename: 'app_observer.dart',
          dart313Code: '''
import 'package:bloc_signals/bloc_signals.dart';

class AppBlocObserver extends BlocSignalObserver {
  @override
  void onCreate(BlocSignalBase bloc) {
    super.onCreate(bloc);
    print('Container Created: \${bloc.runtimeType}');
  }

  @override
  void onEvent(BlocSignal bloc, Object? event) {
    super.onEvent(bloc, event);
    print('\${bloc.runtimeType} Event: \$event');
  }

  @override
  void onChange(BlocSignalBase bloc, Change change) {
    super.onChange(bloc, change);
    print('\${bloc.runtimeType} Change: \${change.currentState} -> \${change.nextState}');
  }

  @override
  void onTransition(BlocSignal bloc, Transition transition) {
    super.onTransition(bloc, transition);
    print('\${bloc.runtimeType} Transition: \${transition.event} => \${transition.nextState}');
  }

  @override
  void onError(BlocSignalBase bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    print('Error in \${bloc.runtimeType}: \$error');
  }

  @override
  void onClose(BlocSignalBase bloc) {
    super.onClose(bloc);
    print('Container Closed: \${bloc.runtimeType}');
  }
}

// In main.dart:
// BlocSignalObserver.observer = AppBlocObserver();
''',
          dart35Code: '''
import 'package:bloc_signals/bloc_signals.dart';

class AppBlocObserver extends BlocSignalObserver {
  @override
  void onCreate(BlocSignalBase bloc) {
    super.onCreate(bloc);
    print('Container Created: \${bloc.runtimeType}');
  }

  @override
  void onEvent(BlocSignal bloc, Object? event) {
    super.onEvent(bloc, event);
    print('\${bloc.runtimeType} Event: \$event');
  }

  @override
  void onChange(BlocSignalBase bloc, Change change) {
    super.onChange(bloc, change);
    print('\${bloc.runtimeType} Change: \${change.currentState} -> \${change.nextState}');
  }

  @override
  void onTransition(BlocSignal bloc, Transition transition) {
    super.onTransition(bloc, transition);
    print('\${bloc.runtimeType} Transition: \${transition.event} => \${transition.nextState}');
  }

  @override
  void onError(BlocSignalBase bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    print('Error in \${bloc.runtimeType}: \$error');
  }

  @override
  void onClose(BlocSignalBase bloc) {
    super.onClose(bloc);
    print('Container Closed: \${bloc.runtimeType}');
  }
}

// In main.dart:
// BlocSignalObserver.observer = AppBlocObserver();
''',
        ),
      ]),

      // 2. Lifecycle Hook Reference
      section(id: 'lifecycle-hook-reference', classes: 'docs-section', [
        h2([Component.text('Lifecycle Hook Reference')]),
        div(classes: 'docs-table-wrapper', [
          table(classes: 'docs-table', [
            thead([
              tr([
                th([Component.text('Hook')]),
                th([Component.text('Target')]),
                th([Component.text('Trigger Moment')]),
              ]),
            ]),
            tbody([
              tr([
                td([Component.text('onCreate')]),
                td([Component.text('Cubit & Bloc')]),
                td([
                  Component.text(
                    'Immediately after container constructor execution.',
                  ),
                ]),
              ]),
              tr([
                td([Component.text('onEvent')]),
                td([Component.text('Bloc only')]),
                td([
                  Component.text(
                    'When add(event) is called before handler dispatch.',
                  ),
                ]),
              ]),
              tr([
                td([Component.text('onChange')]),
                td([Component.text('Cubit & Bloc')]),
                td([
                  Component.text('When emit() produces a new non-equal state.'),
                ]),
              ]),
              tr([
                td([Component.text('onTransition')]),
                td([Component.text('Bloc only')]),
                td([
                  Component.text(
                    'When emit() produces a new state associated with a causal event.',
                  ),
                ]),
              ]),
              tr([
                td([Component.text('onError')]),
                td([Component.text('Cubit & Bloc')]),
                td([
                  Component.text(
                    'When an operational exception is captured during event processing.',
                  ),
                ]),
              ]),
              tr([
                td([Component.text('onClose')]),
                td([Component.text('Cubit & Bloc')]),
                td([
                  Component.text(
                    'When close() is invoked and signal effects are disposed.',
                  ),
                ]),
              ]),
            ]),
          ]),
        ]),
      ]),

      // 3. Change vs. Transition
      section(id: 'change-vs-transition', classes: 'docs-section', [
        h2([Component.text('Change vs. Transition')]),
        p([
          Component.text('Both '),
          apiLink(DocSymbol.change, label: 'Change<State>'),
          Component.text(' and '),
          apiLink(DocSymbol.transition, label: 'Transition<Event, State>'),
          Component.text(
            ' represent state mutations, but provide different levels of context:',
          ),
        ]),
        ul(classes: 'docs-list', [
          li([
            apiLink(DocSymbol.change, label: 'Change<State>'),
            Component.text(
              ': Fires for all state containers (both Cubits and Blocs). Contains currentState and nextState.',
            ),
          ]),
          li([
            apiLink(DocSymbol.transition, label: 'Transition<Event, State>'),
            Component.text(
              ': Fires exclusively for BlocSignal. Enriches the Change with the causal event that triggered the mutation.',
            ),
          ]),
        ]),
      ]),

      // 4. OpenTelemetry & DevTools
      section(id: 'opentelemetry-devtools', classes: 'docs-section', [
        h2([Component.text('OpenTelemetry & DevTools Integration')]),
        p([
          Component.text('The satellite package bloc_signals_otel provides '),
          apiLink(DocSymbol.otelBlocSignalObserver),
          Component.text(
            ', instrumenting events and transitions into distributed OpenTelemetry trace spans. In addition, ',
          ),
          apiLink(DocSymbol.devToolsBlocSignalObserver),
          Component.text(
            ' posts diagnostic events via dart:developer for Flutter DevTools.',
          ),
        ]),
      ]),

      // 5. Memory Leak Prevention in Observers
      section(id: 'memory-leak-prevention', classes: 'docs-section', [
        h2([Component.text('Memory Leak Prevention in Observers')]),
        const DocsCallout(
          type: CalloutType.important,
          title: 'Span & Key Eviction Rules',
          children: [
            p([
              Component.text(
                'Because onTransition may not fire for every event (for example, when an error occurs or state is de-duplicated), '
                'active span maps in telemetry observers must be capped (default 100 entries) with oldest-key eviction. '
                'Furthermore, onClose() MUST purge lingering spans to prevent retained memory leaks upon container disposal.',
              ),
            ]),
          ],
        ),
      ]),
    ]);
  }
}
