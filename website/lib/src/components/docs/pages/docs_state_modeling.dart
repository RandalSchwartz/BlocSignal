import 'package:blocsignal_website/src/models/pub_api_registry.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../docs_callout.dart';
import '../docs_code_block.dart';
import '../docs_toc.dart';

/// Documentation page covering state modeling, immutability, records, and equality in BlocSignal.
class const DocsStateModelingPage({super.key}) extends StatelessComponent {
  static const List<TocHeading> headings = [
    TocHeading(
      title: 'Immutability Fundamentals',
      anchor: 'immutability-fundamentals',
    ),
    TocHeading(title: 'Sealed Class Unions', anchor: 'sealed-class-unions'),
    TocHeading(title: 'Dart Records for State', anchor: 'dart-records'),
    TocHeading(
      title: 'Fast Immutable Collections',
      anchor: 'immutable-collections',
    ),
    TocHeading(
      title: 'Equality & De-duplication',
      anchor: 'equality-deduplication',
    ),
    TocHeading(
      title: 'Custom SignalOptions Comparators',
      anchor: 'custom-comparators',
    ),
  ];

  @override
  Component build(BuildContext context) {
    return article(classes: 'docs-article', [
      header(classes: 'docs-article-header', [
        div(classes: 'docs-badge', [Component.text('🧠 Core Concepts')]),
        h1([Component.text('State Modeling & Immutability')]),
        p(classes: 'docs-lead', [
          Component.text(
            'Master state architecture patterns in BlocSignal: sealed class unions, Dart records, immutable collections, and custom equality comparators.',
          ),
        ]),
      ]),

      // 1. Immutability Fundamentals
      section(id: 'immutability-fundamentals', classes: 'docs-section', [
        h2([Component.text('Immutability Fundamentals')]),
        p([
          Component.text('State in '),
          apiLink(DocSymbol.blocSignal),
          Component.text(' and '),
          apiLink(DocSymbol.cubitSignal),
          Component.text(
            ' must always be immutable. Because signals perform automatic de-duplication using equality checks (==), '
            'in-place mutation of mutable objects (such as calling list.add() on a standard List) will not trigger signal recalculations or widget rebuilds.',
          ),
        ]),
        const DocsCallout(
          type: CalloutType.important,
          title: 'Never Mutate State In-Place',
          children: [
            p([
              Component.text(
                'Always emit a brand new instance or a copyWith copy. In-place mutations break reactive dependency tracking and violate the unidirectional data flow contract.',
              ),
            ]),
          ],
        ),
      ]),

      // 2. Sealed Class Unions
      section(id: 'sealed-class-unions', classes: 'docs-section', [
        h2([Component.text('Sealed Class Unions')]),
        p([
          Component.text(
            'Dart 3 sealed classes provide type-safe, exhaustive pattern matching across all possible UI states. '
            'This completely eliminates impossible state representations (for example, showing a loading spinner while simultaneously displaying an error alert).',
          ),
        ]),
        const DocsCodeBlock(
          filename: 'user_profile_state.dart',
          dart313Code: '''
sealed class ProfileState;

final class ProfileLoading extends ProfileState;

final class ProfileLoaded(final User user, final List<Post> posts) extends ProfileState;

final class ProfileError(final String message) extends ProfileState;

// In your UI component:
Widget buildProfile(BuildContext context, ProfileState state) {
  return switch (state) {
    ProfileLoading() => const CircularProgressIndicator(),
    ProfileLoaded(:final user, :final posts) => ProfileView(user: user, posts: posts),
    ProfileError(:final message) => ErrorBanner(message: message),
  };
}''',
          dart35Code: '''
sealed class ProfileState {
  const ProfileState();
}

final class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

final class ProfileLoaded extends ProfileState {
  const ProfileLoaded(this.user, this.posts);
  final User user;
  final List<Post> posts;
}

final class ProfileError extends ProfileState {
  const ProfileError(this.message);
  final String message;
}

// In your UI component:
Widget buildProfile(BuildContext context, ProfileState state) {
  return switch (state) {
    ProfileLoading() => const CircularProgressIndicator(),
    ProfileLoaded(:final user, :final posts) => ProfileView(user: user, posts: posts),
    ProfileError(:final message) => ErrorBanner(message: message),
  };
}''',
        ),
      ]),

      // 3. Dart Records for State
      section(id: 'dart-records', classes: 'docs-section', [
        h2([Component.text('Dart Records for State')]),
        p([
          Component.text(
            'For simple, multi-field states, Dart Records provide built-in value equality and structural typing without creating standalone classes:',
          ),
        ]),
        const DocsCodeBlock(
          filename: 'pagination_cubit.dart',
          dart313Code: '''
typedef PaginationState = ({int page, int pageSize, bool hasMore});

class PaginationCubit()
    extends CubitSignal<PaginationState>(
      initialState: (page: 1, pageSize: 20, hasMore: true),
    ) {
  void nextPage() {
    emit((
      page: stateValue.page + 1,
      pageSize: stateValue.pageSize,
      hasMore: stateValue.hasMore,
    ));
  }
}''',
          dart35Code: '''
typedef PaginationState = ({int page, int pageSize, bool hasMore});

class PaginationCubit extends CubitSignal<PaginationState> {
  PaginationCubit()
      : super(initialState: (page: 1, pageSize: 20, hasMore: true));

  void nextPage() {
    emit((
      page: stateValue.page + 1,
      pageSize: stateValue.pageSize,
      hasMore: stateValue.hasMore,
    ));
  }
}''',
        ),
      ]),

      // 4. Fast Immutable Collections
      section(id: 'immutable-collections', classes: 'docs-section', [
        h2([Component.text('Fast Immutable Collections (FIC)')]),
        p([
          Component.text(
            'Standard Dart List and Map instances compare by identity reference rather than contents. '
            'Using Fast Immutable Collections (package:fast_immutable_collections) guarantees true structural equality and O(1) mutations.',
          ),
        ]),
        const DocsCodeBlock(
          filename: 'todo_cubit.dart',
          dart313Code: '''
import 'package:fast_immutable_collections/fast_immutable_collections.dart';

class TodoCubit()
    extends CubitSignal<IList<String>>(initialState: const <String>[].lock) {
  void addTodo(String item) => emit(stateValue.add(item));
  void removeTodo(int index) => emit(stateValue.removeAt(index));
}''',
          dart35Code: '''
import 'package:fast_immutable_collections/fast_immutable_collections.dart';

class TodoCubit extends CubitSignal<IList<String>> {
  TodoCubit() : super(initialState: const <String>[].lock);

  void addTodo(String item) {
    emit(stateValue.add(item));
  }

  void removeTodo(int index) {
    emit(stateValue.removeAt(index));
  }
}''',
        ),
      ]),

      // 5. Equality & De-duplication
      section(id: 'equality-deduplication', classes: 'docs-section', [
        h2([Component.text('Equality & De-duplication')]),
        p([
          Component.text(
            'Whenever emit(newState) is called, BlocSignal compares the incoming state with the current state. '
            'If the states evaluate as equal (previous == next), the emission is dropped automatically. '
            'No Change is emitted, observers are not notified, and downstream widgets do not perform redundant rebuilds.',
          ),
        ]),
      ]),

      // 6. Custom SignalOptions Comparators
      section(id: 'custom-comparators', classes: 'docs-section', [
        h2([Component.text('Custom SignalOptions Comparators')]),
        p([
          Component.text(
            'You can customize equality evaluation per-container by passing a SignalOptions instance or an equals: comparator closure:',
          ),
        ]),
        const DocsCodeBlock(
          filename: 'custom_comparator_cubit.dart',
          dart313Code: '''
class CaseInsensitiveCubit()
    extends CubitSignal<String>(
      initialState: '',
      equals: (a, b) => a.toLowerCase() == b.toLowerCase(),
    ) {
  void updateText(String text) => emit(text);
}

// In this cubit:
// cubit.updateText('Flutter');
// cubit.updateText('flutter'); // Dropped as duplicate! No rebuild triggered.
''',
          dart35Code: '''
class CaseInsensitiveCubit extends CubitSignal<String> {
  CaseInsensitiveCubit()
      : super(
          initialState: '',
          equals: (a, b) => a.toLowerCase() == b.toLowerCase(),
        );

  void updateText(String text) => emit(text);
}

// In this cubit:
// cubit.updateText('Flutter');
// cubit.updateText('flutter'); // Dropped as duplicate! No rebuild triggered.
''',
        ),
      ]),
    ]);
  }
}
