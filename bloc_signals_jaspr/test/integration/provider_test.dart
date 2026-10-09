// Characterization tests for the Jaspr `BlocSignalProvider`: which container a
// descendant sees, how many times it rebuilds, and when a `context.select`
// subscription is released.
//
// This package's provider is a line-by-line twin of the Flutter one and takes
// the same fixes, but it rides on different framework hooks --
// `deactivateDependent` rather than `removeDependent`, the binding's
// post-frame queue rather than `WidgetsBinding` -- against a pre-1.0
// dependency. Without a suite here, a jaspr bump silently restores whatever
// these pin and the Flutter suite cannot fail for it.
//
// The load-bearing assertions are selector *call* counts, not rendered output.
// A subscription that outlived its component checks nothing before recomputing
// its selector, so the only way to see it is to count how often the selector
// runs.

import 'package:bloc_signals_jaspr/bloc_signals_jaspr.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_test/jaspr_test.dart';

/// The container under test.
class CounterCubit extends CubitSignal<int> {
  /// Creates a counter starting at [initial].
  CounterCubit([int initial = 0]) : super(initialState: initial);

  /// Advances the counter by one.
  void increment() => emit(stateValue + 1);
}

/// One entry per build of whichever child is mounted.
final List<String> builds = <String>[];

/// How many times [counterOf] has been called since the last [setUp].
int selectorCalls = 0;

/// Reads the counter out of a container.
///
/// A top-level function rather than a closure written at the call site: two
/// closures written at the same site do not compare equal, so a call-site
/// closure makes the selector path rebind on every build and hides whatever a
/// test is trying to isolate.
int counterOf(CounterCubit bloc) {
  selectorCalls++;
  return bloc.stateValue;
}

/// Depends on the container's state through the selector path.
class SelectingChild extends StatelessComponent {
  /// Creates a [SelectingChild].
  const SelectingChild({super.key});

  @override
  Component build(BuildContext context) {
    builds.add('select:${context.select<CounterCubit, int>(counterOf)}');
    return const Component.empty();
  }
}

/// Selects on some builds and not others, which is what a component whose
/// layout depends on a flag does.
class MaybeSelectingChild extends StatelessComponent {
  /// Creates a [MaybeSelectingChild] that reads the counter iff [selecting].
  const MaybeSelectingChild({required this.selecting, super.key});

  /// Whether this build calls `context.select` at all.
  final bool selecting;

  @override
  Component build(BuildContext context) {
    if (!selecting) {
      builds.add('plain');
      return const Component.empty();
    }
    builds.add('select:${context.select<CounterCubit, int>(counterOf)}');
    return const Component.empty();
  }
}

/// Depends on the provider, so it rebuilds when the container is replaced.
class WatchingChild extends StatelessComponent {
  /// Creates a [WatchingChild].
  const WatchingChild({super.key});

  @override
  Component build(BuildContext context) {
    builds.add('watch:${context.watch<CounterCubit>().stateValue}');
    return const Component.empty();
  }
}

/// A parent that can be made to rebuild its subtree on demand.
///
/// Needed because `pumpComponent` is not Flutter's `pumpWidget`: it attaches a
/// brand-new root element every call and abandons the previous tree without
/// deactivating it, so a second `pumpComponent` never models a component
/// leaving the tree. Driving the change from inside one mounted tree does.
class Host extends StatefulComponent {
  /// Creates a [Host] rendering [childBuilder] for the current generation.
  const Host(this.childBuilder, {super.key});

  /// Builds the subtree for a given generation.
  final Component Function(int generation) childBuilder;

  @override
  State<Host> createState() => HostState();
}

/// The state behind [Host]; [bump] is what a test calls to force one rebuild.
class HostState extends State<Host> {
  /// The most recently mounted host, so a test can drive it.
  static HostState? current;

  /// How many times [bump] has been called.
  int generation = 0;

  @override
  void initState() {
    super.initState();
    current = this;
  }

  /// Rebuilds the subtree with the next generation number.
  void bump() => setState(() => generation++);

  @override
  Component build(BuildContext context) => component.childBuilder(generation);
}

/// Reads the container without registering any dependency.
class ReadingChild extends StatelessComponent {
  /// Creates a [ReadingChild].
  const ReadingChild({super.key});

  @override
  Component build(BuildContext context) {
    builds.add('read:${context.read<CounterCubit>().stateValue}');
    return const Component.empty();
  }
}

