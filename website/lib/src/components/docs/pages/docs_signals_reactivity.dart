import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../docs_callout.dart';
import '../docs_code_block.dart';
import '../docs_toc.dart';

/// Documentation page covering signals graph reactivity, stateValue vs state, computed derivations, and reactions.
class const DocsSignalsReactivityPage({super.key}) extends StatelessComponent {
  static const List<TocHeading> headings = [
    TocHeading(title: 'stateValue vs. state', anchor: 'statevalue-vs-state'),
    TocHeading(title: 'Signals Graph Architecture', anchor: 'signals-graph'),
    TocHeading(
      title: 'Deriving State with computed()',
      anchor: 'computed-derivations',
    ),
    TocHeading(
      title: 'Managing Side Effects with effect()',
      anchor: 'side-effects',
    ),
    TocHeading(
      title: '0ms Synchronous Frame Propagation',
      anchor: 'synchronous-propagation',
    ),
    TocHeading(
      title: 'Adapting Signals & Futures to BlocSignal',
      anchor: 'adapters',
    ),
  ];

  @override
  Component build(BuildContext context) {
    return article(classes: 'docs-article', [
      header(classes: 'docs-article-header', [
        div(classes: 'docs-badge', [Component.text('🧠 Core Concepts')]),
        h1([Component.text('Signals Graph Reactivity')]),
        p(classes: 'docs-lead', [
          Component.text(
            'Understand how BlocSignal leverages Rody Davis signals v7 primitives for fine-grained dependency tracking, automatic de-duplication, and 0ms synchronous updates.',
          ),
        ]),
      ]),

      // 1. stateValue vs. state
      section(id: 'statevalue-vs-state', classes: 'docs-section', [
        h2([Component.text('stateValue vs. state')]),
        p([
          Component.text(
            'Every BlocSignalBase exposes two core state getters with distinct purposes:',
          ),
        ]),
        ul(classes: 'docs-list', [
          li([
            strong([Component.text('stateValue (StateType): ')]),
            Component.text(
              'Reads the raw, current state synchronously. It does NOT register a signal dependency when read inside a computed or effect callback. '
              'Use this for imperative checks, conditionals, and inside event handlers.',
            ),
          ]),
          li([
            strong([Component.text('state (ReadonlySignal<StateType>): ')]),
            Component.text(
              'Exposes the underlying reactive signal. Calling state() or state.value inside a computed signal or Flutter SignalBuilder automatically '
              'subscribes to state updates and triggers fine-grained recalculations.',
            ),
          ]),
        ]),
      ]),

      // 2. Signals Graph Architecture
      section(id: 'signals-graph', classes: 'docs-section', [
        h2([Component.text('Signals Graph Architecture')]),
        p([
          Component.text(
            'Under the hood, BlocSignal state containers create a Signal<StateType> node in the global reactive graph. '
            'Whenever emit(newState) is called, the graph evaluates equality. If the state has changed, dependent nodes '
            '(computed signals, effect listeners, and active Flutter Element subscribers) are marked dirty and evaluated synchronously.',
          ),
        ]),
      ]),

      // 3. Deriving State with computed()
      section(id: 'computed-derivations', classes: 'docs-section', [
        h2([Component.text('Deriving State with computed()')]),
        p([
          Component.text(
            'You can derive combined state across multiple independent Cubits and Blocs without boilerplate orchestration blocs using computed():',
          ),
        ]),
        const DocsCodeBlock(
          filename: 'computed_cart_example.dart',
          dart313Code: '''
final cartCubit = CartCubit();
final userCubit = UserCubit();

// Derived computed signal:
final checkoutSummary = computed(() {
  final items = cartCubit.state.value;
  final user = userCubit.state.value;
  final subtotal = items.fold<double>(0, (sum, item) => sum + item.price);
  final discount = user.isVip ? 0.20 : 0.0;
  return subtotal * (1 - discount);
});

// Automatically re-evaluates ONLY when cart or user state changes!
''',
          dart35Code: '''
final cartCubit = CartCubit();
final userCubit = UserCubit();

// Derived computed signal:
final checkoutSummary = computed(() {
  final items = cartCubit.state.value;
  final user = userCubit.state.value;
  final subtotal = items.fold<double>(0, (sum, item) => sum + item.price);
  final discount = user.isVip ? 0.20 : 0.0;
  return subtotal * (1 - discount);
});

// Automatically re-evaluates ONLY when cart or user state changes!
''',
        ),
      ]),

      // 4. Managing Side Effects with effect()
      section(id: 'side-effects', classes: 'docs-section', [
        h2([Component.text('Managing Side Effects with effect()')]),
        p([
          Component.text(
            'Use effect() or createEffect() to execute side effects (logging, persistent storage writes, analytics triggers) '
            'in response to signal graph mutations. The callback runs immediately upon initialization and re-runs whenever tracked signals mutate.',
          ),
        ]),
        const DocsCodeBlock(
          filename: 'effect_logging_example.dart',
          dart313Code: '''
final disposeEffect = effect(() {
  final currentCount = counterBloc.state.value;
  print('Counter signal updated: \$currentCount');
});

// Call disposeEffect() to cancel the subscription when no longer needed.
''',
          dart35Code: '''
final disposeEffect = effect(() {
  final currentCount = counterBloc.state.value;
  print('Counter signal updated: \$currentCount');
});

// Call disposeEffect() to cancel the subscription when no longer needed.
''',
        ),
      ]),

      // 5. 0ms Synchronous Frame Propagation
      section(id: 'synchronous-propagation', classes: 'docs-section', [
        h2([Component.text('0ms Synchronous Frame Propagation')]),
        p([
          Component.text(
            'Traditional stream-based state management libraries queue state emissions onto asynchronous microtask queues. '
            'This introduces at least 1-2 microtask ticks before UI widgets receive the new state.',
          ),
        ]),
        p([
          Component.text(
            'BlocSignal executes state transitions synchronously. When emit(newState) is called, downstream computations '
            'and widget builders are notified in the exact same execution frame, eliminating frame flickers and race conditions in complex UI workflows.',
          ),
        ]),
        const DocsCallout(
          type: CalloutType.tip,
          title: 'Immediate Test Verifications',
          children: [
            p([
              Component.text(
                'Because state propagation is 0ms synchronous, unit tests do not require artificial pumpAndSettle() or async sleep delays to assert immediate state changes.',
              ),
            ]),
          ],
        ),
      ]),

      // 6. Adapting Signals, Futures & Streams to BlocSignal
      section(id: 'adapters', classes: 'docs-section', [
        h2([
          Component.text('Adapting Signals, Futures & Streams to BlocSignal'),
        ]),
        p([
          Component.text(
            'You can seamlessly convert any ReadonlySignal (including raw signals, computed values, stream signals, and lifted primitives), '
            'asynchronous Future, or Stream into a BlocSignalBase state container using the .toBlocSignal() and .toAsyncBlocSignal() extensions:',
          ),
        ]),
        const DocsCodeBlock(
          filename: 'adapters_example.dart',
          dart313Code: '''
// 1. Convert any ReadonlySignal (or lifted primitive) to a BlocSignalBase<T>
final countSignal = signal(0);
final countBloc = countSignal.toBlocSignal();
final priceBloc = 49.99.\$.toBlocSignal();

// 2. Convert a Future<T> to a raw BlocSignalBase<T> with required initialState
final userBloc = api.fetchUser(id).toBlocSignal(initialState: User.anonymous());

// 3. Convert a Future<T> or Stream<T> to a BlocSignalBase<AsyncState<T>>
final userProfileBloc = api.fetchUserProfile(userId).toAsyncBlocSignal();
final sensorBloc = sensorStream.toAsyncBlocSignal();

// UI consumes the synchronous state transitions via BlocSignalBuilder:
BlocSignalBuilder(
  bloc: userProfileBloc,
  builder: (context, state) => switch (state) {
    AsyncData(:final value) => ProfileView(user: value),
    AsyncLoading() => const CircularProgressIndicator(),
    AsyncError(:final error) => Text('Error: \$error'),
  },
);
''',
          dart35Code: '''
// 1. Convert any ReadonlySignal (or lifted primitive) to a BlocSignalBase<T>
final countSignal = signal(0);
final countBloc = countSignal.toBlocSignal();
final priceBloc = 49.99.\$.toBlocSignal();

// 2. Convert a Future<T> to a raw BlocSignalBase<T> with required initialState
final userBloc = api.fetchUser(id).toBlocSignal(initialState: User.anonymous());

// 3. Convert a Future<T> or Stream<T> to a BlocSignalBase<AsyncState<T>>
final userProfileBloc = api.fetchUserProfile(userId).toAsyncBlocSignal();
final sensorBloc = sensorStream.toAsyncBlocSignal();

// UI consumes the synchronous state transitions via BlocSignalBuilder:
BlocSignalBuilder(
  bloc: userProfileBloc,
  builder: (context, state) {
    if (state case AsyncData(:final value)) {
      return ProfileView(user: value);
    }
    if (state case AsyncError(:final error)) {
      return Text('Error: \$error');
    }
    return const CircularProgressIndicator();
  },
);
''',
        ),
      ]),
    ]);
  }
}
