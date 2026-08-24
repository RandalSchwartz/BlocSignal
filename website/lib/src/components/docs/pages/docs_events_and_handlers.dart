import 'package:blocsignal_website/src/models/pub_api_registry.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../docs_callout.dart';
import '../docs_code_block.dart';
import '../docs_toc.dart';

/// Documentation page covering event dispatching, on<E> handler registration, and error handling in BlocSignal.
class const DocsEventsAndHandlersPage({super.key}) extends StatelessComponent {
  static const List<TocHeading> headings = [
    TocHeading(
      title: 'Event Registration with on<E>',
      anchor: 'event-registration',
    ),
    TocHeading(
      title: 'Single-Registration Rule',
      anchor: 'single-registration-rule',
    ),
    TocHeading(
      title: 'Concurrent Async Coordination',
      anchor: 'async-coordination',
    ),
    TocHeading(
      title: 'Error Handling & Fault Routing',
      anchor: 'error-handling',
    ),
    TocHeading(
      title: 'Dynamic Zone Event Tracing',
      anchor: 'zone-event-tracing',
    ),
  ];

  @override
  Component build(BuildContext context) {
    return article(classes: 'docs-article', [
      header(classes: 'docs-article-header', [
        div(classes: 'docs-badge', [Component.text('🧠 Core Concepts')]),
        h1([Component.text('Events & Handlers')]),
        p(classes: 'docs-lead', [
          Component.text('Master event-driven state pipelines in '),
          apiLink(DocSymbol.blocSignal),
          Component.text(
            ': handler registration, asynchronous coordination, error routing, and zone-based event tracing.',
          ),
        ]),
      ]),

      // 1. Event Registration with on<E>
      section(id: 'event-registration', classes: 'docs-section', [
        h2([Component.text('Event Registration with on<E>')]),
        p([
          Component.text('In '),
          apiLink(DocSymbol.blocSignal),
          Component.text(
            ', event handlers are registered inside constructor bodies using the ',
          ),
          apiLink(DocSymbol.blocSignalOn, label: 'on<E>((event, emit) => ...)'),
          Component.text(
            ' registry. Handlers receive the strongly-typed event payload and an ',
          ),
          apiLink(DocSymbol.blocSignalEmit, label: 'emit'),
          Component.text(' function to transition state.'),
        ]),
        const DocsCodeBlock(
          filename: 'counter_bloc.dart',
          dart313Code: '''
sealed class CounterEvent;
final class IncrementPressed extends CounterEvent;
final class DecrementPressed extends CounterEvent;

class CounterBloc() extends BlocSignal<CounterEvent, int> {
  this : super(initialState: 0) {
    on<IncrementPressed>((event, emit) => emit(stateValue + 1));
    on<DecrementPressed>((event, emit) => emit(stateValue - 1));
  }
}''',
          dart35Code: '''
sealed class CounterEvent {}
final class IncrementPressed extends CounterEvent {
  const IncrementPressed();
}
final class DecrementPressed extends CounterEvent {
  const DecrementPressed();
}

class CounterBloc extends BlocSignal<CounterEvent, int> {
  CounterBloc() : super(initialState: 0) {
    on<IncrementPressed>((event, emit) {
      emit(stateValue + 1);
    });

    on<DecrementPressed>((event, emit) {
      emit(stateValue - 1);
    });
  }
}''',
        ),
      ]),

      // 2. Single-Registration Rule
      section(id: 'single-registration-rule', classes: 'docs-section', [
        h2([Component.text('Single-Registration Rule')]),
        p([
          Component.text(
            'Each event type E can be registered at most once in a given BlocSignal. '
            'Attempting to register ',
          ),
          apiLink(DocSymbol.blocSignalOn, label: 'on<E>()'),
          Component.text(
            ' for the exact same event type twice will immediately throw a StateError during initialization.',
          ),
        ]),
        DocsCallout(
          type: CalloutType.warning,
          title: 'Duplicate Registration Detection',
          children: [
            p([
              Component.text('Registering '),
              apiLink(DocSymbol.blocSignalOn, label: 'on<MyEvent>'),
              Component.text(
                ' multiple times is disallowed to eliminate ambiguous execution order. '
                'Use polymorphic subclasses or consolidated handler functions instead.',
              ),
            ]),
          ],
        ),
      ]),

      // 3. Concurrent Async Coordination
      section(id: 'async-coordination', classes: 'docs-section', [
        h2([Component.text('Concurrent Async Coordination')]),
        p([
          Component.text(
            'Event handlers in BlocSignal support FutureOr<void>. When multiple asynchronous events are dispatched in rapid succession, '
            'handlers execute concurrently by default. You can control execution strategy by applying concurrency transformers.',
          ),
        ]),
        const DocsCodeBlock(
          filename: 'async_event_handling.dart',
          dart313Code: '''
class SearchBloc(final SearchService service)
    extends BlocSignal<SearchEvent, SearchState> {
  this : super(initialState: const SearchInitial()) {
    on<SearchQuerySubmitted>((event, emit) async {
      emit(const SearchLoading());
      try {
        final results = await service.search(event.query);
        emit(SearchSuccess(results));
      } catch (e, stack) {
        emit(SearchError(e.toString()));
      }
    }, transformer: restartable());
  }
}''',
          dart35Code: '''
class SearchBloc extends BlocSignal<SearchEvent, SearchState> {
  SearchBloc(this._service) : super(initialState: const SearchInitial()) {
    on<SearchQuerySubmitted>((event, emit) async {
      emit(const SearchLoading());
      try {
        final results = await _service.search(event.query);
        emit(SearchSuccess(results));
      } catch (e, stack) {
        emit(SearchError(e.toString()));
      }
    }, transformer: restartable());
  }

  final SearchService _service;
}''',
        ),
      ]),

      // 4. Error Handling & Fault Routing
      section(id: 'error-handling', classes: 'docs-section', [
        h2([Component.text('Error Handling & Fault Routing')]),
        p([
          Component.text(
            'BlocSignal enforces strict fault isolation between operational exceptions and programmer errors:',
          ),
        ]),
        ul(classes: 'docs-list', [
          li([
            strong([
              Component.text(
                'Operational Exceptions (Exception, FormatException, etc.): ',
              ),
            ]),
            Component.text(
              'Caught automatically and routed to onError(error, stackTrace) and registered BlocSignalObserver instances without crashing the application.',
            ),
          ]),
          li([
            strong([
              Component.text(
                'Programmer Errors (Error, RangeError, TypeError): ',
              ),
            ]),
            Component.text(
              'Rethrown immediately to fail fast in development and highlight code defects.',
            ),
          ]),
        ]),
      ]),

      // 5. Dynamic Zone Event Tracing
      section(id: 'zone-event-tracing', classes: 'docs-section', [
        h2([Component.text('Dynamic Zone Event Tracing')]),
        p([
          Component.text(
            'Whenever emit(newState) is called inside an on<E> handler, BlocSignal captures the causing event using Dart dynamic Zones. '
            'This means downstream observers receive a complete Transition(currentState, event, nextState) without requiring developers to pass the event explicitly to emit().',
          ),
        ]),
      ]),
    ]);
  }
}
