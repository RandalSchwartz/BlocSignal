import 'package:blocsignal_website/src/models/pub_api_registry.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../docs_callout.dart';
import '../docs_code_block.dart';
import '../docs_toc.dart';

/// Testing Guide: Declarative testing with bloc_signals_test.
class const DocsTestingGuidePage({super.key}) extends StatelessComponent {
  /// Table of contents headings for this article.
  static const List<TocHeading> headings = [
    TocHeading(title: '1. Declarative Testing Overview', anchor: 'overview'),
    TocHeading(title: '2. Testing CubitSignal', anchor: 'cubit-testing'),
    TocHeading(
      title: '3. State Seeding Best Practice',
      anchor: 'state-seeding',
    ),
    TocHeading(
      title: '4. Testing BlocSignal & Async',
      anchor: 'bloc-async-testing',
    ),
    TocHeading(title: '5. Error Handling & Routing', anchor: 'error-testing'),
    TocHeading(
      title: '6. Observer Scoping & Lifecycle',
      anchor: 'observer-verification',
    ),
  ];

  @override
  Component build(BuildContext context) {
    return article(classes: 'docs-article', [
      header(classes: 'docs-article-header', [
        div(classes: 'docs-badge', [
          Component.text('Unit Testing & Quality Gates'),
        ]),
        h1([Component.text('Testing Guide with bloc_signals_test')]),
        p(classes: 'docs-lead', [
          Component.text(
            'Write robust, declarative unit tests for CubitSignal and BlocSignal containers '
            'with deterministic state transitions, asynchronous event waiting, and observer assertions.',
          ),
        ]),
      ]),

      section(id: 'overview', classes: 'docs-section', [
        h2([Component.text('1. Declarative Testing Overview')]),
        p([
          Component.text(
            'Testing reactive state containers requires validating synchronous state emissions, '
            'asynchronous operations, error handling paths, and lifecycle cleanup. ',
          ),
          code([Component.text('package:bloc_signals_test')]),
          Component.text(' provides the '),
          apiLink(DocSymbol.blocSignalTest),
          Component.text(
            ' helper function to write expressive, deterministic tests with zero boilerplate.',
          ),
        ]),
        const DocsCodeBlock(
          title: 'pubspec.yaml Dev Dependencies',
          dart313Code: '''
dev_dependencies:
  test: ^1.25.0
  bloc_signals_test: ^1.0.0
''',
          dart35Code: '''
dev_dependencies:
  test: ^1.25.0
  bloc_signals_test: ^1.0.0
''',
        ),
      ]),

      section(id: 'cubit-testing', classes: 'docs-section', [
        h2([Component.text('2. Testing CubitSignal')]),
        p([
          Component.text(
            'Testing a CubitSignal involves building the cubit, triggering actions in ',
          ),
          code([Component.text('act:')]),
          Component.text(', and asserting expected state values in '),
          code([Component.text('expect:')]),
          Component.text(':'),
        ]),
        const DocsCodeBlock(
          title: 'Cubit Unit Test',
          dart313Code: '''
import 'package:bloc_signals_test/bloc_signals_test.dart';
import 'package:test/test.dart';

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
          dart35Code: '''
import 'package:bloc_signals_test/bloc_signals_test.dart';
import 'package:test/test.dart';

void main() {
  group('CounterCubit', () {
    blocSignalTest<CounterCubit, int>(
      'emits [1, 2] when increment is called twice',
      build: () => CounterCubit(),
      act: (CounterCubit cubit) {
        cubit.increment();
        cubit.increment();
      },
      expect: () => <int>[1, 2],
    );
  });
}
''',
        ),
      ]),

      section(id: 'state-seeding', classes: 'docs-section', [
        h2([Component.text('3. State Seeding Best Practice')]),
        p([
          Component.text(
            'In BlocSignal, state seeding is performed directly in the ',
          ),
          code([Component.text('build:')]),
          Component.text(
            ' closure via constructor parameters, rather than mutating private state after creation.',
          ),
        ]),
        const DocsCallout(
          type: CalloutType.tip,
          title: 'Explicit Constructor Seeding',
          children: [
            p([
              Component.text(
                'Passing initialState into the container constructor makes your architecture '
                'transparent, testable, and aligns directly with pure Dart functional principles.',
              ),
            ]),
          ],
        ),
        const DocsCodeBlock(
          title: 'Seeding Initial State in build',
          dart313Code: '''
blocSignalTest<CounterCubit, int>(
  'emits [11] when increment is called on seeded cubit',
  build: () => CounterCubit(initialState: 10),
  act: (cubit) => cubit.increment(),
  expect: () => [11],
);
''',
          dart35Code: '''
blocSignalTest<CounterCubit, int>(
  'emits [11] when increment is called on seeded cubit',
  build: () => CounterCubit(initialState: 10),
  act: (CounterCubit cubit) => cubit.increment(),
  expect: () => <int>[11],
);
''',
        ),
      ]),

      section(id: 'bloc-async-testing', classes: 'docs-section', [
        h2([Component.text('4. Testing BlocSignal & Async Handlers')]),
        p([
          Component.text(
            'When testing event-driven BlocSignal instances that execute asynchronous operations '
            '(such as network requests or database queries), use the ',
          ),
          code([Component.text('wait:')]),
          Component.text(' parameter to let async futures complete:'),
        ]),
        const DocsCodeBlock(
          title: 'Async Event Testing with wait',
          dart313Code: '''
blocSignalTest<UserBloc, UserState>(
  'emits [UserLoading, UserLoaded] on UserFetchRequested',
  build: () => UserBloc(apiClient: mockApiClient),
  act: (bloc) => bloc.add(const UserFetchRequested(id: 'user-42')),
  wait: const Duration(milliseconds: 50),
  expect: () => [
    const UserLoading(),
    const UserLoaded(User(id: 'user-42', name: 'Alice')),
  ],
  verify: (bloc) {
    expect(bloc.stateValue, isA<UserLoaded>());
  },
);
''',
          dart35Code: '''
blocSignalTest<UserBloc, UserState>(
  'emits [UserLoading, UserLoaded] on UserFetchRequested',
  build: () => UserBloc(apiClient: mockApiClient),
  act: (UserBloc bloc) => bloc.add(const UserFetchRequested(id: 'user-42')),
  wait: const Duration(milliseconds: 50),
  expect: () => <UserState>[
    const UserLoading(),
    const UserLoaded(User(id: 'user-42', name: 'Alice')),
  ],
  verify: (UserBloc bloc) {
    expect(bloc.stateValue, isA<UserLoaded>());
  },
);
''',
        ),
      ]),

      section(id: 'error-testing', classes: 'docs-section', [
        h2([Component.text('5. Error Handling & Routing')]),
        p([
          Component.text(
            'Operational exceptions caught inside event handlers are routed to onError and captured by ',
          ),
          code([Component.text('errors:')]),
          Component.text(':'),
        ]),
        const DocsCodeBlock(
          title: 'Asserting Error Captures',
          dart313Code: '''
blocSignalTest<UserBloc, UserState>(
  'captures NetworkException on server failure',
  build: () => UserBloc(apiClient: failingApiClient),
  act: (bloc) => bloc.add(const UserFetchRequested(id: 'invalid')),
  errors: () => [isA<NetworkException>()],
);
''',
          dart35Code: '''
blocSignalTest<UserBloc, UserState>(
  'captures NetworkException on server failure',
  build: () => UserBloc(apiClient: failingApiClient),
  act: (UserBloc bloc) => bloc.add(const UserFetchRequested(id: 'invalid')),
  errors: () => <dynamic>[isA<NetworkException>()],
);
''',
        ),
      ]),

      section(id: 'observer-verification', classes: 'docs-section', [
        h2([Component.text('6. Observer Scoping & Lifecycle Verification')]),
        p([
          code([Component.text('blocSignalTest')]),
          Component.text(
            ' automatically scopes a test observer during execution. It captures ',
          ),
          code([Component.text('onCreate')]),
          Component.text(', tracks all '),
          code([Component.text('onTransition')]),
          Component.text(' and '),
          code([Component.text('onChange')]),
          Component.text(' emissions, and ensures '),
          code([Component.text('onClose')]),
          Component.text(
            ' is invoked when the container is closed at the end of the test run.',
          ),
        ]),
      ]),
    ]);
  }
}
