import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import 'blocs/marvel_character_bloc.dart';
import 'screens/character_detail_screen.dart';
import 'services/marvel_repository.dart';

void main() {
  runApp(const RiverpodMarvelApp());
}

/// Root widget for the Riverpod Marvel comparison application.
class RiverpodMarvelApp extends StatelessWidget {
  /// Creates a [RiverpodMarvelApp].
  const RiverpodMarvelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Riverpod Marvel (BlocSignal Port)',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          primary: Colors.red.shade900,
        ),
        useMaterial3: true,
      ),
      home: BlocSignalProvider<MarvelCharacterBloc>(
        create: (_) => MarvelCharacterBloc(repository: MarvelRepository()),
        child: const MarvelHomeScreen(),
      ),
    );
  }
}

/// Home screen displaying Marvel characters list and search bar.
class MarvelHomeScreen extends StatelessWidget {
  /// Creates a [MarvelHomeScreen].
  const MarvelHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<MarvelCharacterBloc>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Marvel Characters (Riverpod Port)'),
        backgroundColor: Colors.red.shade900,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search Marvel Characters',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (query) => bloc.add(FetchCharacters(query)),
            ),
          ),
          Expanded(
            child: BlocSignalBuilder<MarvelCharacterBloc, MarvelState>(
              builder: (context, state) {
                return switch (state) {
                  MarvelLoading() => const Center(
                      child: CircularProgressIndicator(),
                    ),
                  MarvelError(message: final msg) => Center(
                      child: Text('Error: $msg',
                          style: const TextStyle(color: Colors.red)),
                    ),
                  MarvelLoaded(characters: final characters) => characters
                          .isEmpty
                      ? const Center(
                          child: Text('No Marvel characters found.'),
                        )
                      : ListView.builder(
                          itemCount: characters.length,
                          itemBuilder: (context, index) {
                            final character = characters[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.red.shade100,
                                child: Text(character.name[0]),
                              ),
                              title: Text(
                                character.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                character.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => CharacterDetailScreen(
                                      character: character,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                };
              },
            ),
          ),
        ],
      ),
    );
  }
}
