import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../docs_callout.dart';
import '../docs_code_block.dart';
import '../docs_toc.dart';

/// Documentation page covering state atomicity and the role of batch() in BlocSignal.
class const DocsRecipeBatchingPage({super.key}) extends StatelessComponent {
  static const List<TocHeading> headings = [
    TocHeading(
      title: 'The Core Question: Do Blocs Need batch()?',
      anchor: 'the-core-question',
    ),
    TocHeading(
      title: 'Inherent Atomicity of emit()',
      anchor: 'inherent-atomicity',
    ),
    TocHeading(
      title: 'Anti-Pattern: Batching Synchronous Emits',
      anchor: 'anti-pattern-batching-emits',
    ),
    TocHeading(
      title: 'Valid Use Case 1: Cross-Bloc Coordination',
      anchor: 'cross-bloc-coordination',
    ),
    TocHeading(
      title: 'Valid Use Case 2: Internal Auxiliary Signals',
      anchor: 'auxiliary-signals',
    ),
    TocHeading(title: 'Summary & Decision Rubric', anchor: 'summary-rubric'),
  ];

  @override
  Component build(BuildContext context) {
    return article(classes: 'docs-article', [
      header(classes: 'docs-article-header', [
        div(classes: 'docs-badge', [
          Component.text('🛠️ Architecture Recipes'),
        ]),
        h1([Component.text('Batching & Atomic Transactions')]),
        p(classes: 'docs-lead', [
          Component.text(
            'Understand state update atomicity in BlocSignal, why single-bloc emissions never require batch(), and how to use batch() correctly for multi-bloc transaction coordination.',
          ),
        ]),
      ]),

      // 1. The Core Question
      section(id: 'the-core-question', classes: 'docs-section', [
        h2([Component.text('The Core Question: Do Blocs Need batch()?')]),
        p([
          Component.text(
            'Developers familiar with fine-grained reactive signals often ask: ',
          ),
          em([
            Component.text(
              '"Is there any place inside a BlocSignal or CubitSignal where we should use batch() to ensure actions taken by the bloc are atomic?"',
            ),
          ]),
        ]),
        p([
          Component.text('The short answer is: '),
          strong([
            Component.text(
              'No, inside an individual Bloc or Cubit, state updates are already strictly atomic by design.',
            ),
          ]),
          Component.text(
            ' Calling batch() inside an emit() call or wrapping multiple synchronous emissions inside a handler is redundant or an anti-pattern. '
            'However, batch() has high value when coordinating transactions across multiple independent state containers.',
          ),
        ]),
      ]),

      // 2. Inherent Atomicity of emit()
      section(id: 'inherent-atomicity', classes: 'docs-section', [
        h2([Component.text('Inherent Atomicity of emit()')]),
        p([
          Component.text(
            'In BlocSignal, every state container owns exactly one underlying reactive signal node: ',
          ),
          code([Component.text('Signal<StateType> _state')]),
          Component.text(
            '. State is modeled as a unified, immutable object rather than separate loose variables:',
          ),
        ]),
        const DocsCodeBlock(
          filename: 'user_profile_state.dart',
          language: 'dart',
          code: '''
class UserProfileState {
  const UserProfileState({
    required this.name,
    required this.email,
    required this.role,
  });

  final String name;
  final String email;
  final String role;

  UserProfileState copyWith({String? name, String? email, String? role}) {
    return UserProfileState(
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
    );
  }
}''',
        ),
        p([
          Component.text('When you update state using '),
          code([
            Component.text(
              'emit(stateValue.copyWith(name: "Jane", role: "Admin"))',
            ),
          ]),
          Component.text(
            ', the entire update executes as a single assignment to the underlying state signal. '
            'Because all fields transition together in that single assignment, there is zero risk of "torn reads" or intermediate partial states. '
            'Downstream observers, computed signals, and Flutter widgets observe the complete transition from the previous state to the next state synchronously.',
          ),
        ]),
      ]),

      // 3. Anti-Pattern: Batching Synchronous Emits
      section(id: 'anti-pattern-batching-emits', classes: 'docs-section', [
        h2([Component.text('Anti-Pattern: Batching Synchronous Emits')]),
        p([
          Component.text(
            'A common misconception is attempting to wrap sequential calls to emit() inside batch() within a single event handler:',
          ),
        ]),
        const DocsCodeBlock(
          filename: 'anti_pattern_batch.dart',
          language: 'dart',
          code: '''
// ❌ ANTI-PATTERN: Do not wrap multiple synchronous emits in batch()
on<ResetAndInitialize>((event, emit) {
  batch(() {
    emit(const ProfileLoading());
    emit(const ProfileReady(user: defaultUser));
  });
});''',
        ),
        const DocsCallout(
          type: CalloutType.warning,
          title: 'Why Batching Synchronous Emits Is Harmful',
          children: [
            p([
              Component.text(
                '1. Reactive Graph Swallowing: batch() defers signal graph propagation until the batch block finishes. '
                'As a result, reactive widgets (like BlocSignalBuilder) and computed derivations only ever observe ProfileReady, '
                'completely skipping ProfileLoading.',
              ),
            ]),
            p([
              Component.text(
                '2. Observer Mismatch: Lifecycle hooks (handleTransition, BlocSignalObserver.onTransition, and onChange) '
                'execute immediately and synchronously on each emit() invocation. Observers record two transitions, '
                'while the UI and reactive graph only see one.',
              ),
            ]),
          ],
        ),
        p([Component.text('Follow these standard heuristics:')]),
        ul(classes: 'docs-list', [
          li([
            strong([
              Component.text(
                'If the intermediate state should not be rendered: ',
              ),
            ]),
            Component.text(
              'Do not emit it. Directly emit the final state (for example ProfileReady).',
            ),
          ]),
          li([
            strong([
              Component.text(
                'If the intermediate state represents an asynchronous checkpoint: ',
              ),
            ]),
            Component.text(
              'Emit the loading state, await the async operation, and then emit the outcome state. '
              'Because these calls occur across an await boundary, synchronous batch() cannot span them anyway.',
            ),
          ]),
        ]),
      ]),

      // 4. Valid Use Case 1: Cross-Bloc Coordination
      section(id: 'cross-bloc-coordination', classes: 'docs-section', [
        h2([Component.text('Valid Use Case 1: Cross-Bloc Coordination')]),
        p([
          Component.text(
            'The primary scenario where batch() is essential is when a single business event or user interaction '
            'mutates ',
          ),
          strong([
            Component.text(
              'multiple independent Blocs or Cubits simultaneously',
            ),
          ]),
          Component.text(':'),
        ]),
        const DocsCodeBlock(
          filename: 'logout_action.dart',
          dart313Code: '''
import 'package:flutter/widgets.dart';
import 'package:signals_core/signals_core.dart';
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';

void onLogout(BuildContext context) {
  final authBloc = context.read<AuthBloc>();
  final cartBloc = context.read<CartBloc>();
  final preferencesCubit = context.read<PreferencesCubit>();

  // ✅ Group mutations across multiple containers into a single transaction:
  batch(() {
    authBloc.add(const LogoutRequested());
    cartBloc.add(const ClearCart());
    preferencesCubit.resetToDefaults();
  });
}''',
          dart35Code: '''
import 'package:flutter/widgets.dart';
import 'package:signals_core/signals_core.dart';
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';

void onLogout(BuildContext context) {
  final authBloc = context.read<AuthBloc>();
  final cartBloc = context.read<CartBloc>();
  final preferencesCubit = context.read<PreferencesCubit>();

  // ✅ Group mutations across multiple containers into a single transaction:
  batch(() {
    authBloc.add(const LogoutRequested());
    cartBloc.add(const ClearCart());
    preferencesCubit.resetToDefaults();
  });
}''',
        ),
        p([
          strong([Component.text('Why this matters: ')]),
          Component.text(
            'Suppose your application header or dashboard computes derived values depending on both authBloc.state and cartBloc.state. '
            'Without batch(), authBloc emits first, triggering dependent widgets and computed signals to re-evaluate while cartBloc '
            'still holds the previous user\'s cart data (a temporary torn read). Wrapping the dispatches in batch() ensures all three '
            'state containers update before downstream listeners re-evaluate, guaranteeing atomic cross-bloc updates.',
          ),
        ]),
      ]),

      // 5. Valid Use Case 2: Internal Auxiliary Signals
      section(id: 'auxiliary-signals', classes: 'docs-section', [
        h2([Component.text('Valid Use Case 2: Internal Auxiliary Signals')]),
        p([
          Component.text(
            'In advanced services or repositories adopting CubitSignalMixin, you may manage multiple auxiliary raw Signal instances '
            'that feed into an internal computed derivation or effect:',
          ),
        ]),
        const DocsCodeBlock(
          filename: 'search_repository.dart',
          dart313Code: '''
import 'package:bloc_signals/bloc_signals.dart';
import 'package:signals_core/signals_core.dart';

class SearchRepository with CubitSignalMixin<SearchState> {
  SearchRepository() {
    initCubitSignal(initialState: const SearchState.initial());

    // Internal effect monitoring auxiliary signals:
    createEffect(() {
      final q = _query.value;
      final f = _filter.value;
      emit(SearchState.active(query: q, filter: f));
    });
  }

  final _query = signal('');
  final _filter = signal<String?>(null);

  void updateQueryAndFilter({required String query, required String? filter}) {
    // ✅ Batch auxiliary signal updates before the effect runs:
    batch(() {
      _query.value = query;
      _filter.value = filter;
    });
  }
}''',
          dart35Code: '''
import 'package:bloc_signals/bloc_signals.dart';
import 'package:signals_core/signals_core.dart';

class SearchRepository with CubitSignalMixin<SearchState> {
  SearchRepository() {
    initCubitSignal(initialState: const SearchState.initial());

    // Internal effect monitoring auxiliary signals:
    createEffect(() {
      final q = _query.value;
      final f = _filter.value;
      emit(SearchState.active(query: q, filter: f));
    });
  }

  final _query = signal('');
  final _filter = signal<String?>(null);

  void updateQueryAndFilter({required String query, required String? filter}) {
    // ✅ Batch auxiliary signal updates before the effect runs:
    batch(() {
      _query.value = query;
      _filter.value = filter;
    });
  }
}''',
        ),
        p([
          Component.text(
            'Here, modifying both _query and _filter inside batch() prevents the createEffect callback from firing twice '
            'with a half-updated state.',
          ),
        ]),
      ]),

      // 6. Summary & Decision Rubric
      section(id: 'summary-rubric', classes: 'docs-section', [
        h2([Component.text('Summary & Decision Rubric')]),
        p([
          Component.text(
            'Use this decision rubric to determine when batch() is appropriate:',
          ),
        ]),
        div(classes: 'docs-table-wrapper', [
          table(classes: 'docs-table', [
            thead([
              tr([
                th([Component.text('Scenario')]),
                th([Component.text('Use batch()?')]),
                th([Component.text('Architectural Rationale')]),
              ]),
            ]),
            tbody([
              tr([
                td([
                  code([Component.text('emit(newState)')]),
                ]),
                td([
                  strong([Component.text('No')]),
                ]),
                td([
                  Component.text(
                    'Inherent atomicity. Single assignment to underlying state signal leaves zero window for torn reads.',
                  ),
                ]),
              ]),
              tr([
                td([
                  Component.text('Multiple synchronous emits in one handler'),
                ]),
                td([
                  strong([Component.text('No')]),
                ]),
                td([
                  Component.text(
                    'Anti-pattern. Drops intermediate states in the reactive UI graph while observer hooks still record multiple transitions.',
                  ),
                ]),
              ]),
              tr([
                td([Component.text('Mutating multiple distinct Blocs/Cubits')]),
                td([
                  strong([Component.text('Yes')]),
                ]),
                td([
                  Component.text(
                    'Prevents cross-container torn reads and eliminates redundant intermediate rebuilds in widgets observing both containers.',
                  ),
                ]),
              ]),
              tr([
                td([
                  Component.text(
                    'Updating multiple auxiliary internal signals',
                  ),
                ]),
                td([
                  strong([Component.text('Yes')]),
                ]),
                td([
                  Component.text(
                    'Groups raw signal writes so dependent computed derivations or createEffect callbacks fire exactly once.',
                  ),
                ]),
              ]),
            ]),
          ]),
        ]),
      ]),
    ]);
  }
}
