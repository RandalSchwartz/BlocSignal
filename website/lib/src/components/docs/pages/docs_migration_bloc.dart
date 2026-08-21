import 'package:blocsignal_website/src/models/pub_api_registry.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../docs_callout.dart';
import '../docs_code_block.dart';
import '../docs_toc.dart';

/// Documentation page covering migration from package:bloc and flutter_bloc.
class const DocsMigrationBlocPage({super.key}) extends StatelessComponent {
  static const List<TocHeading> headings = [
    TocHeading(
      title: 'Overview & Key Differences',
      anchor: 'overview-differences',
    ),
    TocHeading(
      title: 'Concept Translation Matrix',
      anchor: 'translation-matrix',
    ),
    TocHeading(title: 'Cubit Migration', anchor: 'cubit-migration'),
    TocHeading(title: 'Bloc & Event Migration', anchor: 'bloc-migration'),
    TocHeading(title: 'Flutter UI Migration', anchor: 'ui-migration'),
    TocHeading(title: 'Testing Migration', anchor: 'testing-migration'),
  ];

  @override
  Component build(BuildContext context) {
    return article(classes: 'docs-article', [
      header(classes: 'docs-article-header', [
        div(classes: 'docs-badge', [Component.text('🔄 Migration Guides')]),
        h1([Component.text('Migrating from package:bloc')]),
        p(classes: 'docs-lead', [
          Component.text(
            'A comprehensive side-by-side guide for migrating applications from classic BLoC and flutter_bloc to BlocSignal.',
          ),
        ]),
      ]),

      // 1. Overview & Key Differences
      section(id: 'overview-differences', classes: 'docs-section', [
        h2([Component.text('Overview & Key Differences')]),
        p([
          Component.text(
            'BlocSignal preserves the familiar mental model of BLoC (Events, States, Transitions, Cubits, Blocs, Observers, Providers, Builders) '
            'while replacing asynchronous microtask Stream pipelines with synchronous Preact Signals v7 primitives.',
          ),
        ]),
        ul([
          li([
            strong([Component.text('0ms Synchronous Propagation')]),
            Component.text(
              ': emit() recalculates downstream signal graphs and updates UI immediately in the current frame without microtask delay.',
            ),
          ]),
          li([
            strong([Component.text('Streamless Concurrency')]),
            Component.text(
              ': Event transformers (droppable, restartable, sequential) operate via pure Dart functions and mutexes with zero stream allocation.',
            ),
          ]),
          li([
            strong([Component.text('Automatic Signal Interop')]),
            Component.text(
              ': State is exposed as ReadonlySignal<S>, allowing direct composition with computed() and effect().',
            ),
          ]),
        ]),
      ]),

      // 2. Concept Translation Matrix
      section(id: 'translation-matrix', classes: 'docs-section', [
        h2([Component.text('Concept Translation Matrix')]),
        table(classes: 'docs-table', [
          thead([
            tr([
              th([Component.text('classic package:bloc / flutter_bloc')]),
              th([Component.text('bloc_signals / bloc_signals_flutter')]),
            ]),
          ]),
          tbody([
            tr([
              td([
                code([Component.text('Cubit<State>')]),
              ]),
              td([apiLink(DocSymbol.cubitSignal, label: 'CubitSignal<State>')]),
            ]),
            tr([
              td([
                code([Component.text('Bloc<Event, State>')]),
              ]),
              td([
                apiLink(
                  DocSymbol.blocSignal,
                  label: 'BlocSignal<Event, State>',
                ),
              ]),
            ]),
            tr([
              td([
                code([Component.text('BlocProvider<B>')]),
              ]),
              td([
                apiLink(
                  DocSymbol.blocSignalProvider,
                  label: 'BlocSignalProvider<B>',
                ),
              ]),
            ]),
            tr([
              td([
                code([Component.text('BlocBuilder<B, S>')]),
              ]),
              td([
                apiLink(
                  DocSymbol.blocSignalBuilder,
                  label: 'BlocSignalBuilder<B, S>',
                ),
              ]),
            ]),
            tr([
              td([
                code([Component.text('BlocListener<B, S>')]),
              ]),
              td([
                apiLink(
                  DocSymbol.blocSignalListener,
                  label: 'BlocSignalListener<B, S>',
                ),
              ]),
            ]),
            tr([
              td([
                code([Component.text('BlocConsumer<B, S>')]),
              ]),
              td([
                apiLink(
                  DocSymbol.blocSignalConsumer,
                  label: 'BlocSignalConsumer<B, S>',
                ),
              ]),
            ]),
            tr([
              td([
                code([Component.text('BlocSelector<B, S, T>')]),
              ]),
              td([
                apiLink(
                  DocSymbol.blocSignalSelector,
                  label: 'BlocSignalSelector<B, S, T>',
                ),
              ]),
            ]),
            tr([
              td([
                code([Component.text('context.read<B>()')]),
              ]),
              td([apiLink(DocSymbol.contextRead, label: 'context.read<B>()')]),
            ]),
            tr([
              td([
                code([Component.text('context.select<B, T>((b) => ...)')]),
              ]),
              td([
                apiLink(
                  DocSymbol.contextSelect,
                  label: 'context.select<B, R>((b) => ...)',
                ),
              ]),
            ]),
            tr([
              td([
                code([Component.text('context.watch<B>().state')]),
              ]),
              td([
                Component.text('Use '),
                apiLink(
                  DocSymbol.contextSelect,
                  label: 'context.select<B, R>()',
                ),
                Component.text(' or '),
                apiLink(
                  DocSymbol.blocSignalBuilder,
                  label: 'BlocSignalBuilder<B, S>',
                ),
                Component.text(
                  ' (context.watch in BlocSignal tracks provider instance only)',
                ),
              ]),
            ]),
            tr([
              td([
                code([Component.text('blocTest<B, S>(seed: ...)')]),
              ]),
              td([
                apiLink(
                  DocSymbol.blocSignalTest,
                  label:
                      'blocSignalTest<B, S>(build: () => B(initialState: ...))',
                ),
              ]),
            ]),
          ]),
        ]),
      ]),

      // 3. Cubit Migration
      section(id: 'cubit-migration', classes: 'docs-section', [
        h2([Component.text('Cubit Migration')]),
        const DocsCodeBlock(
          title: 'Side-by-Side: Cubit',
          language: 'dart',
          code: '''
// --- BEFORE: package:bloc ---
import 'package:flutter_bloc/flutter_bloc.dart';

class CounterCubit extends Cubit<int> {
  CounterCubit() : super(0);
  void increment() => emit(state + 1);
}

// --- AFTER: bloc_signals ---
import 'package:bloc_signals/bloc_signals.dart';

class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);
  void increment() => emit(stateValue + 1);
}''',
        ),
      ]),

      // 4. Bloc & Event Migration
      section(id: 'bloc-migration', classes: 'docs-section', [
        h2([Component.text('Bloc & Event Migration')]),
        const DocsCodeBlock(
          title: 'Side-by-Side: Bloc with Transformers',
          language: 'dart',
          code: '''
// --- BEFORE: package:bloc ---
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  SearchBloc() : super(SearchInitial()) {
    on<QuerySubmitted>(
      (event, emit) async => _onSearch(event, emit),
      transformer: restartable(),
    );
  }
}

// --- AFTER: bloc_signals ---
import 'package:bloc_signals/bloc_signals.dart';

class SearchBloc extends BlocSignal<SearchEvent, SearchState> {
  SearchBloc() : super(initialState: SearchInitial()) {
    on<QuerySubmitted>(
      (event, emit) async => _onSearch(event, emit),
      transformer: restartable(), // Zero-stream pure function transformer!
    );
  }
}''',
        ),
      ]),

      // 5. Flutter UI Migration
      section(id: 'ui-migration', classes: 'docs-section', [
        h2([Component.text('Flutter UI Migration')]),
        const DocsCallout(
          type: CalloutType.warning,
          title: 'Migration Trap: context.watch vs State Changes',
          children: [
            p([
              Component.text(
                'In classic flutter_bloc, context.watch<B>().state rebuilt widgets on every state emission. '
                'In BlocSignal, context.watch only tracks provider instance replacement. '
                'To rebuild widgets on state changes, use context.select<B, R>((b) => ...) or BlocSignalBuilder<B, S>.',
              ),
            ]),
          ],
        ),
        const DocsCodeBlock(
          title: 'Side-by-Side: Flutter Widgets & Context Extensions',
          language: 'dart',
          code: '''
// --- BEFORE: flutter_bloc ---
// 1. Reading actions
context.read<CounterBloc>().add(Increment());

// 2. Watching state in build()
final count = context.watch<CounterBloc>().state;

// 3. Declarative builder
BlocBuilder<CounterCubit, int>(
  builder: (context, count) => Text('\$count'),
);

// --- AFTER: bloc_signals_flutter ---
// 1. Reading actions
context.read<CounterBloc>().add(Increment());

// 2. Selecting state in build()
final count = context.select<CounterBloc, int>((b) => b.stateValue);

// 3. Declarative builder
BlocSignalBuilder<CounterCubit, int>(
  builder: (context, count) => Text('\$count'),
);''',
        ),
      ]),

      // 6. Unit Test Migration
      section(id: 'testing-migration', classes: 'docs-section', [
        h2([Component.text('Unit Test Migration')]),
        p([
          Component.text(
            'In bloc_signals_test, state seeding is performed directly in the build constructor closure rather than through a separate seed parameter:',
          ),
        ]),
        const DocsCodeBlock(
          title: 'Side-by-Side: Unit Tests',
          language: 'dart',
          code: '''
// --- BEFORE: bloc_test ---
blocTest<CounterCubit, int>(
  'emits [11] when increment is called with seed 10',
  build: () => CounterCubit(),
  seed: () => 10,
  act: (cubit) => cubit.increment(),
  expect: () => [11],
);

// --- AFTER: bloc_signals_test ---
blocSignalTest<CounterCubit, int>(
  'emits [11] when increment is called with initial state 10',
  build: () => CounterCubit(initialState: 10),
  act: (cubit) => cubit.increment(),
  expect: () => [11],
);''',
        ),
      ]),
    ]);
  }
}
