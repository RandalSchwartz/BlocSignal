import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

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
    TocHeading(title: 'Unit Test Migration', anchor: 'testing-migration'),
  ];

  @override
  Component build(BuildContext context) {
    return article(classes: 'docs-article', [
      header(classes: 'docs-article-header', [
        div(classes: 'docs-badge', [Component.text('🔄 Migration Guides')]),
        h1([Component.text('Migrating from package:bloc & flutter_bloc')]),
        p(classes: 'docs-lead', [
          Component.text(
            'Step-by-step guide and side-by-side conversion patterns for transitioning from classic BLoC / flutter_bloc to BlocSignal.',
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
              td([Component.text('Cubit<State>')]),
              td([Component.text('CubitSignal<State>')]),
            ]),
            tr([
              td([Component.text('Bloc<Event, State>')]),
              td([Component.text('BlocSignal<Event, State>')]),
            ]),
            tr([
              td([Component.text('BlocProvider<B>')]),
              td([Component.text('BlocSignalProvider<B>')]),
            ]),
            tr([
              td([Component.text('BlocBuilder<B, S>')]),
              td([Component.text('BlocSignalBuilder<B, S>')]),
            ]),
            tr([
              td([Component.text('BlocListener<B, S>')]),
              td([Component.text('BlocSignalListener<B, S>')]),
            ]),
            tr([
              td([Component.text('BlocConsumer<B, S>')]),
              td([Component.text('BlocSignalConsumer<B, S>')]),
            ]),
            tr([
              td([Component.text('BlocSelector<B, S, T>')]),
              td([Component.text('BlocSignalSelector<B, S, T>')]),
            ]),
            tr([
              td([Component.text('blocTest<B, S>(seed: ...)')]),
              td([
                Component.text(
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
        const DocsCodeBlock(
          title: 'Side-by-Side: Flutter Widgets',
          language: 'dart',
          code: '''
// --- BEFORE: flutter_bloc ---
BlocProvider(
  create: (context) => CounterCubit(),
  child: BlocBuilder<CounterCubit, int>(
    builder: (context, count) => Text('\$count'),
  ),
);

// --- AFTER: bloc_signals_flutter ---
BlocSignalProvider(
  create: (context) => CounterCubit(),
  child: BlocSignalBuilder<CounterCubit, int>(
    builder: (context, count) => Text('\$count'),
  ),
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
