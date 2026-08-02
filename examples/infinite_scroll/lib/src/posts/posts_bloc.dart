import 'package:bloc_signals/bloc_signals.dart';
import 'package:flutter/foundation.dart';
import '../models/post.dart';

sealed class PostsEvent {
  const PostsEvent();
}

final class PostsFetched extends PostsEvent {
  const PostsFetched();
}

final class PostsSearchChanged extends PostsEvent {
  const PostsSearchChanged(this.query);
  final String query;
}

enum PostsStatus { initial, success, failure }

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

class PostsBloc extends BlocSignal<PostsEvent, PostsState> {
  PostsBloc() : super(initialState: const PostsState()) {
    on<PostsFetched>((event, emit) async {
      if (stateValue.hasReachedMax) return;

      try {
        if (stateValue.status == PostsStatus.initial) {
          final posts = _generatePosts(
              startIndex: 0, count: 10, query: stateValue.searchQuery);
          return emit(stateValue.copyWith(
            status: PostsStatus.success,
            posts: posts,
            hasReachedMax: false,
          ));
        }

        final posts = _generatePosts(
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
    }, transformer: droppable());

    on<PostsSearchChanged>((event, emit) async {
      final posts =
          _generatePosts(startIndex: 0, count: 10, query: event.query);
      emit(stateValue.copyWith(
        status: PostsStatus.success,
        posts: posts,
        hasReachedMax: false,
        searchQuery: event.query,
      ));
    }, transformer: restartable());
  }

  static List<Post> _generatePosts({
    required int startIndex,
    required int count,
    required String query,
  }) {
    final all = List.generate(
      30,
      (i) => Post(
        id: i + 1,
        title:
            'Post ${i + 1}: ${i % 2 == 0 ? "BlocSignal Reactivity" : "Flutter Architecture"}',
        body: 'This is the detailed body content for post number ${i + 1}.',
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
}
