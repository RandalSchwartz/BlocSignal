import 'package:blocsignal_website/src/models/pub_api_registry.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../docs_callout.dart';
import '../docs_code_block.dart';
import '../docs_toc.dart';

class const DocsQuickstartPage({super.key}) extends StatelessComponent {
  static const List<TocHeading> headings = [
    TocHeading(
      title: 'Step 1: Create a CubitSignal',
      anchor: 'step-1-cubitsignal',
    ),
    TocHeading(
      title: 'Step 2: Create a BlocSignal',
      anchor: 'step-2-blocsignal',
    ),
    TocHeading(
      title: 'Step 3: Provide to the Widget Tree',
      anchor: 'step-3-provide',
    ),
    TocHeading(
      title: 'Step 4: Build Reactive UI',
      anchor: 'step-4-reactive-ui',
    ),
    TocHeading(
      title: 'Step 5: Test with blocSignalTest',
      anchor: 'step-5-unit-testing',
    ),
  ];

  @override
  Component build(BuildContext context) {
    return article(classes: 'docs-article', [
      header(classes: 'docs-article-header', [
        div(classes: 'docs-badge', [Component.text('🚀 Getting Started')]),
        h1([Component.text('Quickstart Guide (5-Minute Tour)')]),
        p(classes: 'docs-lead', [
          Component.text(
            'Learn how to define state containers, bind them to Flutter or Jaspr UI, and write declarative unit tests in under five minutes.',
          ),
        ]),
      ]),

      // Step 1: CubitSignal
      section(id: 'step-1-cubitsignal', classes: 'docs-section', [
        h2([Component.text('Step 1: Create a CubitSignal')]),
        p([
          Component.text('A '),
          apiLink(DocSymbol.cubitSignal),
          Component.text(
            ' is the simplest state container in BlocSignal. It exposes direct public methods that invoke emit(newState) synchronously.',
          ),
        ]),
        const DocsCallout(
          type: CalloutType.important,
          title: 'Syntax Note',
          children: [
            p([
              Component.text(
                'Always use the named initialState: parameter in your constructor super call, and use stateValue (or state.value) to read raw state values.',
              ),
            ]),
          ],
        ),
        const DocsCodeBlock(
          title: 'counter_cubit.dart',
          dart313Code: '''
import 'package:bloc_signals/bloc_signals.dart';

class CounterCubit() extends CubitSignal<int> {
  this : super(initialState: 0);

  void increment() => emit(stateValue + 1);
  void decrement() => emit(stateValue - 1);
}
''',
          dart35Code: '''
import 'package:bloc_signals/bloc_signals.dart';

class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void increment() => emit(stateValue + 1);
  void decrement() => emit(stateValue - 1);
}
''',
        ),
      ]),

      // Step 2: BlocSignal
      section(id: 'step-2-blocsignal', classes: 'docs-section', [
        h2([Component.text('Step 2: Create a BlocSignal')]),
        p([
          Component.text(
            'When your domain logic benefits from event traceability, concurrency transformers, or complex state machine transitions, use ',
          ),
          apiLink(DocSymbol.blocSignal),
          Component.text('.'),
        ]),
        const DocsCodeBlock(
          title: 'counter_bloc.dart',
          dart313Code: '''
import 'package:bloc_signals/bloc_signals.dart';

sealed class CounterEvent;
final class Increment extends CounterEvent;
final class Decrement extends CounterEvent;

class CounterBloc() extends BlocSignal<CounterEvent, int> {
  this : super(initialState: 0) {
    on<Increment>((event, emit) => emit(stateValue + 1));
    on<Decrement>((event, emit) => emit(stateValue - 1));
  }
}
''',
          dart35Code: '''
import 'package:bloc_signals/bloc_signals.dart';

sealed class CounterEvent {}
class Increment extends CounterEvent {}
class Decrement extends CounterEvent {}

class CounterBloc extends BlocSignal<CounterEvent, int> {
  CounterBloc() : super(initialState: 0) {
    on<Increment>((event, emit) => emit(stateValue + 1));
    on<Decrement>((event, emit) => emit(stateValue - 1));
  }
}
''',
        ),
      ]),

      // Step 3: Provide
      section(id: 'step-3-provide', classes: 'docs-section', [
        h2([Component.text('Step 3: Provide to the Widget Tree')]),
        p([
          Component.text(
            'Provide your state container to downstream widgets using ',
          ),
          apiLink(DocSymbol.blocSignalProvider),
          Component.text(
            '. It performs lazy instantiation and O(1) element lookups.',
          ),
        ]),
        const DocsCodeBlock(
          title: 'main.dart',
          dart313Code: '''
import 'package:flutter/material.dart';
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'counter_cubit.dart';
import 'counter_view.dart';

void main() => runApp(const MyApp());

class MyApp() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: BlocSignalProvider<CounterCubit>(
        create: (context) => CounterCubit(),
        child: const CounterView(),
      ),
    );
  }
}
''',
          dart35Code: '''
import 'package:flutter/material.dart';
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'counter_cubit.dart';
import 'counter_view.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: BlocSignalProvider<CounterCubit>(
        create: (context) => CounterCubit(),
        child: const CounterView(),
      ),
    );
  }
}
''',
        ),
      ]),

      // Step 4: Reactive UI
      section(id: 'step-4-reactive-ui', classes: 'docs-section', [
        h2([Component.text('Step 4: Build Reactive UI')]),
        p([
          Component.text('Use '),
          apiLink(DocSymbol.blocSignalBuilder),
          Component.text(
            ' to rebuild widgets in 0ms when state changes, and context.read in callbacks.',
          ),
        ]),
        const DocsCodeBlock(
          title: 'counter_view.dart',
          dart313Code: '''
import 'package:flutter/material.dart';
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'counter_cubit.dart';

class CounterView() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BlocSignal Counter')),
      body: Center(
        child: BlocSignalBuilder<CounterCubit, int>(
          builder: (context, count) => Text(
            '\$count',
            style: Theme.of(context).textTheme.displayLarge,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.read<CounterCubit>().increment(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
''',
          dart35Code: '''
import 'package:flutter/material.dart';
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'counter_cubit.dart';

class CounterView extends StatelessWidget {
  const CounterView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BlocSignal Counter')),
      body: Center(
        child: BlocSignalBuilder<CounterCubit, int>(
          builder: (context, count) => Text(
            '\$count',
            style: Theme.of(context).textTheme.displayLarge,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.read<CounterCubit>().increment(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
''',
        ),
      ]),

      // Step 5: Testing
      section(id: 'step-5-unit-testing', classes: 'docs-section', [
        h2([Component.text('Step 5: Test with blocSignalTest')]),
        p([
          Component.text('Write declarative unit tests with '),
          apiLink(DocSymbol.blocSignalTest),
          Component.text(' from package:bloc_signals_test:'),
        ]),
        const DocsCodeBlock(
          title: 'counter_cubit_test.dart',
          dart313Code: '''
import 'package:bloc_signals_test/bloc_signals_test.dart';
import 'package:test/test.dart';
import 'counter_cubit.dart';

void main() {
  group('CounterCubit', () {
    blocSignalTest<CounterCubit, int>(
      'emits [1, 2] when increment is called twice',
      build: () => CounterCubit(),
      act: (cubit) => cubit..increment()..increment(),
      expect: () => [1, 2],
    );
  });
}
''',
          dart35Code: '''
import 'package:bloc_signals_test/bloc_signals_test.dart';
import 'package:test/test.dart';
import 'counter_cubit.dart';

void main() {
  group('CounterCubit', () {
    blocSignalTest<CounterCubit, int>(
      'emits [1, 2] when increment is called twice',
      build: () => CounterCubit(),
      act: (cubit) {
        cubit.increment();
        cubit.increment();
      },
      expect: () => [1, 2],
    );
  });
}
''',
        ),
      ]),
    ]);
  }
}
