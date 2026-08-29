import 'package:blocsignal_website/src/models/pub_api_registry.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../docs_callout.dart';
import '../docs_code_block.dart';
import '../docs_toc.dart';

/// Documentation page covering bidirectional Riverpod interop with bloc_signals_riverpod.
class const DocsPkgRiverpodPage({super.key}) extends StatelessComponent {
  static const List<TocHeading> headings = [
    TocHeading(title: 'Overview & Installation', anchor: 'overview-install'),
    TocHeading(title: 'Riverpod to BlocSignal', anchor: 'riverpod-to-bloc'),
    TocHeading(title: 'BlocSignal to Riverpod', anchor: 'bloc-to-riverpod'),
    TocHeading(
      title: 'Auto-Disposal & Lifecycle',
      anchor: 'lifecycle-disposal',
    ),
    TocHeading(
      title: 'Riverpod 2 & 3 Compatibility',
      anchor: 'version-compatibility',
    ),
  ];

  @override
  Component build(BuildContext context) {
    return article(classes: 'docs-article', [
      header(classes: 'docs-article-header', [
        div(classes: 'docs-badge', [Component.text('📦 Satellite Packages')]),
        h1([Component.text('bloc_signals_riverpod')]),
        p(classes: 'docs-lead', [
          Component.text(
            'Seamless, bidirectional interoperability bridges connecting Riverpod providers and BlocSignal reactive state containers.',
          ),
        ]),
      ]),

      // 1. Overview & Installation
      section(id: 'overview-install', classes: 'docs-section', [
        h2([Component.text('Overview & Installation')]),
        p([
          Component.text(
            'The bloc_signals_riverpod package allows codebases transitioning between Riverpod and BlocSignal '
            'to share state seamlessly. You can consume Riverpod providers inside BlocSignals, or expose BlocSignals '
            'as standard Riverpod providers with zero boilerplate.',
          ),
        ]),
        const DocsCodeBlock(
          title: 'terminal',
          language: 'bash',
          code: 'flutter pub add bloc_signals_riverpod bloc_signals flutter_riverpod',
        ),
      ]),

      // 2. Riverpod to BlocSignal
      section(id: 'riverpod-to-bloc', classes: 'docs-section', [
        h2([
          Component.text(
            'Riverpod to BlocSignal (.toBlocSignal & Typed Notifier Access)',
          ),
        ]),
        p([
          Component.text('Convert any Riverpod ProviderListenable into a '),
          apiLink(DocSymbol.blocSignalBase),
          Component.text(' state container using the '),
          apiLink(
            DocSymbol.providerListenableBlocSignalX,
            label: '.toBlocSignal(ref)',
          ),
          Component.text(
            ' extension. When adapting NotifierProvider, AsyncNotifierProvider, StateNotifierProvider, or StateProvider, ',
          ),
          Component.text('the returned '),
          apiLink(DocSymbol.riverpodNotifierBlocSignal),
          Component.text(
            ' provides direct typed access to the underlying Riverpod notifier via the ',
          ),
          code([Component.text('.notifier')]),
          Component.text(' property for seamless state mutations:'),
        ]),
        const DocsCodeBlock(
          title: 'lib/riverpod_bridge.dart',
          language: 'dart',
          code: '''
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:bloc_signals_riverpod/bloc_signals_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final counterProvider = NotifierProvider<CounterNotifier, int>(CounterNotifier.new);

class CounterNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void increment() => state++;
}

class CounterWidget extends ConsumerWidget {
  const CounterWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Adapt Riverpod provider to RiverpodNotifierBlocSignal<CounterNotifier, int>
    final counterBloc = counterProvider.toBlocSignal(ref);

    return Column(
      children: [
        // Read state reactively as a BlocSignal:
        BlocSignalBuilder<BlocSignalBase<int>, int>(
          bloc: counterBloc,
          builder: (context, count) => Text('Count: \$count'),
        ),
        // Mutate the Riverpod notifier directly via typed .notifier:
        ElevatedButton(
          onPressed: () => counterBloc.notifier.increment(),
          child: const Text('Increment'),
        ),
      ],
    );
  }
}''',
        ),
      ]),

      // 3. BlocSignal to Riverpod
      section(id: 'bloc-to-riverpod', classes: 'docs-section', [
        h2([Component.text('BlocSignal to Riverpod (.toProvider)')]),
        p([
          Component.text('Expose an existing '),
          apiLink(DocSymbol.cubitSignal),
          Component.text(' or '),
          apiLink(DocSymbol.blocSignal),
          Component.text(' as a Riverpod NotifierProvider using the '),
          apiLink(DocSymbol.blocSignalRiverpodX, label: '.toProvider()'),
          Component.text(' extension. The generated '),
          apiLink(DocSymbol.blocSignalNotifier),
          Component.text(
            ' exposes typed .cubit and .bloc getters on the notifier, allowing Riverpod widgets to trigger mutations with zero boilerplate:',
          ),
        ]),
        const DocsCodeBlock(
          title: 'lib/counter_provider.dart',
          language: 'dart',
          code: '''
import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_riverpod/bloc_signals_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);
  void increment() => emit(stateValue + 1);
}

// 1. Expose the CubitSignal as a Riverpod NotifierProvider
final cubit = CounterCubit();
final counterProvider = cubit.toProvider();

// 2. Consume and mutate inside Riverpod widgets
class CounterView extends ConsumerWidget {
  const CounterView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(counterProvider);

    return ElevatedButton(
      // Access typed .cubit or .bloc on the notifier for direct mutations:
      onPressed: () => ref.read(counterProvider.notifier).cubit.increment(),
      child: Text('Count: \$count'),
    );
  }
}''',
        ),
      ]),

      // 4. Auto-Disposal & Lifecycle
      section(id: 'lifecycle-disposal', classes: 'docs-section', [
        h2([Component.text('Auto-Disposal & Lifecycle Binding')]),
        p([
          Component.text(
            'When you call .toBlocSignal(ref) and pass a Ref or WidgetRef, bloc_signals_riverpod automatically registers '
            'ref.onDispose(bloc.close). This guarantees that when the surrounding Riverpod provider or consumer widget is destroyed, '
            'the adapted BlocSignal is disposed of cleanly without retaining memory.',
          ),
        ]),
        const DocsCallout(
          type: CalloutType.important,
          title: 'Preventing Listener Duplication',
          children: [
            p([
              Component.text(
                'Never subscribe to signals inside standard auto-invalidating Provider((ref) => ...) closures if ref.invalidateSelf() is called. '
                'Instead, use Riverpod 2/3 Notifiers where the container lifecycle is stable.',
              ),
            ]),
          ],
        ),
      ]),

      // 5. Riverpod 2 & 3 Compatibility
      section(id: 'version-compatibility', classes: 'docs-section', [
        h2([Component.text('Riverpod 2 & 3 Cross-Version Compatibility')]),
        p([
          Component.text(
            'The adapter leverages package:riverpod/src/internals.dart to maintain unified binary and source compatibility '
            'across both Riverpod 2.x and Riverpod 3.x installations. You can upgrade Riverpod versions without requiring adapter rewrites.',
          ),
        ]),
      ]),
    ]);
  }
}
