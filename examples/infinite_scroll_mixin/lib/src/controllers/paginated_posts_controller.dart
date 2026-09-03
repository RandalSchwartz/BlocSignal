import 'dart:async';

import 'package:bloc_signals/bloc_signals.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../models/post.dart';

/// Events for the paginated posts domain flow.
sealed class PostsEvent {
  const PostsEvent();
}

/// Dispatched when the user reaches the scroll threshold to fetch the next page.
final class PostsFetched extends PostsEvent {
  const PostsFetched();
}

/// Dispatched when the search filter query changes.
final class PostsSearchChanged extends PostsEvent {
  const PostsSearchChanged(this.query);
  final String query;
}

/// Status of the paginated posts stream.
enum PostsStatus { initial, success, failure }

/// The immutable state representing paginated posts, status, and query.
@immutable
class PostsState {
  const PostsState({
    this.status = PostsStatus.initial,
    this.posts = const [],
    this.hasReachedMax = false,
    this.searchQuery = '',
  });

  final PostsStatus status;
  final List<Post> posts;
  final bool hasReachedMax;
  final String searchQuery;

  PostsState copyWith({
    PostsStatus? status,
    List<Post>? posts,
    bool? hasReachedMax,
    String? searchQuery,
  }) {
    return PostsState(
      status: status ?? this.status,
      posts: posts ?? this.posts,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PostsState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          listEquals(posts, other.posts) &&
          hasReachedMax == other.hasReachedMax &&
          searchQuery == other.searchQuery;

  @override
  int get hashCode =>
      Object.hash(status, Object.hashAll(posts), hasReachedMax, searchQuery);
}

/// A [ScrollController] that is also a [CubitSignalMixin] and [BlocSignalMixin].
///
/// **Pattern B: Zero-Bridge Self-Paging Controller**
/// The controller is both a Flutter [ScrollController] and a reactive [BlocSignalBase].
/// It listens to its own scroll geometry, triggering [PostsFetched] with
/// [droppable] concurrency so overlapping scroll fling events are cleanly dropped.
class PaginatedPostsController extends ScrollController
    with CubitSignalMixin<PostsState>, BlocSignalMixin<PostsEvent, PostsState> {
  PaginatedPostsController({
    this.threshold = 200.0,
    List<Post> Function({
      required int startIndex,
      required int count,
      required String query,
    })? postGenerator,
  }) : _postGenerator = postGenerator ?? defaultGeneratePosts {
    initCubitSignal(initialState: const PostsState());

    on<PostsFetched>(
      _onPostsFetched,
      transformer: droppable(),
    );

    on<PostsSearchChanged>(
      _onPostsSearchChanged,
      transformer: restartable(),
    );

    addListener(_onScrollChanged);
  }

  /// Remaining scroll extent threshold in logical pixels (default: 200.0).
  final double threshold;

  final List<Post> Function({
    required int startIndex,
    required int count,
    required String query,
  }) _postGenerator;

  bool _isControllerDisposed = false;

  void _onScrollChanged() {
    if (!hasClients) return;
    if (position.extentAfter <= threshold) {
      add(const PostsFetched());
    }
  }

  Future<void> _onPostsFetched(
    PostsFetched event,
    void Function(PostsState) emit,
  ) async {
    if (stateValue.hasReachedMax) return;

    try {
      if (stateValue.status == PostsStatus.initial) {
        final posts = _postGenerator(
          startIndex: 0,
          count: 10,
          query: stateValue.searchQuery,
        );
        return emit(stateValue.copyWith(
          status: PostsStatus.success,
          posts: posts,
          hasReachedMax: false,
        ));
      }

      final posts = _postGenerator(
        startIndex: stateValue.posts.length,
        count: 10,
        query: stateValue.searchQuery,
      );

      emit(posts.isEmpty
          ? stateValue.copyWith(hasReachedMax: true)
          : stateValue.copyWith(
              status: PostsStatus.success,
              posts: [...stateValue.posts, ...posts],
              hasReachedMax: stateValue.posts.length + posts.length >= 30,
            ));
    } catch (_) {
      emit(stateValue.copyWith(status: PostsStatus.failure));
    }
  }

  Future<void> _onPostsSearchChanged(
    PostsSearchChanged event,
    void Function(PostsState) emit,
  ) async {
    final posts = _postGenerator(
      startIndex: 0,
      count: 10,
      query: event.query,
    );
    emit(stateValue.copyWith(
      status: PostsStatus.success,
      posts: posts,
      hasReachedMax: false,
      searchQuery: event.query,
    ));
  }

  /// Default mock post generator.
  static List<Post> defaultGeneratePosts({
    required int startIndex,
    required int count,
    required String query,
  }) {
    final all = List.generate(
      30,
      (i) => Post(
        id: i + 1,
        title:
            'Post ${i + 1}: ${i % 2 == 0 ? "CubitSignalMixin Architecture" : "StatelessWidget Pagination"}',
        body:
            'Demonstrating zero-glue self-paging controllers in post ${i + 1}.',
      ),
    );

    final filtered = query.isEmpty
        ? all
        : all
            .where((p) => p.title.toLowerCase().contains(query.toLowerCase()))
            .toList();

    if (startIndex >= filtered.length) return const [];
    final endIndex = (startIndex + count).clamp(0, filtered.length);
    return filtered.sublist(startIndex, endIndex);
  }

  @override
  void dispose() {
    if (_isControllerDisposed) return;
    _isControllerDisposed = true;
    removeListener(_onScrollChanged);
    close();
    super.dispose();
  }

  @override
  Future<void> close() async {
    if (!_isControllerDisposed) {
      _isControllerDisposed = true;
      removeListener(_onScrollChanged);
      super.dispose();
    }
    await super.close();
  }
}
