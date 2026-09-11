import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../docs_code_block.dart';
import '../docs_toc.dart';

/// Documentation page covering Jaspr web component integration with bloc_signals_jaspr.
class const DocsPkgJasprPage({super.key}) extends StatelessComponent {
  static const List<TocHeading> headings = [
    TocHeading(title: 'Overview & Web Reactivity', anchor: 'overview-web'),
    TocHeading(title: 'Component Hierarchy', anchor: 'component-hierarchy'),
    TocHeading(
      title: 'Reactive Builders & Consumers',
      anchor: 'reactive-components',
    ),
    TocHeading(title: 'Context Extensions', anchor: 'context-extensions'),
    TocHeading(title: 'SSR & Static Hydration', anchor: 'ssr-hydration'),
  ];

  @override
  Component build(BuildContext context) {
    return article(classes: 'docs-article', [
      header(classes: 'docs-article-header', [
        div(classes: 'docs-badge', [Component.text('📦 Satellite Packages')]),
        h1([Component.text('bloc_signals_jaspr')]),
        p(classes: 'docs-lead', [
          Component.text(
            'High-performance web state management for Jaspr web applications with synchronous 0ms dispatch, server-side rendering (SSR), and seamless HTML component tree integration.',
          ),
        ]),
      ]),

      // 1. Overview & Web Reactivity
      section(id: 'overview-web', classes: 'docs-section', [
        h2([Component.text('Overview & Web Reactivity')]),
        p([
          Component.text(
            'bloc_signals_jaspr brings the complete BlocSignal declarative architecture to Jaspr web applications. '
            'Because BlocSignal operates without asynchronous stream microtasks, DOM component updates propagate in the exact same execution frame at over 100,000 state dispatches per second in browser JavaScript.',
          ),
        ]),
        const DocsCodeBlock(
          title: 'terminal',
          language: 'bash',
          code: 'dart pub add bloc_signals_jaspr bloc_signals',
        ),
      ]),

      // 2. Component Hierarchy
      section(id: 'component-hierarchy', classes: 'docs-section', [
        h2([Component.text('Component Hierarchy')]),
        p([
          Component.text(
            'Provide state containers down your Jaspr HTML component tree using BlocSignalProvider or MultiBlocSignalProvider:',
          ),
        ]),
        const DocsCodeBlock(
          title: 'lib/app.dart',
          language: 'dart',
          code: '''
import 'package:bloc_signals_jaspr/bloc_signals_jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import 'counter_cubit.dart';
import 'counter_view.dart';

class const App({super.key}) extends StatelessComponent {
  @override
  Component build(BuildContext context) {
    return BlocSignalProvider<CounterCubit>(
      create: (context) => CounterCubit(),
      child: const CounterView(),
    );
  }
}''',
        ),
      ]),

      // 3. Reactive Builders & Consumers
      section(id: 'reactive-components', classes: 'docs-section', [
        h2([Component.text('Reactive Builders & Consumers')]),
        p([
          Component.text(
            'Rebuild HTML elements when state changes using BlocSignalBuilder, or coordinate side effects with BlocSignalConsumer:',
          ),
        ]),
        const DocsCodeBlock(
          title: 'lib/counter_view.dart',
          language: 'dart',
          code: r'''
import 'package:bloc_signals_jaspr/bloc_signals_jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import 'counter_cubit.dart';

class const CounterView({super.key}) extends StatelessComponent {
  @override
  Component build(BuildContext context) {
    return div(classes: 'counter-container', [
      BlocSignalBuilder<CounterCubit, int>(
        builder: (context, count) {
          return h1([Component.text('Current Count: $count')]);
        },
      ),
      button(
        onClick: () => context.read<CounterCubit>().increment(),
        [Component.text('Increment (+1)')],
      ),
    ]);
  }
}''',
        ),
      ]),

      // 4. Context Extensions
      section(id: 'context-extensions', classes: 'docs-section', [
        h2([Component.text('Context Extensions')]),
        p([
          Component.text(
            'Access state containers and fine-grained values directly via BuildContext:',
          ),
        ]),
        ul([
          li([
            strong([
              code([Component.text('context.read<B>()')]),
            ]),
            Component.text(
              ': Retrieves the container without creating a reactive subscription. Used inside button click callbacks.',
            ),
          ]),
          li([
            strong([
              code([Component.text('context.select<B, R>((b) => ...)')]),
            ]),
            Component.text(
              ': Subscribes to a fine-grained sub-property. Automatically updates the component and safely rebinds when ancestor providers swap container instances.',
            ),
          ]),
          li([
            strong([
              code([Component.text('context.watch<B>()')]),
            ]),
            Component.text(
              ': Tracks provider container instance swapping only, without listening to individual state emissions.',
            ),
          ]),
          li([
            strong([
              code([Component.text('context.value<B, S>()')]),
            ]),
            Component.text(
              ': Subscribes the calling component Element to state updates and returns current state value ',
            ),
            code([Component.text('S')]),
            Component.text(
              '. Perfect for clean single-line state access inside build(context) methods.',
            ),
          ]),
          li([
            strong([
              code([Component.text('context.state<B, S>()')]),
            ]),
            Component.text(': Returns the underlying '),
            code([Component.text('ReadonlySignal<S>')]),
            Component.text(
              ' without registering an element rebuild dependency. Designed specifically for computed() and effect() signal graph composition.',
            ),
          ]),
        ]),
        const DocsCodeBlock(
          title: 'context.value and context.state in Jaspr',
          dart313Code: '''
class const CounterStatsCard({super.key}) extends StatefulComponent {
  @override
  State<CounterStatsCard> createState() => _CounterStatsCardState();
}

class _CounterStatsCardState() extends State<CounterStatsCard> {
  // Long-lived computed signal bound outside build() to prevent unmanaged re-allocations:
  late final isEven = computed(
    () => context.state<CounterCubit, int>().value.isEven,
  );

  @override
  Component build(BuildContext context) {
    // context.value subscribes this component to state emissions directly:
    final count = context.value<CounterCubit, int>();

    return div(classes: 'stats-card', [
      p([Component.text('Count: \$count')]),
      p([Component.text('Is Even: \${isEven.value}')]),
      button(
        onClick: () => context.read<CounterCubit>().increment(),
        [Component.text('Increment (+1)')],
      ),
    ]);
  }
}''',
          dart35Code: '''
class CounterStatsCard extends StatefulComponent {
  const CounterStatsCard({super.key});

  @override
  State<CounterStatsCard> createState() => _CounterStatsCardState();
}

class _CounterStatsCardState extends State<CounterStatsCard> {
  // Long-lived computed signal bound outside build() to prevent unmanaged re-allocations:
  late final ReadonlySignal<bool> isEven = computed(
    () => context.state<CounterCubit, int>().value.isEven,
  );

  @override
  Component build(BuildContext context) {
    // context.value subscribes this component to state emissions directly:
    final int count = context.value<CounterCubit, int>();

    return div(classes: 'stats-card', [
      p([Component.text('Count: \$count')]),
      p([Component.text('Is Even: \${isEven.value}')]),
      button(
        onClick: () => context.read<CounterCubit>().increment(),
        [Component.text('Increment (+1)')],
      ),
    ]);
  }
}''',
        ),
      ]),

      // 5. SSR & Static Hydration
      section(id: 'ssr-hydration', classes: 'docs-section', [
        h2([Component.text('SSR & Static Hydration')]),
        p([
          Component.text(
            'bloc_signals_jaspr fully supports Jaspr Static Site Generation (SSG) and Server-Side Rendering (SSR). '
            'Because state signals are initialized synchronously, initial HTML renders deterministically on the server and hydrates seamlessly on the browser client without flash of unstyled content or hydration mismatch warnings.',
          ),
        ]),
      ]),
    ]);
  }
}
