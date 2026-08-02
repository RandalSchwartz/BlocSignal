import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';

/// Repository Model.
@immutable
class RepositoryItem {
  const RepositoryItem({
    required this.name,
    required this.owner,
    required this.stars,
    required this.description,
  });

  final String name;
  final String owner;
  final int stars;
  final String description;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RepositoryItem &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          owner == other.owner &&
          stars == other.stars &&
          description == other.description;

  @override
  int get hashCode =>
      name.hashCode ^ owner.hashCode ^ stars.hashCode ^ description.hashCode;
}

/// GitHub Search Client Repository.
class GithubRepository {
  const GithubRepository();

  static const List<RepositoryItem> _kMockRepos = [
    RepositoryItem(
        name: 'bloc',
        owner: 'felangel',
        stars: 11200,
        description:
            'A predictable state management library for Dart & Flutter'),
    RepositoryItem(
        name: 'signals.dart',
        owner: 'rodydavis',
        stars: 1500,
        description: 'Reactive state management primitives for Dart & Flutter'),
    RepositoryItem(
        name: 'bloc_signals',
        owner: 'RandalSchwartz',
        stars: 850,
        description: 'Bridging BLoC pattern with synchronous signals v7'),
    RepositoryItem(
        name: 'flutter',
        owner: 'flutter',
        stars: 165000,
        description: 'Build fast multi-platform apps from a single codebase'),
  ];

  Future<List<RepositoryItem>> search(String query) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final q = query.trim().toLowerCase();
    if (q == 'error') {
      throw Exception('GitHub API rate limit exceeded');
    }
    return _kMockRepos
        .where((item) =>
            item.name.toLowerCase().contains(q) ||
            item.description.toLowerCase().contains(q) ||
            item.owner.toLowerCase().contains(q))
        .toList();
  }
}

/// Search State.
sealed class GithubSearchState {
  const GithubSearchState();
}

final class SearchEmpty extends GithubSearchState {
  const SearchEmpty();
}

final class SearchLoading extends GithubSearchState {
  const SearchLoading();
}

final class SearchSuccess extends GithubSearchState {
  const SearchSuccess(this.items);
  final List<RepositoryItem> items;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchSuccess &&
          runtimeType == other.runtimeType &&
          _listEquals(items, other.items);

  @override
  int get hashCode => items.length.hashCode;

  static bool _listEquals(List<RepositoryItem> a, List<RepositoryItem> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

final class SearchError extends GithubSearchState {
  const SearchError(this.message);
  final String message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchError &&
          runtimeType == other.runtimeType &&
          message == other.message;

  @override
  int get hashCode => message.hashCode;
}

/// Search Event.
final class SearchQueryChanged {
  const SearchQueryChanged(this.query);
  final String query;
}

/// [GithubSearchBlocSignal] uses restartable event transformer for debounced search.
class GithubSearchBlocSignal
    extends BlocSignal<SearchQueryChanged, GithubSearchState> {
  GithubSearchBlocSignal(
      {GithubRepository repository = const GithubRepository()})
      : _repository = repository,
        super(initialState: const SearchEmpty()) {
    on<SearchQueryChanged>(
      _onQueryChanged,
      transformer: restartable(),
    );
  }

  final GithubRepository _repository;

  Future<void> _onQueryChanged(
      SearchQueryChanged event, void Function(GithubSearchState) emit) async {
    final query = event.query.trim();
    if (query.isEmpty) {
      emit(const SearchEmpty());
      return;
    }

    emit(const SearchLoading());
    try {
      final items = await _repository.search(query);
      if (items.isEmpty) {
        emit(const SearchError('No repositories found matching query'));
      } else {
        emit(SearchSuccess(items));
      }
    } catch (e) {
      emit(SearchError(e.toString()));
    }
  }
}

void main() {
  runApp(const GithubSearchApp());
}

class GithubSearchApp extends StatelessWidget {
  const GithubSearchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GitHub Search',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: BlocSignalProvider<GithubSearchBlocSignal>(
        create: (_) => GithubSearchBlocSignal(),
        child: const GithubSearchPage(),
      ),
    );
  }
}

class GithubSearchPage extends StatelessWidget {
  const GithubSearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<GithubSearchBlocSignal>();
    return Scaffold(
      appBar: AppBar(title: const Text('GitHub Search')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search Repositories',
                hintText: 'e.g. bloc, signals, flutter',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => bloc.add(SearchQueryChanged(val)),
            ),
            const SizedBox(height: 16),
            Expanded(
              child:
                  BlocSignalBuilder<GithubSearchBlocSignal, GithubSearchState>(
                builder: (context, state) {
                  return switch (state) {
                    SearchEmpty() => const Center(
                        child: Text('Type a query to search GitHub.')),
                    SearchLoading() =>
                      const Center(child: CircularProgressIndicator()),
                    SearchSuccess(:final items) => ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: ListTile(
                              title: Text('${item.owner}/${item.name}'),
                              subtitle: Text(item.description),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star,
                                      color: Colors.amber, size: 18),
                                  const SizedBox(width: 4),
                                  Text('${item.stars}'),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    SearchError(:final message) => Center(
                        child: Text(
                          message,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                  };
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
