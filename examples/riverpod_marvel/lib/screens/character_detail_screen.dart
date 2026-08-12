import 'package:flutter/material.dart';
import '../models/marvel_character.dart';

/// Screen displaying full bio and details for a selected [MarvelCharacter].
class CharacterDetailScreen extends StatelessWidget {
  /// Creates a [CharacterDetailScreen].
  const CharacterDetailScreen({required this.character, super.key});

  /// The character whose details are rendered.
  final MarvelCharacter character;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(character.name),
        backgroundColor: Colors.red.shade900,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 250,
              width: double.infinity,
              color: Colors.black12,
              child: Image.network(
                character.thumbnailUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.person,
                  size: 100,
                  color: Colors.grey,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    character.name,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Chip(
                    label: Text('ID: ${character.id}'),
                    backgroundColor: Colors.red.shade100,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Biography',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    character.description.isNotEmpty
                        ? character.description
                        : 'No official description available for this character.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
