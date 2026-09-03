import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_scroll_mixin_example/main.dart';
import 'package:infinite_scroll_mixin_example/src/controllers/paginated_posts_controller.dart';
import 'package:infinite_scroll_mixin_example/src/controllers/paging_scroll_controller.dart';
import 'package:infinite_scroll_mixin_example/src/models/post.dart';

void main() {
  group('PagingScrollController (Pattern A)', () {
    test('initializes with false and disposes cleanly', () async {
      final controller = PagingScrollController(threshold: 200.0);
      expect(controller.stateValue, isFalse);

      // Disposal should be safe and idempotent
      controller.dispose();
      await controller.close();
      expect(controller.isClosed, isTrue);
    });

    testWidgets('emits true when scroll offset reaches threshold',
        (tester) async {
      final controller = PagingScrollController(threshold: 200.0);
      final recordedStates = <bool>[];
      controller.createEffect(() {
        recordedStates.add(controller.stateValue);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              controller: controller,
              itemCount: 100,
              itemBuilder: (context, index) => SizedBox(
                height: 50,
                child: Text('Item $index'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially at top (offset 0, extentAfter is large)
      expect(controller.stateValue, isFalse);

      // Scroll so that extentAfter <= 200 (within 100px of max extent)
      final maxExtent = controller.position.maxScrollExtent;
      controller.jumpTo(maxExtent - 100);
      await tester.pumpAndSettle();

      expect(controller.stateValue, isTrue);

      // Scroll back up
      controller.jumpTo(0);
      await tester.pumpAndSettle();

      expect(controller.stateValue, isFalse);

      controller.dispose();
    });
  });

  group('PaginatedPostsController (Pattern B)', () {
    test('initial state and initial fetch', () async {
      final controller = PaginatedPostsController();
      expect(controller.stateValue.status, PostsStatus.initial);
      expect(controller.stateValue.posts, isEmpty);
      expect(controller.stateValue.hasReachedMax, isFalse);

      controller.add(const PostsFetched());
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(controller.stateValue.status, PostsStatus.success);
      expect(controller.stateValue.posts.length, 10);
      expect(controller.stateValue.hasReachedMax, isFalse);

      // Fetch page 2
      controller.add(const PostsFetched());
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(controller.stateValue.posts.length, 20);

      // Fetch page 3 (hits 30, marks max)
      controller.add(const PostsFetched());
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(controller.stateValue.posts.length, 30);
      expect(controller.stateValue.hasReachedMax, isTrue);

      // Subsequent fetch dropped when hasReachedMax is true
      controller.add(const PostsFetched());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(controller.stateValue.posts.length, 30);

      await controller.close();
    });

    test('search query resets pagination and filters posts', () async {
      final controller = PaginatedPostsController();
      controller.add(const PostsFetched());
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(controller.stateValue.posts.length, 10);

      // Search for specific query
      controller.add(const PostsSearchChanged('StatelessWidget'));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(controller.stateValue.searchQuery, 'StatelessWidget');
      expect(controller.stateValue.posts, isNotEmpty);
      for (final post in controller.stateValue.posts) {
        expect(post.title.contains('StatelessWidget'), isTrue);
      }

      await controller.close();
    });

    test('handles error gracefully when generator throws', () async {
      final controller = PaginatedPostsController(
        postGenerator: ({required count, required query, required startIndex}) {
          throw Exception('Network error');
        },
      );

      controller.add(const PostsFetched());
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(controller.stateValue.status, PostsStatus.failure);
      expect(controller.stateValue.posts, isEmpty);

      await controller.close();
    });

    test('safe double-dispose and close idempotency', () async {
      final controller = PaginatedPostsController();
      controller.dispose();
      await controller.close();
      expect(controller.isClosed, isTrue);
    });
  });

  group('SelfPagingPostsView Widget Tests', () {
    testWidgets('renders posts, filters on search, and scrolls to paginate',
        (tester) async {
      await tester.pumpWidget(const InfiniteScrollMixinApp());
      await tester.pumpAndSettle();

      expect(
        find.text('Self-Paging Controller (Stateless)'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Post 1:'),
        findsOneWidget,
      );

      // Filter by search text
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'CubitSignalMixin');
      await tester.pumpAndSettle();

      expect(
        find.textContaining('CubitSignalMixin Architecture'),
        findsWidgets,
      );

      // Clear search to show full list
      await tester.enterText(searchField, '');
      await tester.pumpAndSettle();

      // Scroll to bottom to trigger self-paging fetch
      final listView = find.byType(ListView);
      await tester.drag(listView, const Offset(0, -3000));
      await tester.pumpAndSettle();

      // Additional posts should now be loaded
      expect(find.byType(ListTile), findsWidgets);
    });
  });
}