void main() {
  setUp(() {
    builds.clear();
    selectorCalls = 0;
  });

  group('a selecting child', () {
    testComponents('reads the container through the selector path',
        (tester) async {
      final handed = CounterCubit();
      addTearDown(handed.close);

      tester.pumpComponent(
        BlocSignalProvider<CounterCubit>.value(
          value: handed,
          child: const SelectingChild(),
        ),
      );
      await tester.pump();

      expect(builds, ['select:0']);

      handed.increment();
      await tester.pump();
      expect(builds, ['select:0', 'select:1']);
    });

    // Pins F23 in the Jaspr twin. There is no `deactivateDependent` hook and no
    // other unmount path for selector state; the trim runs on
    // `scheduleMicrotask` with no mounted check at all, and `_selectFinalizer`
    // is best-effort.
    testComponents(
        '(Issue #298: F23) cancels its subscription cleanly when it leaves the '
        'tree', (tester) async {
      final handed = CounterCubit();
      addTearDown(handed.close);

      tester.pumpComponent(
        Host(
          (generation) => BlocSignalProvider<CounterCubit>.value(
            value: handed,
            child: generation == 0
                ? const SelectingChild()
                : const Component.empty(),
          ),
        ),
      );
      await tester.pump();
      expect(builds, ['select:0']);

      HostState.current!.bump();
      await tester.pump();

      expect(
        handed.increment,
        returnsNormally,
        reason: 'the emission should be clean and not throw',
      );
      await tester.pump();
      expect(builds, ['select:0']);
    });

    // Pins F25 in the Jaspr twin.
    testComponents(
        '(Issue #298: F25) releases its subscription when component stops '
        'selecting', (tester) async {
      final handed = CounterCubit();
      addTearDown(handed.close);

      tester.pumpComponent(
        Host(
          (generation) => BlocSignalProvider<CounterCubit>.value(
            value: handed,
            child: MaybeSelectingChild(selecting: generation == 0),
          ),
        ),
      );
      await tester.pump();
      expect(builds, ['select:0']);

      HostState.current!.bump();
      await tester.pump();
      final callsBefore = selectorCalls;

      handed.increment();
      await tester.pump();
      expect(selectorCalls, callsBefore);

      handed.increment();
      await tester.pump();
      expect(selectorCalls, callsBefore);
    });

    testComponents(
        '(Issue #327: R13) deterministically disposes selector subscription '
        'when root component is replaced via pumpComponent without relying on '
        'AssertionError', (tester) async {
      final handed = CounterCubit();
      addTearDown(handed.close);

      tester.pumpComponent(
        BlocSignalProvider<CounterCubit>.value(
          value: handed,
          child: const SelectingChild(),
        ),
      );
      await tester.pump();
      expect(builds, ['select:0']);

      // Replace the root tree directly without deactivating the previous root.
      tester.pumpComponent(const Component.empty());
      await tester.pump();

      final callsBefore = selectorCalls;
      handed.increment();
      await tester.pump();
      handed.increment();
      await tester.pump();

      expect(selectorCalls, callsBefore);
      expect(builds, ['select:0']);
    });

    testComponents(
        '(Issue #327: R13) deterministically disposes selector subscription '
        'when provider subtree unmounts', (tester) async {
      final handed = CounterCubit();
      addTearDown(handed.close);

      tester.pumpComponent(
        Host(
          (generation) => generation == 0
              ? BlocSignalProvider<CounterCubit>.value(
                  value: handed,
                  child: const SelectingChild(),
                )
              : const Component.empty(),
        ),
      );
      await tester.pump();
      expect(builds, ['select:0']);

      HostState.current!.bump();
      await tester.pump();
      final callsBefore = selectorCalls;

      handed.increment();
      await tester.pump();
      expect(selectorCalls, callsBefore);
      expect(builds, ['select:0']);
    });

    testComponents(
        '(Issue #327: R13) updates inherited element reference when ancestor '
        'provider element is replaced above GlobalKey child', (tester) async {
      final first = CounterCubit();
      final second = CounterCubit(10);
      addTearDown(first.close);
      addTearDown(second.close);

      const childKey = GlobalObjectKey('selecting_child_r13');

      tester.pumpComponent(
        Host(
          (generation) => generation == 0
              ? BlocSignalProvider<CounterCubit>.value(
                  key: const ValueKey('p1'),
                  value: first,
                  child: const SelectingChild(key: childKey),
                )
              : BlocSignalProvider<CounterCubit>.value(
                  key: const ValueKey('p2'),
                  value: second,
                  child: const SelectingChild(key: childKey),
                ),
        ),
      );
      await tester.pump();
      expect(builds, ['select:0']);

      HostState.current!.bump();
      await tester.pump();
      expect(builds, ['select:0', 'select:10']);

      second.increment();
      await tester.pump();
      expect(builds, ['select:0', 'select:10', 'select:11']);
    });

    testComponents(
        '(Issue #327: R13) preserves selector subscription when entire '
        'provider subtree is reparented via GlobalKey', (tester) async {
      final cubit = CounterCubit();
      addTearDown(cubit.close);

      const subtreeKey = GlobalObjectKey('provider_subtree_r13');
      final subtree = Component.element(
        tag: 'div',
        key: subtreeKey,
        children: [
          BlocSignalProvider<CounterCubit>.value(
            value: cubit,
            child: const SelectingChild(),
          ),
        ],
      );

      tester.pumpComponent(
        Host(
          (generation) => generation == 0
              ? Component.element(tag: 'div', children: [subtree])
              : Component.element(
                  tag: 'section',
                  children: [
                    Component.element(tag: 'div', children: [subtree]),
                  ],
                ),
        ),
      );
      await tester.pump();
      expect(builds, ['select:0']);
      expect(selectorCalls, 1);

      HostState.current!.bump();
      await tester.pump();
      expect(
        selectorCalls,
        1,
        reason: 'reparenting via GlobalKey must preserve the existing '
            'subscription without tearing down and re-evaluating the selector',
      );
      expect(builds, ['select:0', 'select:0']);

      cubit.increment();
      await tester.pump();
      expect(selectorCalls, 2);
      expect(builds, ['select:0', 'select:0', 'select:1']);
    });
  });

  group('a watching child', () {
    testComponents('rebuilds when the container instance is replaced',
        (tester) async {
      final first = CounterCubit();
      final second = CounterCubit(9);
      addTearDown(first.close);
      addTearDown(second.close);

      tester.pumpComponent(
        Host(
          (generation) => BlocSignalProvider<CounterCubit>.value(
            value: generation == 0 ? first : second,
            child: const WatchingChild(),
          ),
        ),
      );
      await tester.pump();
      expect(builds, ['watch:0']);

      HostState.current!.bump();
      await tester.pump();
      expect(builds, ['watch:0', 'watch:9']);
    });
  });

  group('a provider that creates its own container', () {
    testComponents('closes it when the provider leaves the tree',
        (tester) async {
      late CounterCubit created;

      tester.pumpComponent(
        Host(
          (generation) => generation == 0
              ? BlocSignalProvider<CounterCubit>(
                  create: (_) => created = CounterCubit(7),
                  lazy: false,
                  child: const ReadingChild(),
                )
              : const Component.empty(),
        ),
      );
      await tester.pump();
      expect(created.isClosed, isFalse);

      HostState.current!.bump();
      await tester.pump();

      expect(created.isClosed, isTrue);
    });

    testComponents('leaves a handed-in container open', (tester) async {
      final handed = CounterCubit();
      addTearDown(handed.close);

      tester.pumpComponent(
        Host(
          (generation) => generation == 0
              ? BlocSignalProvider<CounterCubit>.value(
                  value: handed,
                  child: const ReadingChild(),
                )
              : const Component.empty(),
        ),
      );
      await tester.pump();

      HostState.current!.bump();
      expect(handed.isClosed, isFalse);
    });

    testComponents(
      'lazily, does not rebuild a watching child when container did '
      'not change',
      (tester) async {
        tester.pumpComponent(
          Host(
            (_) => BlocSignalProvider<CounterCubit>(
              create: (_) => CounterCubit(),
              child: const WatchingChild(),
            ),
          ),
        );
        await tester.pump();
        expect(builds, ['watch:0']);

        HostState.current!.bump();
        await tester.pump();
        expect(builds, ['watch:0']);

        HostState.current!.bump();
        await tester.pump();
        expect(builds, ['watch:0']);
      },
    );

    testComponents(
        'lazily, does not rebuild a selecting child when container did '
        'not change', (tester) async {
      late CounterCubit cubit;
      tester.pumpComponent(
        Host(
          (_) => BlocSignalProvider<CounterCubit>(
            create: (_) => cubit = CounterCubit(),
            child: const SelectingChild(),
          ),
        ),
      );
      await tester.pump();
      expect(builds, ['select:0']);

      HostState.current!.bump();
      await tester.pump();
      expect(builds, ['select:0']);

      HostState.current!.bump();
      await tester.pump();
      expect(builds, ['select:0']);

      cubit.increment();
      await tester.pump();
      expect(builds, ['select:0', 'select:1']);
    });

    testComponents(
        '(Issue #298: F5) lazily, does not re-run a throwing factory on '
        'subsequent rebuilds', (tester) async {
      var factoryCalls = 0;
      tester.pumpComponent(
        Host(
          (_) => BlocSignalProvider<CounterCubit>(
            create: (_) {
              factoryCalls++;
              throw StateError('factory failed');
            },
            child: Builder(
              builder: (context) {
                expect(
                  () => context.watch<CounterCubit>(),
                  throwsA(isA<StateError>()),
                );
                return const Component.empty();
              },
            ),
          ),
        ),
      );
      await tester.pump();
      expect(factoryCalls, 1);

      HostState.current!.bump();
      await tester.pump();
      expect(factoryCalls, 1);
    });
  });
}
