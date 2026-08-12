import '../models/marvel_character.dart';

/// Repository supplying Marvel character datasets.
class MarvelRepository {
  static const List<MarvelCharacter> _mockCharacters = [
    MarvelCharacter(
      id: '1009368',
      name: 'Iron Man',
      description:
          'Wounded, captured and forced to build a weapon by his enemies, billionaire industrialist Tony Stark instead created an advanced suit of armor to save his life and escape captivity.',
      thumbnailUrl:
          'https://i.annihil.us/u/prod/marvel/i/mg/9/c0/527bb7b37ff55.jpg',
    ),
    MarvelCharacter(
      id: '1009610',
      name: 'Spider-Man',
      description:
          'Bitten by a radioactive spider, high school student Peter Parker gained the speed, strength and powers of a spider.',
      thumbnailUrl:
          'https://i.annihil.us/u/prod/marvel/i/mg/3/50/526548a343e4b.jpg',
    ),
    MarvelCharacter(
      id: '1009220',
      name: 'Captain America',
      description:
          'Vowing to serve his country, Steve Rogers took the Super-Soldier Serum to become America’s one-man army.',
      thumbnailUrl:
          'https://i.annihil.us/u/prod/marvel/i/mg/3/50/537ba56d3108d.jpg',
    ),
    MarvelCharacter(
      id: '1009664',
      name: 'Thor',
      description:
          'As the Norse God of Thunder, Thor wields one of the greatest weapons ever made, the enchanted hammer Mjolnir.',
      thumbnailUrl:
          'https://i.annihil.us/u/prod/marvel/i/mg/d/d0/5269657a74350.jpg',
    ),
  ];

  /// Fetches character list with optional [query] filter.
  Future<List<MarvelCharacter>> fetchCharacters({String? query}) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (query == null || query.trim().isEmpty) {
      return _mockCharacters;
    }
    final filter = query.trim().toLowerCase();
    return _mockCharacters
        .where((c) =>
            c.name.toLowerCase().contains(filter) ||
            c.description.toLowerCase().contains(filter))
        .toList();
  }

  /// Fetches single character details by [id].
  Future<MarvelCharacter?> fetchCharacterById(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    try {
      return _mockCharacters.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }
}
