import 'package:bloc_signals/bloc_signals.dart';
import 'package:flutter/foundation.dart';
import '../models/marvel_character.dart';
import '../services/marvel_repository.dart';

@immutable
sealed class MarvelEvent {
  const MarvelEvent();
}

final class FetchCharacters extends MarvelEvent {
  const FetchCharacters([this.query]);
  final String? query;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FetchCharacters && other.query == query;

  @override
  int get hashCode => query.hashCode;
}

@immutable
sealed class MarvelState {
  const MarvelState();
}

final class MarvelLoading extends MarvelState {
  const MarvelLoading();
}

final class MarvelLoaded extends MarvelState {
  const MarvelLoaded(this.characters);
  final List<MarvelCharacter> characters;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MarvelLoaded && listEquals(other.characters, characters);

  @override
  int get hashCode => Object.hashAll(characters);
}

final class MarvelError extends MarvelState {
  const MarvelError(this.message);
  final String message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MarvelError && other.message == message;

  @override
  int get hashCode => message.hashCode;
}

/// BLoC for managing Marvel characters state.
class MarvelCharacterBloc extends BlocSignal<MarvelEvent, MarvelState> {
  MarvelCharacterBloc({required MarvelRepository repository})
      : _repository = repository,
        super(initialState: const MarvelLoading()) {
    on<FetchCharacters>(
      _onFetchCharacters,
      transformer: restartable(),
    );
    add(const FetchCharacters());
  }

  final MarvelRepository _repository;

  Future<void> _onFetchCharacters(
    FetchCharacters event,
    void Function(MarvelState) emit,
  ) async {
    emit(const MarvelLoading());
    try {
      final characters = await _repository.fetchCharacters(query: event.query);
      emit(MarvelLoaded(characters));
    } catch (e) {
      emit(MarvelError(e.toString()));
    }
  }
}
