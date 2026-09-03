import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';

import '../controllers/paginated_posts_controller.dart';

/// A 100% [StatelessWidget] infinite scroll view powered by
/// [PaginatedPostsController].
///
/// Because [PaginatedPostsController] is simultaneously a [ScrollController]
/// and a [BlocSignalBase], there is zero widget-level plumbing:
/// - No [StatefulWidget]
/// - No [State.initState]
/// - No [State.dispose]
/// - No manual [ScrollController.addListener]
/// - No manual scroll threshold math
class SelfPagingPostsView extends StatelessWidget {
  const SelfPagingPostsView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.read<PaginatedPostsController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Self-Paging Controller (Stateless)'),
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
                controller.add(PostsSearchChanged(query));
              },
            ),
          ),
        ),
      ),
      body: BlocSignalBuilder<PaginatedPostsController, PostsState>(
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
                controller: controller,
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
