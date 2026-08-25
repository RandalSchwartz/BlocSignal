import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../docs_code_block.dart';
import '../docs_toc.dart';

/// Documentation page covering API caching and TTL expiration patterns.
class const DocsRecipeCachingPage({super.key}) extends StatelessComponent {
  static const List<TocHeading> headings = [
    TocHeading(
      title: 'Overview & Stale-While-Revalidate',
      anchor: 'overview-swr',
    ),
    TocHeading(title: 'Designing the Cache State Model', anchor: 'cache-model'),
    TocHeading(title: 'The Caching Cubit Pattern', anchor: 'caching-cubit'),
    TocHeading(
      title: 'Derived Status with computed()',
      anchor: 'derived-status',
    ),
    TocHeading(
      title: 'Cache Invalidation & Manual Refresh',
      anchor: 'manual-refresh',
    ),
  ];

  @override
  Component build(BuildContext context) {
    return article(classes: 'docs-article', [
      header(classes: 'docs-article-header', [
        div(classes: 'docs-badge', [
          Component.text('🛠️ Architecture Recipes'),
        ]),
        h1([Component.text('API Caching & TTL Expiration')]),
        p(classes: 'docs-lead', [
          Component.text(
            'Implement high-performance Stale-While-Revalidate caching with automatic Time-to-Live (TTL) expiration and background network synchronization.',
          ),
        ]),
      ]),

      // 1. Overview & Stale-While-Revalidate
      section(id: 'overview-swr', classes: 'docs-section', [
        h2([Component.text('Overview & Stale-While-Revalidate')]),
        p([
          Component.text(
            'Modern mobile and web applications deliver instant responsiveness by serving cached data immediately '
            'while silently fetching fresh updates in the background. With BlocSignal, cached entries render with 0ms delay on initial build, '
            'and signals notify the UI when fresh network data arrives.',
          ),
        ]),
      ]),

      // 2. Designing the Cache State Model
      section(id: 'cache-model', classes: 'docs-section', [
        h2([Component.text('Designing the Cache State Model')]),
        const DocsCodeBlock(
          title: 'lib/cache_state.dart',
          language: 'dart',
          code: '''
class CacheEntry<T> {
  const CacheEntry({
    required this.data,
    required this.fetchedAt,
    this.isRefreshing = false,
  });

  final T data;
  final DateTime fetchedAt;
  final bool isRefreshing;

  bool isExpired(Duration ttl) =>
      DateTime.now().difference(fetchedAt) > ttl;

  CacheEntry<T> copyWith({
    T? data,
    DateTime? fetchedAt,
    bool? isRefreshing,
  }) => CacheEntry<T>(
    data: data ?? this.data,
    fetchedAt: fetchedAt ?? this.fetchedAt,
    isRefreshing: isRefreshing ?? this.isRefreshing,
  );
}''',
        ),
      ]),

      // 3. The Caching Cubit Pattern
      section(id: 'caching-cubit', classes: 'docs-section', [
        h2([Component.text('The Caching Cubit Pattern')]),
        const DocsCodeBlock(
          title: 'lib/news_feed_cubit.dart',
          language: 'dart',
          code: '''
import 'package:bloc_signals/bloc_signals.dart';

class NewsFeedCubit extends CubitSignal<CacheEntry<List<String>>?> {
  NewsFeedCubit({required this.repository}) : super(initialState: null);

  final NewsRepository repository;
  static const Duration cacheTtl = Duration(minutes: 5);

  Future<void> loadFeed({bool forceRefresh = false}) async {
    final current = stateValue;

    // 1. Serve fresh cache if still valid and not forcing refresh
    if (!forceRefresh && current != null && !current.isExpired(cacheTtl)) {
      return;
    }

    // 2. Mark background refresh while keeping existing cached data on screen
    if (current != null) {
      emit(current.copyWith(isRefreshing: true));
    }

    // 3. Fetch fresh data from network
    try {
      final items = await repository.fetchTopNews();
      emit(CacheEntry(
        data: items,
        fetchedAt: DateTime.now(),
        isRefreshing: false,
      ));
    } catch (error) {
      // Revert refreshing indicator while preserving existing data
      if (current != null) {
        emit(current.copyWith(isRefreshing: false));
      }
    }
  }
}''',
        ),
      ]),

      // 4. Derived Status with computed()
      section(id: 'derived-status', classes: 'docs-section', [
        h2([Component.text('Derived Status with computed()')]),
        p([
          Component.text(
            'Expose derived signals for UI components to inspect cache freshness without re-running expiration math inside build methods:',
          ),
        ]),
        const DocsCodeBlock(
          title: 'lib/news_feed_helpers.dart',
          language: 'dart',
          code: '''
extension NewsFeedDerived on NewsFeedCubit {
  /// Derived boolean signal indicating if current cached data is stale
  ReadonlySignal<bool> get isStale => computed(() {
    final current = state.value;
    if (current == null) return true;
    return current.isExpired(NewsFeedCubit.cacheTtl);
  });
}''',
        ),
      ]),

      // 5. Cache Invalidation & Manual Refresh
      section(id: 'manual-refresh', classes: 'docs-section', [
        h2([Component.text('Cache Invalidation & Pull-to-Refresh')]),
        p([
          Component.text(
            'Connect loadFeed(forceRefresh: true) directly to Flutter RefreshIndicator for smooth pull-to-refresh interactions:',
          ),
        ]),
        const DocsCodeBlock(
          title: 'lib/news_feed_view.dart',
          dart313Code: '''
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import 'news_feed_cubit.dart';

class NewsFeedView extends StatelessWidget {
  const NewsFeedView({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<NewsFeedCubit>();

    return BlocSignalBuilder<NewsFeedCubit, CachedData<List<String>>?>(
      builder: (context, cache) {
        if (cache == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: () => cubit.loadFeed(forceRefresh: true),
          child: ListView.builder(
            itemCount: cache.data.length,
            itemBuilder: (context, index) => ListTile(
              title: Text(cache.data[index]),
            ),
          ),
        );
      },
    );
  }
}''',
          dart35Code: '''
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import 'news_feed_cubit.dart';

class NewsFeedView extends StatelessWidget {
  const NewsFeedView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<NewsFeedCubit>();

    return BlocSignalBuilder<NewsFeedCubit, CachedData<List<String>>?>(
      builder: (context, cache) {
        if (cache == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: () => cubit.loadFeed(forceRefresh: true),
          child: ListView.builder(
            itemCount: cache.data.length,
            itemBuilder: (context, index) => ListTile(
              title: Text(cache.data[index]),
            ),
          ),
        );
      },
    );
  }
}''',
        ),
      ]),
    ]);
  }
}
