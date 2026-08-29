import 'package:blocsignal_website/src/models/pub_api_registry.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../docs_callout.dart';
import '../docs_code_block.dart';
import '../docs_toc.dart';

/// Documentation page covering bidirectional classic BLoC interop with bloc_signals_bloc.
class const DocsPkgBlocPage({super.key}) extends StatelessComponent {
  static const List<TocHeading> headings = [
    TocHeading(title: 'Overview & Installation', anchor: 'overview-install'),
    TocHeading(
      title: 'Classic Bloc to BlocSignal',
      anchor: 'classic-to-signals',
    ),
    TocHeading(
      title: 'Classic Cubit to CubitSignal',
      anchor: 'cubit-to-signals',
    ),
    TocHeading(
      title: 'BlocSignal to Classic Bloc',
      anchor: 'signals-to-classic',
    ),
    TocHeading(
      title: '3-Phase Strangler Fig Migration',
      anchor: 'strangler-fig',
    ),
    TocHeading(
      title: 'Lifecycle & Auto-Disposal',
      anchor: 'lifecycle-disposal',
    ),
  ];

  @override
  Component build(BuildContext context) {
    return article(classes: 'docs-article', [
      header(classes: 'docs-article-header', [
        div(classes: 'docs-badge', [Component.text('📦 Satellite Packages')]),
        h1([Component.text('bloc_signals_bloc')]),
        p(classes: 'docs-lead', [
          Component.text(
            'Seamless, bidirectional interoperability bridges connecting classic package:bloc / flutter_bloc with BlocSignal reactive state containers.',
          ),
        ]),
      ]),

      // 1. Overview & Installation
      section(id: 'overview-install', classes: 'docs-section', [
        h2([Component.text('Overview & Installation')]),
        p([
          Component.text(
            'The bloc_signals_bloc package enables applications transitioning between classic package:bloc (versions 8 and 9) and BlocSignal '
            'to share state bidirectionally. You can adapt existing Blocs and Cubits into synchronous BlocSignals with full mutation support, '
            'or adapt modern BlocSignals into classic Blocs to power legacy Flutter UI widgets.',
          ),
        ]),
        const DocsCodeBlock(
          title: 'terminal',
          language: 'bash',
          code: 'flutter pub add bloc_signals_bloc bloc_signals bloc',
        ),
      ]),

      // 2. Classic Bloc to BlocSignal
      section(id: 'classic-to-signals', classes: 'docs-section', [
        h2([
          Component.text(
            'Classic Bloc to BlocSignal (.toBlocSignal & Event Dispatching)',
          ),
        ]),
        p([
          Component.text('Wrap any classic '),
          code([Component.text('bloc.Bloc<Event, State>')]),
          Component.text(' using the '),
          apiLink(DocSymbol.classicBlocToBlocSignalX, label: '.toBlocSignal()'),
          Component.text(' extension. The returned '),
          apiLink(DocSymbol.classicBlocSignal),
          Component.text(
            ' provides synchronous state access, reactive signal subscriptions, and forwards events directly into the underlying classic Bloc:',
          ),
        ]),
        const DocsCodeBlock(
          title: 'lib/classic_bloc_bridge.dart',
          language: 'dart',
          code: '''
import 'package:bloc/bloc.dart' as bloc;
import 'package:bloc_signals_bloc/bloc_signals_bloc.dart';

sealed class CounterEvent {}
final class IncrementEvent extends CounterEvent {}

class CounterBloc extends bloc.Bloc<CounterEvent, int> {
  CounterBloc() : super(0) {
    on<IncrementEvent>((event, emit) => emit(state + 1));
  }
}

void main() {
  final classicBloc = CounterBloc();
  final blocSignal = classicBloc.toBlocSignal();

  // 1. Synchronous signal reads (0ms, no microtask delays)
  print(blocSignal.stateValue); // 0
  final stateSignal = blocSignal.state;

  // 2. Direct event dispatching forwards to classicBloc.add()
  blocSignal.add(IncrementEvent());
}
''',
        ),
      ]),

      // 3. Classic Cubit to CubitSignal
      section(id: 'cubit-to-signals', classes: 'docs-section', [
        h2([
          Component.text(
            'Classic Cubit to CubitSignal (Typed .cubit Mutation Access)',
          ),
        ]),
        p([
          Component.text('Wrap any classic '),
          code([Component.text('bloc.Cubit<State>')]),
          Component.text(' using the '),
          apiLink(
            DocSymbol.classicCubitToBlocSignalX,
            label: '.toBlocSignal()',
          ),
          Component.text(' extension. The returned '),
          apiLink(DocSymbol.classicCubitSignal),
          Component.text(
            ' provides synchronous state access, reactive signals, and typed access to the underlying Cubit instance via the ',
          ),
          code([Component.text('.cubit')]),
          Component.text(' property:'),
        ]),
        const DocsCodeBlock(
          title: 'lib/classic_cubit_bridge.dart',
          language: 'dart',
          code: '''
import 'package:bloc/bloc.dart' as bloc;
import 'package:bloc_signals_bloc/bloc_signals_bloc.dart';

class CounterCubit extends bloc.Cubit<int> {
  CounterCubit() : super(0);
  void increment() => emit(state + 1);
}

void main() {
  final classicCubit = CounterCubit();
  final cubitSignal = classicCubit.toBlocSignal();

  // 1. Synchronous reactive state
  print(cubitSignal.stateValue); // 0

  // 2. Direct typed mutation through the wrapped cubit
  cubitSignal.cubit.increment();
}
''',
        ),
      ]),

      // 4. BlocSignal to Classic Bloc
      section(id: 'signals-to-classic', classes: 'docs-section', [
        h2([
          Component.text(
            'BlocSignal to Classic Bloc (.toClassicBloc & flutter_bloc UI)',
          ),
        ]),
        p([
          Component.text(
            'When writing new state containers with modern, streamless ',
          ),
          apiLink(DocSymbol.blocSignal),
          Component.text(' or '),
          apiLink(DocSymbol.cubitSignal),
          Component.text(
            ', you can adapt them back into classic Blocs and Cubits using ',
          ),
          apiLink(
            DocSymbol.blocSignalToClassicBlocX,
            label: '.toClassicBloc()',
          ),
          Component.text(' or '),
          apiLink(
            DocSymbol.blocSignalToClassicCubitX,
            label: '.toClassicCubit()',
          ),
          Component.text(
            '. This allows existing Flutter UI widgets (for example ',
          ),
          code([Component.text('BlocBuilder')]),
          Component.text(', '),
          code([Component.text('BlocListener')]),
          Component.text(', and '),
          code([Component.text('BlocConsumer')]),
          Component.text(
            ') to consume modern BlocSignals without refactoring UI code first:',
          ),
        ]),
        const DocsCodeBlock(
          title: 'lib/signal_to_flutter_bloc.dart',
          language: 'dart',
          code: '''
import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_bloc/bloc_signals_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart' as fb;

sealed class CounterEvent {}
final class IncrementEvent extends CounterEvent {}

class ModernCounterBloc extends BlocSignal<CounterEvent, int> {
  ModernCounterBloc() : super(initialState: 0) {
    on<IncrementEvent>((event, emit) => emit(stateValue + 1));
  }
}

class LegacyBlocView extends StatelessWidget {
  const LegacyBlocView({super.key, required this.modernBloc});

  final ModernCounterBloc modernBloc;

  @override
  Widget build(BuildContext context) {
    // Adapt modern BlocSignal into a classic Bloc instance for flutter_bloc widgets:
    final classicAdapter = modernBloc.toClassicBloc();

    return fb.BlocBuilder<fb.Bloc<CounterEvent, int>, int>(
      bloc: classicAdapter,
      builder: (context, count) {
        return ElevatedButton(
          onPressed: () => classicAdapter.add(IncrementEvent()),
          child: Text('Count: \$count'),
        );
      },
    );
  }
}
''',
        ),
      ]),

      // 5. 3-Phase Strangler Fig Migration
      section(id: 'strangler-fig', classes: 'docs-section', [
        h2([Component.text('3-Phase Strangler Fig Migration')]),
        p([
          Component.text(
            'The Strangler Fig pattern allows teams with large codebases to migrate from classic flutter_bloc '
            'to BlocSignal incrementally without massive refactors or downtime:',
          ),
        ]),
        ol([
          li([
            strong([
              Component.text('Phase 1: Modernize UI to Synchronous Signals'),
            ]),
            p([
              Component.text(
                'Wrap existing classic Blocs with classicBloc.toBlocSignal(). Update UI widgets to BlocSignalBuilder '
                'and context.select to eliminate stream microtask latency and rebuild jank immediately.',
              ),
            ]),
          ]),
          li([
            strong([Component.text('Phase 2: Modernize State Containers')]),
            p([
              Component.text(
                'Rewrite classic Blocs into streamless BlocSignal or CubitSignal containers. Use .toClassicBloc() '
                'for any legacy BlocBuilder widgets that have not yet been migrated.',
              ),
            ]),
          ]),
          li([
            strong([Component.text('Phase 3: Drop the Bridge')]),
            p([
              Component.text(
                'Once both the UI and state containers are modernized, cleanly remove the bloc_signals_bloc adapter calls.',
              ),
            ]),
          ]),
        ]),
        const DocsCallout(
          type: CalloutType.tip,
          title: 'Zero Downtime Migrations',
          children: [
            p([
              Component.text(
                'Because both adapter tracks support full event dispatching and synchronous reads, '
                'each screen and state container can be migrated independently at whatever pace your team chooses.',
              ),
            ]),
          ],
        ),
      ]),

      // 6. Lifecycle & Auto-Disposal
      section(id: 'lifecycle-disposal', classes: 'docs-section', [
        h2([Component.text('Lifecycle & Auto-Disposal')]),
        p([
          Component.text('By default, adapting a classic Bloc with '),
          code([Component.text('toBlocSignal(autoClose: true)')]),
          Component.text(
            ' will automatically close the underlying classic Bloc when the adapted BlocSignal is closed. '
            'If you want the classic Bloc to remain open after the adapter is closed, pass ',
          ),
          code([Component.text('autoClose: false')]),
          Component.text('.'),
        ]),
        const DocsCodeBlock(
          title: 'lib/lifecycle_example.dart',
          language: 'dart',
          code: '''
final classicBloc = CounterBloc();

// Adapter will NOT close classicBloc on close()
final independentAdapter = classicBloc.toBlocSignal(autoClose: false);

await independentAdapter.close();
print(classicBloc.isClosed); // false

// Closing classicBloc closes the stream and drops future adapter emissions
await classicBloc.close();
''',
        ),
      ]),
    ]);
  }
}
