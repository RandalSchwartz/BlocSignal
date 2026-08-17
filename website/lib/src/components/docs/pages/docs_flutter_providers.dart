import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../docs_callout.dart';
import '../docs_code_block.dart';
import '../docs_toc.dart';

/// Flutter Integration: Dependency Injection and Scoping guide.
class const DocsFlutterProvidersPage({super.key}) extends StatelessComponent {
  /// Table of contents headings for this article.
  static const List<TocHeading> headings = [
    TocHeading(title: '1. Dependency Injection', anchor: 'overview'),
    TocHeading(
      title: '2. Creating & Auto-Disposing',
      anchor: 'instance-creation',
    ),
    TocHeading(title: '3. Lazy vs. Eager Loading', anchor: 'lazy-evaluation'),
    TocHeading(
      title: '4. Scoping Existing Instances with .value',
      anchor: 'value-scoping',
    ),
    TocHeading(title: '5. MultiBlocSignalProvider', anchor: 'multi-provider'),
    TocHeading(title: '6. O(1) Lookup Architecture', anchor: 'o1-lookup'),
  ];

  @override
  Component build(BuildContext context) {
    return article(classes: 'docs-article', [
      header(classes: 'docs-article-header', [
        div(classes: 'docs-badge', [
          Component.text('Flutter Bindings & Architecture'),
        ]),
        h1([Component.text('BlocSignalProvider & Scoping')]),
        p(classes: 'docs-lead', [
          Component.text(
            'Explore dependency injection, automatic lifecycle disposal, '
            'lazy evaluation, and O(1) InheritedWidget subtree lookups in BlocSignal.',
          ),
        ]),
      ]),

      section(id: 'overview', classes: 'docs-section', [
        h2([Component.text('1. Dependency Injection in Flutter')]),
        p([
          Component.text(
            'In Flutter applications, managing where state containers are created, '
            'how they are accessed by descendant widgets, and when they are disposed '
            'is critical to preventing memory leaks. ',
          ),
          code([Component.text('BlocSignalProvider')]),
          Component.text(
            ' acts as a dependency injection bridge that binds a ',
          ),
          code([Component.text('BlocSignal')]),
          Component.text(' or '),
          code([Component.text('CubitSignal')]),
          Component.text(
            ' to the Flutter widget hierarchy through an InheritedWidget.',
          ),
        ]),
        const DocsCallout(
          type: CalloutType.tip,
          title: 'Frame-Synchronous Container Scoping',
          children: [
            p([
              Component.text(
                'Unlike classic Stream-based providers that require asynchronous queue draining, '
                'BlocSignalProvider synchronizes state updates synchronously on the exact same frame '
                'while preserving standard Flutter widget subtree caching.',
              ),
            ]),
          ],
        ),
      ]),

      section(id: 'instance-creation', classes: 'docs-section', [
        h2([Component.text('2. Creating & Auto-Disposing Instances')]),
        p([
          Component.text(
            'The standard constructor accepts a create callback. When the provider is '
            'mounted into the widget tree, the container is initialized. When the provider '
            'is unmounted and removed from the tree, ',
          ),
          code([Component.text('close()')]),
          Component.text(
            ' is called automatically to free signal effects and memory.',
          ),
        ]),
        const DocsCodeBlock(
          title: 'Basic Provider Setup',
          dart313Code: '''
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';

class CounterApp extends StatelessWidget {
  const CounterApp({super.key});

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
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';

class CounterApp extends StatelessWidget {
  const CounterApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: BlocSignalProvider<CounterCubit>(
        create: (BuildContext context) => CounterCubit(),
        child: const CounterView(),
      ),
    );
  }
}
''',
        ),
      ]),

      section(id: 'lazy-evaluation', classes: 'docs-section', [
        h2([Component.text('3. Lazy vs. Eager Loading')]),
        p([
          Component.text('By default, '),
          code([Component.text('BlocSignalProvider')]),
          Component.text(
            ' defers creation of the state container until the first time a descendant '
            'widget reads or watches it (',
          ),
          code([Component.text('lazy: true')]),
          Component.text(
            '). If your state container performs immediate startup tasks '
            '(such as opening a database connection or triggering an initial fetch event), '
            'set lazy to false:',
          ),
        ]),
        const DocsCodeBlock(
          title: 'Eager Initialization',
          dart313Code: '''
BlocSignalProvider<AuthBloc>(
  lazy: false,
  create: (context) => AuthBloc()..add(const AuthCheckRequested()),
  child: const AppNavigator(),
)
''',
          dart35Code: '''
BlocSignalProvider<AuthBloc>(
  lazy: false,
  create: (BuildContext context) {
    return AuthBloc()..add(const AuthCheckRequested());
  },
  child: const AppNavigator(),
)
''',
        ),
      ]),

      section(id: 'value-scoping', classes: 'docs-section', [
        h2([Component.text('4. Scoping Existing Instances with .value')]),
        p([
          Component.text(
            'When pushing a new route (such as a modal bottom sheet, detail page, or dialog), '
            'the new screen lives on a separate Navigator branch that cannot reach ancestor '
            'providers directly. Use ',
          ),
          code([Component.text('BlocSignalProvider.value')]),
          Component.text(
            ' to provide the existing instance without transferring disposal ownership.',
          ),
        ]),
        const DocsCallout(
          type: CalloutType.important,
          title: 'No Auto-Disposal on .value',
          children: [
            p([
              Component.text(
                'BlocSignalProvider.value will NOT invoke close() when unmounted. '
                'The original creator provider retains complete lifecycle ownership.',
              ),
            ]),
          ],
        ),
        const DocsCodeBlock(
          title: 'Route Scoping with .value',
          dart313Code: '''
void openDetails(BuildContext context) {
  final counterCubit = context.read<CounterCubit>();

  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (routeContext) => BlocSignalProvider<CounterCubit>.value(
        value: counterCubit,
        child: const CounterDetailScreen(),
      ),
    ),
  );
}
''',
          dart35Code: '''
void openDetails(BuildContext context) {
  final CounterCubit counterCubit = context.read<CounterCubit>();

  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (BuildContext routeContext) {
        return BlocSignalProvider<CounterCubit>.value(
          value: counterCubit,
          child: const CounterDetailScreen(),
        );
      },
    ),
  );
}
''',
        ),
      ]),

      section(id: 'multi-provider', classes: 'docs-section', [
        h2([Component.text('5. Composing Trees with MultiBlocSignalProvider')]),
        p([
          Component.text(
            'Nesting several individual providers causes excessive horizontal code indentation '
            '(the pyramid of doom). ',
          ),
          code([Component.text('MultiBlocSignalProvider')]),
          Component.text(
            ' flattens multiple providers into a single clean list.',
          ),
        ]),
        const DocsCodeBlock(
          title: 'MultiBlocSignalProvider Composition',
          dart313Code: '''
MultiBlocSignalProvider(
  providers: [
    BlocSignalProvider<AuthBloc>(
      create: (context) => AuthBloc(),
    ),
    BlocSignalProvider<ThemeCubit>(
      create: (context) => ThemeCubit(),
    ),
    BlocSignalProvider<SettingsBloc>(
      create: (context) => SettingsBloc(),
    ),
  ],
  child: const MainDashboard(),
)
''',
          dart35Code: '''
MultiBlocSignalProvider(
  providers: [
    BlocSignalProvider<AuthBloc>(
      create: (BuildContext context) => AuthBloc(),
    ),
    BlocSignalProvider<ThemeCubit>(
      create: (BuildContext context) => ThemeCubit(),
    ),
    BlocSignalProvider<SettingsBloc>(
      create: (BuildContext context) => SettingsBloc(),
    ),
  ],
  child: const MainDashboard(),
)
''',
        ),
      ]),

      section(id: 'o1-lookup', classes: 'docs-section', [
        h2([Component.text('6. O(1) InheritedWidget Lookup Architecture')]),
        p([
          Component.text(
            'Classic provider patterns often use tree-walking algorithms that incur an O(N) penalty '
            'proportional to widget tree depth. In BlocSignal, non-listening reads execute in ',
          ),
          strong([Component.text('O(1) constant time')]),
          Component.text(' by using Flutter’s element table lookup:'),
        ]),
        const DocsCodeBlock(
          title: 'O(1) Element Lookup Internals',
          dart313Code: '''
// BlocSignal Flutter Internal Resolver
static T of<T extends BlocSignalBase<Object?>>(
  BuildContext context, {
  bool listen = false,
}) {
  if (listen) {
    final provider = context.dependOnInheritedWidgetOfExactType<_InheritedBlocSignal<T>>();
    return provider!.bloc;
  }

  // O(1) direct element lookup without tree walk
  final element = context.getElementForInheritedWidgetOfExactType<_InheritedBlocSignal<T>>();
  final provider = element?.widget as _InheritedBlocSignal<T>?;
  return provider!.bloc;
}
''',
          dart35Code: '''
static T of<T extends BlocSignalBase<Object?>>(
  BuildContext context, {
  bool listen = false,
}) {
  if (listen) {
    final _InheritedBlocSignal<T>? provider = 
        context.dependOnInheritedWidgetOfExactType<_InheritedBlocSignal<T>>();
    return provider!.bloc;
  }

  final InheritedElement? element = 
      context.getElementForInheritedWidgetOfExactType<_InheritedBlocSignal<T>>();
  final _InheritedBlocSignal<T>? provider = element?.widget as _InheritedBlocSignal<T>?;
  return provider!.bloc;
}
''',
        ),
      ]),
    ]);
  }
}
