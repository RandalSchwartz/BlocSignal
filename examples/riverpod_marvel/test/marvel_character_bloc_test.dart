import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_marvel_example/blocs/marvel_character_bloc.dart';
import 'package:riverpod_marvel_example/services/marvel_repository.dart';

void main() {
  group('MarvelCharacterBloc (Riverpod Port)', () {
    late MarvelCharacterBloc bloc;

    setUp(() {
      bloc = MarvelCharacterBloc(repository: MarvelRepository());
    });

    tearDown(() async {
      await bloc.close();
    });

    test('initial state loads all marvel characters', () async {
      expect(bloc.stateValue, isA<MarvelLoading>());
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(bloc.stateValue, isA<MarvelLoaded>());
      final loadedState = bloc.stateValue as MarvelLoaded;
      expect(loadedState.characters.length, greaterThan(0));
    });

    test('FetchCharacters query filters results', () async {
      bloc.add(const FetchCharacters('Spider'));
      expect(bloc.stateValue, isA<MarvelLoading>());

      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(bloc.stateValue, isA<MarvelLoaded>());
      final loadedState = bloc.stateValue as MarvelLoaded;
      expect(loadedState.characters.every((c) => c.name.contains('Spider')),
          isTrue);
    });
  });
}
