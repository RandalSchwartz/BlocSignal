import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import 'blocs/pub_search_bloc.dart';
import 'services/pub_repository.dart';

void main() {
  runApp(const RiverpodPubApp());
}

/// Root widget for the Riverpod Pub search comparison application.
class RiverpodPubApp extends StatelessWidget {
  /// Creates a [RiverpodPubApp].
  const RiverpodPubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Riverpod Pub Search (BlocSignal Port)',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: BlocSignalProvider<PubSearchBloc>(
        create: (_) => PubSearchBloc(repository: PubRepository()),
        child: const PubSearchScreen(),
      ),
    );
  }
}

/// Screen displaying pub package search input and results list.
class PubSearchScreen extends StatelessWidget {
  /// Creates a [PubSearchScreen].
  const PubSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<PubSearchBloc>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pub Packages (Riverpod Port)'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search packages on pub.dev',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (query) => bloc.add(SearchQueryChanged(query)),
            ),
          ),
          Expanded(
            child: BlocSignalBuilder<PubSearchBloc, PubSearchState>(
              builder: (context, state) {
                return switch (state) {
                  PubSearchInitial() => const Center(
                      child: Text('Type a query to search pub packages.'),
                    ),
                  PubSearchLoading() => const Center(
                      child: CircularProgressIndicator(),
                    ),
                  PubSearchError(message: final msg) => Center(
                      child: Text('Error: $msg',
                          style: const TextStyle(color: Colors.red)),
                    ),
                  PubSearchSuccess(packages: final pkgs) => pkgs.isEmpty
                      ? const Center(child: Text('No matching packages found.'))
                      : ListView.builder(
                          itemCount: pkgs.length,
                          itemBuilder: (context, index) {
                            final pkg = pkgs[index];
                            return ListTile(
                              leading: CircleAvatar(
                                child: Text(pkg.name[0].toUpperCase()),
                              ),
                              title: Text(
                                pkg.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(pkg.description),
                              trailing: Chip(label: Text('v${pkg.version}')),
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
