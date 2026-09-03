import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';

import 'src/controllers/paginated_posts_controller.dart';
import 'src/views/self_paging_posts_view.dart';

void main() {
  runApp(const InfiniteScrollMixinApp());
}

/// Root application widget demonstrating the self-paging mixin architecture.
class InfiniteScrollMixinApp extends StatelessWidget {
  const InfiniteScrollMixinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSignalProvider<PaginatedPostsController>(
      lazy: false,
      create: (context) =>
          PaginatedPostsController()..add(const PostsFetched()),
      child: MaterialApp(
        title: 'BlocSignal Mixin Infinite Scroll',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const SelfPagingPostsView(),
      ),
    );
  }
}
