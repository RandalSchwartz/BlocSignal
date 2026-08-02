import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import 'src/posts/posts_bloc.dart';
import 'src/views/posts_view.dart';

void main() {
  runApp(const InfiniteScrollApp());
}

class InfiniteScrollApp extends StatelessWidget {
  const InfiniteScrollApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSignalProvider<PostsBloc>(
      lazy: false,
      create: (context) => PostsBloc()..add(const PostsFetched()),
      child: MaterialApp(
        title: 'BlocSignal Infinite Scroll',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          useMaterial3: true,
        ),
        home: const PostsView(),
      ),
    );
  }
}
