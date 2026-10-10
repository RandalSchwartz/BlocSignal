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
    TocHeading(
      title: '7. Mocking & Faking (Widget & Golden Tests)',
      anchor: 'widget-golden-mocking',
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

      section(id: 'widget-golden-mocking', classes: 'docs-section', [
        h2([Component.text('7. Mocking & Faking (Widget & Golden Tests)')]),
        p([
          Component.text(
            'When migrating from classic BLoC to BlocSignal, a common stumbling block in widget and golden tests is attempting to stub ',
          ),
          code([
            Component.text(
              'when(() => myCubit.state).thenReturn(MyLoadedState())',
            ),
          ]),
          Component.text(' with '),
          code([Component.text('mocktail')]),
          Component.text('. This produces a compiler error: '),
          code([
            Component.text(
              "The argument type 'MyLoadedState' can't be assigned to the parameter type 'ReadonlySignal'",
            ),
          ]),
          Component.text('.'),
        ]),
        p([
          Component.text('In BlocSignal, '),
          code([Component.text('cubit.state')]),
          Component.text(' is a reactive '),
          code([Component.text('ReadonlySignal<S>')]),
          Component.text(' that UI widgets ('),
          code([Component.text('BlocSignalBuilder')]),
          Component.text(', '),
          code([Component.text('BlocSignalListener')]),
          Component.text(', '),
          code([Component.text('BlocSignalSelector')]),
          Component.text(', and '),
          code([Component.text('context.select')]),
          Component.text(
            ') subscribe to inside reactive effects and computed signals, whereas ',
          ),
          code([Component.text('cubit.value')]),
          Component.text(' (and its alias '),
          code([Component.text('cubit.stateValue')]),
          Component.text(') returns the raw '),
          code([Component.text('S')]),
          Component.text(' snapshot.'),
        ]),
        const DocsCallout(
          type: CalloutType.tip,
          title: 'Prefer Lightweight Fakes or Constructor Seeding Over Mocks',
          children: [
            p([
              Component.text(
                'Because CubitSignal and BlocSignal are streamless and propagate state synchronously in the exact same frame, you rarely need mocktail in widget tests. For static golden tests, pass a real container seeded via initialState: into BlocSignalProvider.value. For interactive widget tests, create a 3-line Fake class extending CubitSignal<S> (or BlocSignal<E, S>) and implementing your container interface with a helper method: void emitState(S newState) => emit(newState);.',
              ),
            ]),
          ],
        ),
        const DocsCodeBlock(
          title: 'Idiomatic Fake Cubit for Widget & Golden Tests',
          dart313Code: '''
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// 1. Define a lightweight Fake extending CubitSignal (or BlocSignal<UserEvent, UserState>)
class FakeUserCubit({super.initialState = const UserInitial()})
    extends CubitSignal<UserState>
    implements UserCubit {
  void emitState(UserState newState) => emit(newState);

  @override
  Future<void> refresh() async {}
}

void main() {
  testWidgets('renders UserLoaded state and reacts to synchronous updates', (tester) async {
    final fakeCubit = FakeUserCubit(initialState: const UserLoading());
    addTearDown(fakeCubit.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocSignalProvider<UserCubit>.value(
          value: fakeCubit,
          child: const UserProfileView(),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // 2. Drive state transitions synchronously and pump the next frame
    fakeCubit.emitState(const UserLoaded('Alice'));
    await tester.pump();

    expect(find.text('Alice'), findsOneWidget);
  });
}
''',
          dart35Code: '''
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// 1. Define a lightweight Fake extending CubitSignal (or BlocSignal<UserEvent, UserState>)
class FakeUserCubit extends CubitSignal<UserState> implements UserCubit {
  FakeUserCubit({UserState initialState = const UserInitial()})
      : super(initialState: initialState);

  void emitState(UserState newState) => emit(newState);

  @override
  Future<void> refresh() async {}
}

void main() {
  testWidgets('renders UserLoaded state and reacts to synchronous updates', (WidgetTester tester) async {
    final fakeCubit = FakeUserCubit(initialState: const UserLoading());
    addTearDown(fakeCubit.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocSignalProvider<UserCubit>.value(
          value: fakeCubit,
          child: const UserProfileView(),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // 2. Drive state transitions synchronously and pump the next frame
    fakeCubit.emitState(const UserLoaded('Alice'));
    await tester.pump();

    expect(find.text('Alice'), findsOneWidget);
  });
}
''',
        ),
        p([
          Component.text('For event-driven containers, '),
          code([
            Component.text(
              'FakeUserBloc extends BlocSignal<UserEvent, UserState> implements UserBloc',
            ),
          ]),
          Component.text(
            ' works identically—providing real reactive signal subscriptions, equality checks, and lifecycle semantics without mock boilerplate.',
          ),
        ]),
        p([
          Component.text(
            'If your test suite requires interaction verification with ',
          ),
          code([Component.text('mocktail')]),
          Component.text(' (for example, '),
          code([Component.text('verify(() => mockCubit.refresh()).called(1)')]),
          Component.text('), back the mock with a real '),
          code([Component.text('signal<S>()')]),
          Component.text(
            ' so reactive widgets and selectors can subscribe to ',
          ),
          code([Component.text('mockCubit.state')]),
          Component.text('. Register a fallback state value via '),
          code([Component.text('setUpAll(() => registerFallbackValue(...))')]),
          Component.text(' for '),
          code([Component.text('equals(any(), any())')]),
          Component.text(', and wire '),
          code([Component.text('mockCubit.close()')]),
          Component.text(' to '),
          code([Component.text('stateSignal.dispose()')]),
          Component.text(' via '),
          code([Component.text('addTearDown(mockCubit.close)')]),
          Component.text(':'),
        ]),
        const DocsCodeBlock(
          title: 'Stubbing with mocktail and a Backing Signal',
          dart313Code: '''
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockUserCubit extends Mock implements UserCubit {}

void main() {
  setUpAll(() => registerFallbackValue(const UserInitial()));

  testWidgets('stubs MockUserCubit with a backing signal', (tester) async {
    final mockCubit = MockUserCubit();
    final stateSignal = signal<UserState>(const UserInitial());
    addTearDown(mockCubit.close);

    // Wire the backing signal and container contract
    when(() => mockCubit.state).thenReturn(stateSignal);
    when(() => mockCubit.value).thenAnswer((_) => stateSignal.value);
    when(() => mockCubit.stateValue).thenAnswer((_) => stateSignal.value);
    when(() => mockCubit.equals(any(), any())).thenAnswer(
      (inv) => inv.positionalArguments[0] == inv.positionalArguments[1],
    );
    when(() => mockCubit.isClosed).thenReturn(false);
    when(() => mockCubit.close()).thenAnswer((_) async => stateSignal.dispose());
    when(() => mockCubit.refresh()).thenAnswer((_) async {});

    await tester.pumpWidget(
      MaterialApp(
        home: BlocSignalProvider<UserCubit>.value(
          value: mockCubit,
          child: const UserProfileView(),
        ),
      ),
    );

    // Mutate the backing signal to trigger reactive widget rebuilds
    stateSignal.value = const UserLoaded('Alice');
    await tester.pump();

    expect(find.text('Alice'), findsOneWidget);
  });
}
''',
          dart35Code: '''
import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockUserCubit extends Mock implements UserCubit {}

void main() {
  setUpAll(() => registerFallbackValue(const UserInitial()));

  testWidgets('stubs MockUserCubit with a backing signal', (WidgetTester tester) async {
    final mockCubit = MockUserCubit();
    final stateSignal = signal<UserState>(const UserInitial());
    addTearDown(mockCubit.close);

    // Wire the backing signal and container contract
    when(() => mockCubit.state).thenReturn(stateSignal);
    when(() => mockCubit.value).thenAnswer((_) => stateSignal.value);
    when(() => mockCubit.stateValue).thenAnswer((_) => stateSignal.value);
    when(() => mockCubit.equals(any(), any())).thenAnswer(
      (Invocation inv) => inv.positionalArguments[0] == inv.positionalArguments[1],
    );
    when(() => mockCubit.isClosed).thenReturn(false);
    when(() => mockCubit.close()).thenAnswer((_) async => stateSignal.dispose());
    when(() => mockCubit.refresh()).thenAnswer((_) async {});

    await tester.pumpWidget(
      MaterialApp(
        home: BlocSignalProvider<UserCubit>.value(
          value: mockCubit,
          child: const UserProfileView(),
        ),
      ),
    );

    // Mutate the backing signal to trigger reactive widget rebuilds
    stateSignal.value = const UserLoaded('Alice');
    await tester.pump();

    expect(find.text('Alice'), findsOneWidget);
  });
}
''',
        ),
      ]),
    ]);
  }
}
