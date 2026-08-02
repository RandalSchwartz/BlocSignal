import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import '../posts/posts_bloc.dart';

class PostsView extends StatefulWidget {
  const PostsView({super.key});

  @override
  State<PostsView> createState() => _PostsViewState();
}

class _PostsViewState extends State<PostsView> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isBottom) {
      context.read<PostsBloc>().add(const PostsFetched());
    }
  }

  bool get _isBottom {
    if (!_scrollController.hasClients) return false;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    return currentScroll >= (maxScroll * 0.9);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Infinite Scroll Posts'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search posts...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (query) {
                context.read<PostsBloc>().add(PostsSearchChanged(query));
              },
            ),
          ),
        ),
      ),
      body: BlocSignalBuilder<PostsBloc, PostsState>(
        builder: (context, state) {
          switch (state.status) {
            case PostsStatus.initial:
              return const Center(child: CircularProgressIndicator());

            case PostsStatus.failure:
              return const Center(child: Text('Failed to load posts'));

            case PostsStatus.success:
              if (state.posts.isEmpty) {
                return const Center(child: Text('No posts found.'));
              }
              return ListView.builder(
                controller: _scrollController,
                itemCount: state.hasReachedMax
                    ? state.posts.length
                    : state.posts.length + 1,
                itemBuilder: (context, index) {
                  if (index >= state.posts.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final post = state.posts[index];
                  return ListTile(
                    leading: CircleAvatar(child: Text('${post.id}')),
                    title: Text(post.title),
                    subtitle: Text(post.body),
                  );
                },
              );
          }
        },
      ),
    );
  }
}
