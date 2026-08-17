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
        h2([Component.text('Riverpod to BlocSignal (.toBlocSignal)')]),
        p([
          Component.text(
            'Convert any Riverpod ProviderListenable into a BlocSignalBase state container using the .toBlocSignal(ref) extension. '
            'State updates from the Riverpod container propagate into the BlocSignal synchronously:',
          ),
        ]),
        const DocsCodeBlock(
          title: 'lib/riverpod_bridge.dart',
          language: 'dart',
          code: '''
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:bloc_signals_riverpod/bloc_signals_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authUserProvider = StateProvider<String?>((ref) => 'Randal');

class UserHeaderWidget extends ConsumerWidget {
  const UserHeaderWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Adapt the Riverpod provider to a BlocSignal instance bound to this widget's lifecycle
    final userBloc = authUserProvider.toBlocSignal(ref);

    return BlocSignalBuilder<BlocSignalBase<String?>, String?>(
      bloc: userBloc,
      builder: (context, user) => Text('Welcome, \${user ?? "Guest"}'),
    );
  }
}''',
        ),
      ]),

      // 3. BlocSignal to Riverpod
      section(id: 'bloc-to-riverpod', classes: 'docs-section', [
        h2([Component.text('BlocSignal to Riverpod (.toProvider)')]),
        p([
          Component.text(
            'Expose an existing CubitSignal or BlocSignal as a Riverpod provider using the .toProvider() extension:',
          ),
        ]),
        const DocsCodeBlock(
          title: 'lib/counter_provider.dart',
          language: 'dart',
          code: '''
import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_riverpod/bloc_signals_riverpod.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);
  void increment() => emit(stateValue + 1);
}

// Create a Riverpod provider backed by CounterCubit
final counterProvider = Provider<int>((ref) {
  final cubit = CounterCubit();
  ref.onDispose(cubit.close);
  return ref.watchBlocSignal(cubit);
});''',
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
