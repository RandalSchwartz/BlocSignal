import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../docs_callout.dart';
import '../docs_code_block.dart';
import '../docs_toc.dart';

/// Documentation page covering streamless event concurrency transformers in BlocSignal.
class const DocsEventTransformersPage({super.key}) extends StatelessComponent {
  static const List<TocHeading> headings = [
    TocHeading(
      title: 'Streamless Concurrency Architecture',
      anchor: 'streamless-architecture',
    ),
    TocHeading(title: 'droppable()', anchor: 'droppable-transformer'),
    TocHeading(title: 'sequential()', anchor: 'sequential-transformer'),
    TocHeading(title: 'restartable()', anchor: 'restartable-transformer'),
    TocHeading(
      title: 'Custom Transformer Recipes',
      anchor: 'custom-transformers',
    ),
  ];

  @override
  Component build(BuildContext context) {
    return article(classes: 'docs-article', [
      header(classes: 'docs-article-header', [
        div(classes: 'docs-badge', [Component.text('🧠 Core Concepts')]),
        h1([Component.text('Event Transformers')]),
        p(classes: 'docs-lead', [
          Component.text(
            'Control asynchronous event execution with zero Rx Stream overhead using pure Dart higher-order functions and Mutex coordination.',
          ),
        ]),
      ]),

      // 1. Streamless Concurrency Architecture
      section(id: 'streamless-architecture', classes: 'docs-section', [
        h2([Component.text('Streamless Concurrency Architecture')]),
        p([
          Component.text(
            'Unlike classic BLoC which depends on package:bloc_concurrency and Rx Streams, BlocSignal event transformers '
            'are implemented as pure Dart higher-order functions: (event, handler, emit) => FutureOr<void>. '
            'This completely avoids Stream subscription allocations and microtask queue delays.',
          ),
        ]),
        const DocsCallout(
          type: CalloutType.tip,
          title: 'Zero Stream Allocations',
          children: [
            p([
              Component.text(
                'By coordinating Futures directly rather than piping through Rx operators, transformer overhead is reduced to zero during high-frequency event bursts.',
              ),
            ]),
          ],
        ),
      ]),

      // 2. droppable()
      section(id: 'droppable-transformer', classes: 'docs-section', [
        h2([Component.text('droppable()')]),
        p([
          Component.text(
            'Ignores and drops any incoming events while the current event handler is actively processing an asynchronous Future. '
            'Ideal for submit buttons, login actions, and checkout forms to prevent duplicate requests.',
          ),
        ]),
        const DocsCodeBlock(
          filename: 'droppable_example.dart',
          dart313Code: '''
on<SubmitFormPressed>((event, emit) async {
  emit(const FormSubmitting());
  await api.postPayload(event.data);
  emit(const FormSuccess());
}, transformer: droppable());
''',
          dart35Code: '''
on<SubmitFormPressed>((event, emit) async {
  emit(const FormSubmitting());
  await _api.postPayload(event.data);
  emit(const FormSuccess());
}, transformer: droppable());
''',
        ),
      ]),

      // 3. sequential()
      section(id: 'sequential-transformer', classes: 'docs-section', [
        h2([Component.text('sequential()')]),
        p([
          Component.text(
            'Queues and processes incoming events strictly in the order they were dispatched using an internal Mutex lock. '
            'Guarantees FIFO order without dropping events.',
          ),
        ]),
        const DocsCodeBlock(
          filename: 'sequential_example.dart',
          dart313Code: '''
on<SyncDatabaseRecord>((event, emit) async {
  await database.syncRecord(event.record);
  emit(DatabaseSynced(event.record.id));
}, transformer: sequential());
''',
          dart35Code: '''
on<SyncDatabaseRecord>((event, emit) async {
  await _database.syncRecord(event.record);
  emit(DatabaseSynced(event.record.id));
}, transformer: sequential());
''',
        ),
      ]),

      // 4. restartable()
      section(id: 'restartable-transformer', classes: 'docs-section', [
        h2([Component.text('restartable()')]),
        p([
          Component.text(
            'Abandons prior in-flight emissions when a newer event of the same type arrives. '
            'Ideal for search typeaheads and autocomplete fields where only the latest query result matters.',
          ),
        ]),
        const DocsCodeBlock(
          filename: 'restartable_example.dart',
          dart313Code: '''
on<SearchQueryChanged>((event, emit) async {
  emit(const SearchLoading());
  final results = await searchService.query(event.text);
  emit(SearchResults(results));
}, transformer: restartable());
''',
          dart35Code: '''
on<SearchQueryChanged>((event, emit) async {
  emit(const SearchLoading());
  final results = await _searchService.query(event.text);
  emit(SearchResults(results));
}, transformer: restartable());
''',
        ),
      ]),

      // 5. Custom Transformer Recipes
      section(id: 'custom-transformers', classes: 'docs-section', [
        h2([Component.text('Custom Transformer Recipes')]),
        p([
          Component.text(
            'You can easily author custom transformers to satisfy bespoke concurrency requirements. '
            'Here is a custom debounce transformer written in pure Dart:',
          ),
        ]),
        const DocsCodeBlock(
          filename: 'debounce_transformer.dart',
          dart313Code: '''
import 'dart:async';
import 'package:bloc_signals/bloc_signals.dart';

EventTransformer<E, S> debounce<E, S>(Duration duration) {
  Timer? timer;
  return (event, handler, emit) {
    final completer = Completer<void>();
    timer?.cancel();
    timer = Timer(duration, () async {
      try {
        await handler(event, emit);
        completer.complete();
      } catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  };
}

// Usage in Bloc constructor:
// on<SearchInputChanged>(..., transformer: debounce(const Duration(milliseconds: 300)));
''',
          dart35Code: '''
import 'dart:async';
import 'package:bloc_signals/bloc_signals.dart';

EventTransformer<E, S> debounce<E, S>(Duration duration) {
  Timer? timer;
  return (event, handler, emit) {
    final completer = Completer<void>();
    timer?.cancel();
    timer = Timer(duration, () async {
      try {
        await handler(event, emit);
        completer.complete();
      } catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  };
}

// Usage in Bloc constructor:
// on<SearchInputChanged>(..., transformer: debounce(const Duration(milliseconds: 300)));
''',
        ),
      ]),
    ]);
  }
}
