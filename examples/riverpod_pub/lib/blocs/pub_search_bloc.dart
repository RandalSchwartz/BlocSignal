import 'package:bloc_signals/bloc_signals.dart';
import 'package:flutter/foundation.dart';
import '../models/pub_package.dart';
import '../services/pub_repository.dart';

/// Base sealed event for Pub search.
@immutable
sealed class PubSearchEvent {
  const PubSearchEvent();
}

/// Event dispatched when query text changes.
final class SearchQueryChanged extends PubSearchEvent {
  const SearchQueryChanged(this.query);
  final String query;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchQueryChanged && other.query == query;

  @override
  int get hashCode => query.hashCode;
}

/// Base sealed state for Pub search.
@immutable
sealed class PubSearchState {
  const PubSearchState();
}

/// Initial search state before any query is typed.
final class PubSearchInitial extends PubSearchState {
  const PubSearchInitial();
}

/// Search in progress state.
final class PubSearchLoading extends PubSearchState {
  const PubSearchLoading();
}

/// Search completed state with results.
final class PubSearchSuccess extends PubSearchState {
  const PubSearchSuccess(this.packages);
  final List<PubPackage> packages;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PubSearchSuccess && listEquals(other.packages, packages);

  @override
  int get hashCode => Object.hashAll(packages);
}

/// Search failed state with error message.
final class PubSearchError extends PubSearchState {
  const PubSearchError(this.message);
  final String message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PubSearchError && other.message == message;

  @override
  int get hashCode => message.hashCode;
}

/// BLoC managing Pub package search with streamless event transformers.
///
/// Demonstrates [restartable] transformer behavior, ensuring subsequent query
/// edits immediately cancel lingering network requests without requiring Rx streams.
class PubSearchBloc extends BlocSignal<PubSearchEvent, PubSearchState> {
  /// Creates a [PubSearchBloc] with injected [PubRepository].
  PubSearchBloc({required PubRepository repository})
      : _repository = repository,
        super(initialState: const PubSearchInitial()) {
    on<SearchQueryChanged>(
      _onSearchQueryChanged,
      transformer: restartable(),
    );
  }

  final PubRepository _repository;

  Future<void> _onSearchQueryChanged(
    SearchQueryChanged event,
    void Function(PubSearchState) emit,
  ) async {
    final query = event.query.trim();
    if (query.isEmpty) {
      emit(const PubSearchInitial());
      return;
    }

    emit(const PubSearchLoading());
    try {
      final packages = await _repository.search(query);
      emit(PubSearchSuccess(packages));
    } catch (error) {
      emit(PubSearchError(error.toString()));
    }
  }
}
