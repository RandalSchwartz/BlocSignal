import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../docs_callout.dart';
import '../docs_code_block.dart';
import '../docs_toc.dart';

class const DocsOverviewPage({super.key}) extends StatelessComponent {
  static const List<TocHeading> headings = [
    TocHeading(title: 'What is BlocSignal?', anchor: 'what-is-blocsignal'),
    TocHeading(title: 'Why BlocSignal?', anchor: 'why-blocsignal'),
    TocHeading(
      title: 'Synchronous 0ms Reactivity',
      anchor: 'synchronous-reactivity',
      level: 3,
    ),
    TocHeading(
      title: 'Fine-Grained Signals Graph',
      anchor: 'signals-graph',
      level: 3,
    ),
    TocHeading(
      title: 'Streamless Concurrency Transformers',
      anchor: 'concurrency-transformers',
      level: 3,
    ),
    TocHeading(title: 'Feature Comparison Matrix', anchor: 'comparison-matrix'),
    TocHeading(title: 'Architecture Overview', anchor: 'architecture-overview'),
  ];

  @override
  Component build(BuildContext context) {
    return article(classes: 'docs-article', [
      header(classes: 'docs-article-header', [
        div(classes: 'docs-badge', [Component.text('🚀 Getting Started')]),
        h1([Component.text('Overview & Why BlocSignal')]),
        p(classes: 'docs-lead', [
          Component.text(
            'BlocSignal bridges the robust predictability of the BLoC pattern with the zero-latency, fine-grained reactivity of Preact Signals v7 in pure Dart.',
          ),
        ]),
      ]),

      // 1. What is BlocSignal
      section(id: 'what-is-blocsignal', classes: 'docs-section', [
        h2([Component.text('What is BlocSignal?')]),
        p([
          Component.text(
            'BlocSignal is a modern state management library designed for Flutter, Jaspr Web, and Pure Dart applications. '
            'It combines the battle-tested conventions of the BLoC pattern—such as structured events, state machines, and lifecycle observers—with '
            'high-performance signals. By replacing Dart Stream microtask queues with synchronous signal graphs, BlocSignal eliminates unnecessary latency and ghost rebuilds.',
          ),
        ]),
        const DocsCallout(
          type: CalloutType.tip,
          title: 'Zero Stream Dependencies',
          children: [
            p([
              Component.text(
                'Unlike classic BLoC, BlocSignal does not rely on async StreamControllers or microtask scheduling for state emissions. '
                'State changes evaluate synchronously in 0ms within the exact frame they are triggered.',
              ),
            ]),
          ],
        ),
      ]),

      // 2. Why BlocSignal?
      section(id: 'why-blocsignal', classes: 'docs-section', [
        h2([Component.text('Why BlocSignal?')]),
        p([
          Component.text(
            'Traditional state management approaches often force developers to compromise between strict architectural structure and fine-grained rendering performance. '
            'BlocSignal resolves this tradeoff through three foundational pillars:',
          ),
        ]),

        h3(id: 'synchronous-reactivity', [
          Component.text('1. Synchronous 0ms Propagation'),
        ]),
        p([
          Component.text(
            'Classic BLoC emits state asynchronously over Dart Streams. Each event requires microtask scheduling before widgets receive the update. '
            'BlocSignal notifies observers and updates dependent widgets synchronously without waiting for microtask drainage, achieving up to 100,000+ state emissions per second.',
          ),
        ]),

        h3(id: 'signals-graph', [
          Component.text('2. Fine-Grained Signals Graph Integration'),
        ]),
        p([
          Component.text(
            'State in BlocSignal is exposed as a ReadonlySignal. This enables seamless composition with computed signals (computed()) and reactive side effects (effect()) across independent state containers without coupling them.',
          ),
        ]),

        const DocsCodeBlock(
          title: 'computed_derivation.dart',
          dart313Code: '''
import 'package:bloc_signals/bloc_signals.dart';

class CounterCubit() extends CubitSignal<int> {
  this : super(initialState: 0);

  void increment() => emit(stateValue + 1);
}

void main() {
  final counter = CounterCubit();
  
  // Dynamically derived signal recalculates only when dependency changes
  final isEven = computed(() => counter.state().isEven);
  
  print('Initial isEven: \${isEven.value}'); // true
  counter.increment();
  print('Updated isEven: \${isEven.value}'); // false
}
''',
          dart35Code: '''
import 'package:bloc_signals/bloc_signals.dart';

class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void increment() => emit(stateValue + 1);
}

void main() {
  final counter = CounterCubit();
  
  // Dynamically derived signal recalculates only when dependency changes
  final isEven = computed(() => counter.state().isEven);
  
  print('Initial isEven: \${isEven.value}'); // true
  counter.increment();
  print('Updated isEven: \${isEven.value}'); // false
}
''',
        ),

        h3(id: 'concurrency-transformers', [
          Component.text('3. Streamless Event Concurrency Transformers'),
        ]),
        p([
          Component.text(
            'BlocSignal provides powerful event transformers like droppable(), sequential(), and restartable() built on lightweight Mutex locks and higher-order functions with zero Rx stream overhead.',
          ),
        ]),
      ]),

      // 3. Comparison Matrix
      section(id: 'comparison-matrix', classes: 'docs-section', [
        h2([Component.text('Feature Comparison Matrix')]),
        div(classes: 'docs-table-wrapper', [
          table(classes: 'docs-table', [
            thead([
              tr([
                th([Component.text('Capability')]),
                th([Component.text('Classic BLoC')]),
                th([Component.text('Riverpod')]),
                th([Component.text('BlocSignal ⚡')]),
              ]),
            ]),
            tbody([
              tr([
                td([
                  strong([Component.text('Reactivity Model')]),
                ]),
                td([Component.text('Async Streams')]),
                td([Component.text('Sync + Async Providers')]),
                td([
                  strong([Component.text('0ms Synchronous Signals')]),
                ]),
              ]),
              tr([
                td([
                  strong([Component.text('InheritedWidget Lookup')]),
                ]),
                td([Component.text('O(N) Traversal')]),
                td([Component.text('Custom Tree')]),
                td([
                  strong([Component.text('O(1) Element Lookup')]),
                ]),
              ]),
              tr([
                td([
                  strong([Component.text('State De-duplication')]),
                ]),
                td([Component.text('Manual Equatable')]),
                td([Component.text('Automatic ==')]),
                td([
                  strong([Component.text('Automatic Signal Equality')]),
                ]),
              ]),
              tr([
                td([
                  strong([Component.text('Event Transformers')]),
                ]),
                td([Component.text('Rx Stream Transformers')]),
                td([Component.text('Manual debounce')]),
                td([
                  strong([Component.text('Streamless Mutex Transformers')]),
                ]),
              ]),
              tr([
                td([
                  strong([Component.text('Platform Support')]),
                ]),
                td([Component.text('Flutter & Dart')]),
                td([Component.text('Flutter & Dart')]),
                td([
                  strong([Component.text('Flutter, Jaspr Web & Pure Dart')]),
                ]),
              ]),
            ]),
          ]),
        ]),
      ]),

      // 4. Architecture Overview
      section(id: 'architecture-overview', classes: 'docs-section', [
        h2([Component.text('Architecture Overview')]),
        p([
          Component.text(
            'BlocSignal components follow a clear, unidirectional data flow:',
          ),
        ]),
        div(classes: 'docs-architecture-card', [
          div(classes: 'docs-arch-step', [
            span(classes: 'docs-arch-badge', [Component.text('1. Events')]),
            span(classes: 'docs-arch-desc', [
              Component.text('UI dispatches typed events to BlocSignal.'),
            ]),
          ]),
          div(classes: 'docs-arch-arrow', [Component.text('➔')]),
          div(classes: 'docs-arch-step', [
            span(classes: 'docs-arch-badge', [
              Component.text('2. Concurrency Transformer'),
            ]),
            span(classes: 'docs-arch-desc', [
              Component.text(
                'Handlers coordinate execution (droppable, mutex).',
              ),
            ]),
          ]),
          div(classes: 'docs-arch-arrow', [Component.text('➔')]),
          div(classes: 'docs-arch-step', [
            span(classes: 'docs-arch-badge', [
              Component.text('3. Synchronous Emit'),
            ]),
            span(classes: 'docs-arch-desc', [
              Component.text('emit(newState) updates underlying signal.'),
            ]),
          ]),
          div(classes: 'docs-arch-arrow', [Component.text('➔')]),
          div(classes: 'docs-arch-step', [
            span(classes: 'docs-arch-badge', [
              Component.text('4. UI & Observers'),
            ]),
            span(classes: 'docs-arch-desc', [
              Component.text('Widgets and telemetry receive instant updates.'),
            ]),
          ]),
        ]),
      ]),
    ]);
  }
}
