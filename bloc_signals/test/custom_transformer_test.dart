import 'dart:async';
import 'package:bloc_signals/bloc_signals.dart';
import 'package:test/test.dart';

// Custom Event Concurrency Transformers for testing API resilience.

/// Custom debounce transformer delaying event execution until [duration] passes without new events.
EventTransformer<E, S> debounce<E, S>(Duration duration) {
  Timer? timer;
  return (event, handler, emit) {
    timer?.cancel();
    timer = Timer(duration, () => handler(event, emit));
  };
}

/// Custom filtering transformer executing [handler] only if [predicate] returns true.
EventTransformer<E, S> filterEvents<E, S>(bool Function(E) predicate) {
  return (event, handler, emit) {
    if (predicate(event)) {
      handler(event, emit);
    }
  };
}

// Sealed Test Events
sealed class SearchEvent {}

final class QueryChanged extends SearchEvent {
  QueryChanged(this.query);
  final String query;
}

final class FilteredQuery extends SearchEvent {
  FilteredQuery(this.value);
  final int value;
}

// Test Bloc utilizing custom event transformers.
class CustomTransformerBloc extends BlocSignal<SearchEvent, String> {
  CustomTransformerBloc({
    Duration debounceDuration = const Duration(milliseconds: 50),
  }) : super(initialState: '') {
    on<QueryChanged>(
      (event, emit) => emit(event.query),
      transformer: debounce(debounceDuration),
    );

    on<FilteredQuery>(
      (event, emit) => emit('Value:${event.value}'),
      transformer: filterEvents((event) => event.value > 10),
    );
  }
}

void main() {
  group('Custom Event Concurrency Transformers', () {
    test('debounce transformer delays execution and drops intermediate events',
        () async {
      final bloc = CustomTransformerBloc(
        debounceDuration: const Duration(milliseconds: 30),
      );

      bloc.add(QueryChanged('f'));
      bloc.add(QueryChanged('fl'));
      bloc.add(QueryChanged('flu'));
      bloc.add(QueryChanged('flutter'));

      // Initial state is unchanged immediately
      expect(bloc.stateValue, equals(''));

      // Wait for debounce timer to fire
      await Future<void>.delayed(const Duration(milliseconds: 60));

      // Only final query was processed
      expect(bloc.stateValue, equals('flutter'));

      await bloc.close();
    });

    test('filterEvents transformer ignores events failing predicate',
        () async {
      final bloc = CustomTransformerBloc();

      bloc.add(FilteredQuery(5));
      expect(bloc.stateValue, equals(''));

      bloc.add(FilteredQuery(15));
      expect(bloc.stateValue, equals('Value:15'));

      await bloc.close();
    });
  });
}
