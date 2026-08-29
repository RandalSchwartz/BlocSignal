import 'package:blocsignal_website/src/models/pub_api_registry.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../docs_code_block.dart';
import '../docs_toc.dart';

/// Documentation page covering migration from flutter_riverpod.
class const DocsMigrationRiverpodPage({super.key}) extends StatelessComponent {
  static const List<TocHeading> headings = [
    TocHeading(title: 'Overview & Mental Model Shift', anchor: 'mental-model'),
    TocHeading(
      title: 'Concept Translation Matrix',
      anchor: 'translation-matrix',
    ),
    TocHeading(
      title: 'StateNotifier to CubitSignal',
      anchor: 'notifier-to-cubit',
    ),
    TocHeading(title: 'Widget Refactoring', anchor: 'widget-refactoring'),
    TocHeading(title: 'Derived State with computed()', anchor: 'derived-state'),
    TocHeading(
      title: 'Incremental Migration & Bidirectional State Bridging',
      anchor: 'bidirectional-bridging',
    ),
  ];

  @override
  Component build(BuildContext context) {
    return article(classes: 'docs-article', [
      header(classes: 'docs-article-header', [
        div(classes: 'docs-badge', [Component.text('🔄 Migration Guides')]),
        h1([Component.text('Migrating from Riverpod')]),
        p(classes: 'docs-lead', [
          Component.text(
            'Understand the architectural shift from global provider graphs to scoped reactive containers, with side-by-side widget and state translation patterns.',
          ),
        ]),
      ]),

      // 1. Overview & Mental Model Shift
      section(id: 'mental-model', classes: 'docs-section', [
        h2([Component.text('Overview & Mental Model Shift')]),
        p([
          Component.text(
            'Riverpod organizes state as a global declarative dependency graph accessed via WidgetRef. '
            'BlocSignal organizes state into scoped, self-contained containers provided through the Flutter Element tree '
            'using standard BuildContext lookups and 0ms synchronous Preact signals.',
          ),
        ]),
      ]),

      // 2. Concept Translation Matrix
      section(id: 'translation-matrix', classes: 'docs-section', [
        h2([Component.text('Concept Translation Matrix')]),
        table(classes: 'docs-table', [
          thead([
            tr([
              th([Component.text('Riverpod 2 / 3')]),
              th([Component.text('BlocSignal / Flutter')]),
            ]),
          ]),
          tbody([
            tr([
              td([Component.text('StateNotifier<State> / Notifier<State>')]),
              td([Component.text('CubitSignal<State>')]),
            ]),
            tr([
              td([Component.text('ProviderScope')]),
              td([
                Component.text('BlocSignalProvider / MultiBlocSignalProvider'),
              ]),
            ]),
            tr([
              td([Component.text('ref.watch(provider)')]),
              td([
                apiLink(
                  DocSymbol.contextSelect,
                  label: 'context.select<B, R>()',
                ),
                Component.text(' or '),
                apiLink(DocSymbol.blocSignalBuilder),
              ]),
            ]),
            tr([
              td([Component.text('ref.read(provider.notifier)')]),
              td([apiLink(DocSymbol.contextRead, label: 'context.read<B>()')]),
            ]),
            tr([
              td([Component.text('ref.listen(provider, ...)')]),
              td([apiLink(DocSymbol.blocSignalListener)]),
            ]),
            tr([
              td([Component.text('ProviderContainer / Overrides')]),
              td([
                Component.text(
                  'Constructor injection / BlocSignalProvider.value',
                ),
              ]),
            ]),
          ]),
        ]),
      ]),

      // 3. Provider Definition Refactoring
      section(id: 'notifier-to-cubit', classes: 'docs-section', [
        h2([Component.text('Provider Definition Refactoring')]),
        const DocsCodeBlock(
          title: 'Side-by-Side: StateNotifier / Notifier to CubitSignal',
          language: 'dart',
          code: '''
// --- BEFORE: Riverpod Notifier ---
@riverpod
class CounterNotifier extends _\$CounterNotifier {
  @override
  int build() => 0;

  void increment() => state++;
}

// --- AFTER: Pure Dart CubitSignal ---
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void increment() => emit(stateValue + 1);
}''',
        ),
      ]),

      // 4. Widget Refactoring
      section(id: 'widget-refactoring', classes: 'docs-section', [
        h2([Component.text('Widget Refactoring')]),
        p([
          Component.text(
            'Replace ConsumerWidget and ConsumerStatefulWidget with standard StatelessWidget and StatefulWidget, '
            'accessing state directly through BuildContext extensions:',
          ),
        ]),
        const DocsCodeBlock(
          title: 'Side-by-Side: Widget Consumption',
          language: 'dart',
          code: '''
// --- BEFORE: Riverpod ConsumerWidget ---
class CounterScreen extends ConsumerWidget {
  const CounterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(counterProvider);
    return Scaffold(
      body: Center(child: Text('\$count')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => ref.read(counterProvider.notifier).increment(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// --- AFTER: BlocSignal with context.select and context.read ---
class CounterScreen extends StatelessWidget {
  const CounterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final count = context.select<CounterCubit, int>((c) => c.stateValue);
    return Scaffold(
      body: Center(child: Text('\$count')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.read<CounterCubit>().increment(),
        child: const Icon(Icons.add),
      ),
    );
  }
}''',
        ),
      ]),

      // 5. Derived State with computed()
      section(id: 'derived-state', classes: 'docs-section', [
        h2([Component.text('Derived State with computed()')]),
        p([
          Component.text(
            'In Riverpod, derived state is declared using dependent functional providers. '
            'In BlocSignal, derived state is declared inside or alongside Cubits using computed() signals:',
          ),
        ]),
        const DocsCodeBlock(
          title: 'Side-by-Side: Derived Computations',
          language: 'dart',
          code: '''
// --- BEFORE: Riverpod Functional Provider ---
final isEvenProvider = Provider<bool>((ref) {
  final count = ref.watch(counterProvider);
  return count.isEven;
});

// --- AFTER: BlocSignal computed() Signal ---
extension CounterDerived on CounterCubit {
  ReadonlySignal<bool> get isEven => computed(() => state.value.isEven);
}''',
        ),
      ]),

      // 6. Incremental Migration & Bidirectional State Bridging
      section(id: 'bidirectional-bridging', classes: 'docs-section', [
        h2([
          Component.text(
            'Incremental Migration & Bidirectional State Bridging',
          ),
        ]),
        p([
          Component.text(
            'You do not need to rewrite entire applications overnight. Using ',
          ),
          code([Component.text('bloc_signals_riverpod')]),
          Component.text(
            ', Riverpod notifiers and BlocSignal containers can coexist and mutate each other across architectural boundaries:',
          ),
        ]),
        const DocsCodeBlock(
          title: 'lib/incremental_bridge.dart',
          language: 'dart',
          code: '''
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:bloc_signals_riverpod/bloc_signals_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 1. Consume and mutate Riverpod notifiers inside BlocSignal features
void consumeRiverpodInsideBloc(WidgetRef ref) {
  final counterBloc = counterProvider.toBlocSignal(ref);
  print(counterBloc.stateValue); // Read state synchronously
  counterBloc.notifier.increment(); // Mutate Riverpod notifier directly!
}

// 2. Expose and mutate BlocSignal containers inside Riverpod ConsumerWidgets
final countCubit = CounterCubit();
final counterNotifierProvider = countCubit.toProvider();

class HybridRiverpodWidget extends ConsumerWidget {
  const HybridRiverpodWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(counterNotifierProvider);

    return ElevatedButton(
      // Mutate the underlying Cubit/Bloc directly via typed .cubit alias:
      onPressed: () => ref.read(counterNotifierProvider.notifier).cubit.increment(),
      child: Text('Count: \$count'),
    );
  }
}''',
        ),
      ]),
    ]);
  }
}
