// Characterization tests for `BlocSignalProvider`: which container a
// descendant sees, how many times it rebuilds, and which containers the
// provider closes on the way out.
//
// Almost every assertion here is a **build count**, never rendered text. A
// widget that rebuilds three times renders exactly what a widget that rebuilt
// twice renders, so a rebuild storm and a correct rebuild are
// indistinguishable from the frame — counting is the only way to see the
// difference. The exceptions are deliberate and few: how many times a factory
// ran, whether a container was closed, how many containers were built, the
// number of selector invocations, and the text of the no-provider error.
//
// The child widgets below are `const` on purpose. A non-const child is rebuilt
// whenever its parent rebuilds, regardless of any inherited-widget
// notification, which would hide exactly the signal these tests are counting.
// With a `const` child, Flutter reuses the element, so a parent rebuild alone
// cannot rebuild it.
//
// Two different things can still rebuild such a child, and the tests turn on
// telling them apart: the provider's own `updateShouldNotify`, which is what
// `WatchingChild` responds to, and a selector subscription calling
// `markNeedsBuild()` on the element directly, which is what `SelectingChild`
// responds to. The selector path does not go through `updateShouldNotify` at
// all.
//
// Every assertion pins behavior that was observed against this tree, not
// behavior the code is supposed to have. Where the two disagree the
// disagreement is recorded in the roadmap's findings log, not fixed here. A red
// test in this file after a production change is the signal to re-read the
// change, not to relax the assertion.

import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The container under test. Nothing here depends on what it holds beyond its
/// being distinguishable by value.
class CounterCubit extends CubitSignal<int> {
  /// Creates a counter starting at [initial].
  CounterCubit([int initial = 0]) : super(initialState: initial);

  /// Advances the counter by one.
  void increment() => emit(stateValue + 1);
}

/// One entry per build of whichever child widget is mounted, holding what that
/// build observed.
///
/// A module-level list rather than a field, because the child widgets have to
/// be `const` and so can capture nothing.
final List<String> builds = <String>[];

/// Depends on the *provider* — rebuilds when the container instance is
/// replaced, not when its state emits.
class WatchingChild extends StatelessWidget {
  /// Creates a [WatchingChild].
  const WatchingChild({super.key});

  @override
  Widget build(BuildContext context) {
    builds.add('watch:${context.watch<CounterCubit>().stateValue}');
    return const SizedBox.shrink();
  }
}

/// How many times [counterOf] has been called since the last [setUp].
///
/// A build count cannot see a selector subscription that outlived its widget:
/// the subscription checks `element.mounted` before asking for a rebuild, so a
/// leaked subscription and a released one both produce zero builds. Counting
/// selector calls is what separates them.
int selectorCalls = 0;

/// Reads the counter out of a container. A top-level function rather than a
/// closure written at the call site, because two closures written at the same
/// site do not compare equal: with a fresh selector on every build, the
/// selector path rebinds every time and a test could never tell whether a
/// rebind happened *because* the container was replaced.
int counterOf(CounterCubit bloc) {
  selectorCalls++;
  return bloc.stateValue;
}

/// Depends on the container's *state* through the selector path.
class SelectingChild extends StatelessWidget {
  /// Creates a [SelectingChild].
  const SelectingChild({super.key});

  @override
  Widget build(BuildContext context) {
    builds.add('select:${context.select<CounterCubit, int>(counterOf)}');
    return const SizedBox.shrink();
  }
}

/// Selects on some builds and not others, which is what a widget whose layout
/// depends on a flag does.
class MaybeSelectingChild extends StatelessWidget {
  /// Creates a [MaybeSelectingChild] that reads the counter iff [selecting].
  const MaybeSelectingChild({required this.selecting, super.key});

  /// Whether this build calls `context.select` at all.
  final bool selecting;

  @override
  Widget build(BuildContext context) {
    if (!selecting) {
      builds.add('plain');
      return const SizedBox.shrink();
    }
    builds.add('select:${context.select<CounterCubit, int>(counterOf)}');
    return const SizedBox.shrink();
  }
}

/// Reads the container without registering any dependency at all.
class ReadingChild extends StatelessWidget {
  /// Creates a [ReadingChild].
  const ReadingChild({super.key});

  @override
  Widget build(BuildContext context) {
    builds.add('read:${context.read<CounterCubit>().stateValue}');
    return const SizedBox.shrink();
  }
}

/// A parent that can be made to rebuild its subtree on demand, handing the
/// builder a generation number so the subtree can change what it provides.
class Host extends StatefulWidget {
  /// Creates a [Host] rendering [childBuilder] for the current generation.
  const Host(this.childBuilder, {super.key});

  /// Builds the subtree for a given generation.
  final Widget Function(int generation) childBuilder;

  @override
  State<Host> createState() => HostState();
}

/// The state behind [Host]; [bump] is what a test calls to force one rebuild.
class HostState extends State<Host> {
  /// How many times [bump] has been called.
  int generation = 0;

  /// Rebuilds the subtree with the next generation number.
  void bump() => setState(() => generation++);

  @override
  Widget build(BuildContext context) => widget.childBuilder(generation);
}

void main() {
  setUp(() {
    builds.clear();
    selectorCalls = 0;
  });

  group('a provider that creates its own container', () {
    testWidgets(
      'lazily, does not rebuild a watching child when container did '
      'not change',
      (tester) async {
        final key = GlobalKey<HostState>();
        await tester.pumpWidget(
          Host(
            key: key,
            (_) => BlocSignalProvider<CounterCubit>(
              create: (_) => CounterCubit(),
              child: const WatchingChild(),
            ),
          ),
        );
        expect(builds, ['watch:0']);

        key.currentState!.bump();
        await tester.pump();
        expect(builds, ['watch:0']);

        key.currentState!.bump();
        await tester.pump();
        expect(builds, ['watch:0']);
      },
    );

    testWidgets(
        'lazily, does not rebuild a selecting child when container did '
        'not change', (tester) async {
      late CounterCubit cubit;
      final key = GlobalKey<HostState>();
      await tester.pumpWidget(
        Host(
          key: key,
          (_) => BlocSignalProvider<CounterCubit>(
            create: (_) => cubit = CounterCubit(),
            child: const SelectingChild(),
          ),
        ),
      );
      expect(builds, ['select:0']);

      key.currentState!.bump();
      await tester.pump();
      expect(builds, ['select:0']);

      key.currentState!.bump();
      await tester.pump();
      expect(builds, ['select:0']);

      cubit.increment();
      await tester.pump();
      expect(builds, ['select:0', 'select:1']);
    });

    testWidgets('lazily, does not rebuild a child that only reads',
        (tester) async {
      final key = GlobalKey<HostState>();
      await tester.pumpWidget(
        Host(
          key: key,
          (_) => BlocSignalProvider<CounterCubit>(
            create: (_) => CounterCubit(),
            child: const ReadingChild(),
          ),
        ),
      );
      expect(builds, ['read:0']);

      // The third kind of dependent, and the one the extra build does not
      // reach: reading registers no inherited dependency, so there is nothing
      // to notify. This is the boundary of "every dependent".
      key.currentState!.bump();
      await tester.pump();
      expect(builds, ['read:0']);
    });

    testWidgets('eagerly, rebuilds a watching child not at all',
        (tester) async {
      final key = GlobalKey<HostState>();
      await tester.pumpWidget(
        Host(
          key: key,
          (_) => BlocSignalProvider<CounterCubit>(
            create: (_) => CounterCubit(),
            lazy: false,
            child: const WatchingChild(),
          ),
        ),
      );
      expect(builds, ['watch:0']);

      // The same sequence as the lazy case above, one build shorter. The
      // difference between these two tests is the whole of the extra build.
      key.currentState!.bump();
      await tester.pump();
      key.currentState!.bump();
      await tester.pump();
      expect(builds, ['watch:0']);
    });

    testWidgets('lazily, does not call the factory when nobody reads it',
        (tester) async {
      var factoryCalls = 0;
      await tester.pumpWidget(
        BlocSignalProvider<CounterCubit>(
          create: (_) {
            factoryCalls++;
            return CounterCubit();
          },
        ),
      );
      expect(factoryCalls, 0);

      // Not even on the way out: disposal must not be what forces creation.
      await tester.pumpWidget(const SizedBox.shrink());
      expect(factoryCalls, 0);
    });

    // Pins F24. The lazy getter runs `_bloc = widget.create!(context)` and only
    // then sets `_isInitialized = true`, with nothing between them, so a throw
    // leaves the flag false and the next read runs the factory again.
    testWidgets(
        'lazily, does not re-run a throwing factory on subsequent rebuilds',
        (tester) async {
      var factoryCalls = 0;
      final key = GlobalKey<HostState>();

      await tester.pumpWidget(
        Host(
          key: key,
          (_) => BlocSignalProvider<CounterCubit>(
            create: (_) {
              factoryCalls++;
              throw StateError('factory failed');
            },
            child: Builder(
              builder: (context) {
                builds.add('watch:${context.watch<CounterCubit>().stateValue}');
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(tester.takeException(), isStateError);
      expect(factoryCalls, 1);
      expect(builds, isEmpty);

      key.currentState!.bump();
      await tester.pump();
      expect(tester.takeException(), isStateError);
      expect(factoryCalls, 1);

      key.currentState!.bump();
      await tester.pump();
      expect(tester.takeException(), isStateError);
      expect(factoryCalls, 1);
    });

    // Pins the second half of F24. `_bloc` is assigned only when `create`
    // *returns*, and `dispose()` is gated on `_bloc != null`, so a container
    // the factory built before throwing is unreachable and never closed.
    testWidgets('lazily, never closes a container a throwing factory allocated',
        (tester) async {
      final allocated = <CounterCubit>[];

      await tester.pumpWidget(
        Host(
          (_) => BlocSignalProvider<CounterCubit>(
            create: (_) {
              allocated.add(CounterCubit());
              throw StateError('failed after allocating');
            },
            child: Builder(
              builder: (context) {
                builds.add('watch:${context.watch<CounterCubit>().stateValue}');
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(tester.takeException(), isStateError);
      expect(allocated, hasLength(1));

      // Tearing the whole tree down is the last chance to close it.
      await tester.pumpWidget(const SizedBox.shrink());
      expect(allocated.single.isClosed, isFalse);

      await allocated.single.close();
    });

    testWidgets('closes it when the provider leaves the tree', (tester) async {
      late CounterCubit created;
      await tester.pumpWidget(
        BlocSignalProvider<CounterCubit>(
          create: (_) => created = CounterCubit(7),
          lazy: false,
        ),
      );
      expect(created.isClosed, isFalse);

      await tester.pumpWidget(const SizedBox.shrink());
      expect(created.isClosed, isTrue);
    });

    testWidgets('keeps the first container when the factory itself changes',
        (tester) async {
      final made = <CounterCubit>[];
      final key = GlobalKey<HostState>();
      await tester.pumpWidget(
        Host(
          key: key,
          (generation) => BlocSignalProvider<CounterCubit>(
            create: (_) {
              final cubit = CounterCubit(generation * 100);
              made.add(cubit);
              return cubit;
            },
            lazy: false,
            child: const SelectingChild(),
          ),
        ),
      );
      expect(made, hasLength(1));
      expect(builds, ['select:0']);

      // A new closure arrives on every parent rebuild, but the provider is
      // initialized once. The second factory is never called and the child is
      // never told anything changed.
      key.currentState!.bump();
      await tester.pump();
      expect(made, hasLength(1));
      expect(builds, ['select:0']);

      addTearDown(made.single.close);
    });
  });

  group('a provider handed an existing container', () {
    testWidgets('leaves it open when the provider leaves the tree',
        (tester) async {
      final handed = CounterCubit(5);
      addTearDown(handed.close);

      await tester.pumpWidget(
        BlocSignalProvider<CounterCubit>.value(value: handed),
      );
      await tester.pumpWidget(const SizedBox.shrink());

      // The container belongs to whoever built it; a provider that did not
      // create it must not close it out from under them.
      expect(handed.isClosed, isFalse);
    });

    testWidgets('rebuilds a watching child not at all when nothing changes',
        (tester) async {
      final handed = CounterCubit(9);
      addTearDown(handed.close);
      final key = GlobalKey<HostState>();

      await tester.pumpWidget(
        Host(
          key: key,
          (_) => BlocSignalProvider<CounterCubit>.value(
            value: handed,
            child: const WatchingChild(),
          ),
        ),
      );
      expect(builds, ['watch:9']);

      // The container is published on the first frame here, so there is no
      // null-to-instance transition and no extra build.
      key.currentState!.bump();
      await tester.pump();
      expect(builds, ['watch:9']);
    });

    testWidgets('rebuilds a watching child when the container is replaced',
        (tester) async {
      final first = CounterCubit(1);
      final second = CounterCubit(2);
      addTearDown(first.close);
      addTearDown(second.close);
      final key = GlobalKey<HostState>();

      await tester.pumpWidget(
        Host(
          key: key,
          (generation) => BlocSignalProvider<CounterCubit>.value(
            value: generation == 0 ? first : second,
            child: const WatchingChild(),
          ),
        ),
      );
      expect(builds, ['watch:1']);

      key.currentState!.bump();
      await tester.pump();
      expect(builds, ['watch:1', 'watch:2']);
    });
  });

  group('a selecting child when the container is replaced under it', () {
    testWidgets('rebuilds for the new container and stops following the old',
        (tester) async {
      final first = CounterCubit(10);
      final second = CounterCubit(100);
      addTearDown(first.close);
      addTearDown(second.close);
      final key = GlobalKey<HostState>();

      await tester.pumpWidget(
        Host(
          key: key,
          (generation) => BlocSignalProvider<CounterCubit>.value(
            value: generation == 0 ? first : second,
            child: const SelectingChild(),
          ),
        ),
      );
      expect(builds, ['select:10']);

      // Before the swap the first container drives the child.
      first.increment();
      await tester.pump();
      expect(builds, ['select:10', 'select:11']);

      key.currentState!.bump();
      await tester.pump();
      expect(builds, ['select:10', 'select:11', 'select:100']);

      second.increment();
      await tester.pump();
      expect(
        builds,
        ['select:10', 'select:11', 'select:100', 'select:101'],
      );

      // The old container is still open and still emitting. If its
      // subscription had survived the swap, this is where the extra build
      // would appear.
      first.increment();
      await tester.pump();
      expect(
        builds,
        ['select:10', 'select:11', 'select:100', 'select:101'],
      );
    });

    // Pins F23. The only deterministic cleanup is the post-frame callback, and
    // its disposal loop sits inside `if (element.mounted)` -- the guard skips
    // exactly when the element is gone. `_selectFinalizer` is the only other
    // path, and a `Finalizer` is best-effort with no guarantee it ever runs.
    testWidgets('releases its subscription after the provider leaves the tree',
        (tester) async {
      final handed = CounterCubit();
      addTearDown(handed.close);

      await tester.pumpWidget(
        BlocSignalProvider<CounterCubit>.value(
          value: handed,
          child: const SelectingChild(),
        ),
      );
      handed.increment();
      await tester.pump();
      expect(builds, ['select:0', 'select:1']);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      final callsBefore = selectorCalls;
      handed.increment();
      await tester.pump();
      expect(selectorCalls, callsBefore);
      expect(builds, ['select:0', 'select:1']);

      handed.increment();
      await tester.pump();
      expect(selectorCalls, callsBefore);
      expect(builds, ['select:0', 'select:1']);
    });
  });

  group('a selecting child that stops selecting', () {
    // Pins F25. The trim is scheduled only from inside `select` and only on the
    // first call of a build, so a build that calls it zero times leaves the
    // subscription in the list with nothing scheduled to inspect it.
    testWidgets('releases the subscription when child stops selecting',
        (tester) async {
      final handed = CounterCubit();
      addTearDown(handed.close);
      final key = GlobalKey<HostState>();

      await tester.pumpWidget(
        Host(
          key: key,
          (generation) => BlocSignalProvider<CounterCubit>.value(
            value: handed,
            child: MaybeSelectingChild(selecting: generation == 0),
          ),
        ),
      );
      expect(builds, ['select:0']);

      key.currentState!.bump();
      await tester.pump();
      await tester.pump();
      expect(builds, ['select:0', 'plain']);

      final buildsBefore = builds.length;
      final callsBefore = selectorCalls;

      handed.increment();
      await tester.pump();
      await tester.pump();

      expect(selectorCalls, callsBefore);
      expect(builds.length, buildsBefore);

      handed.increment();
      await tester.pump();
      await tester.pump();

      expect(selectorCalls, callsBefore);
      expect(builds.length, buildsBefore);
    });
  });

  group('a child that only reads the container', () {
    testWidgets('does not rebuild when the state emits', (tester) async {
      late CounterCubit created;
      await tester.pumpWidget(
        BlocSignalProvider<CounterCubit>(
          create: (_) => created = CounterCubit(),
          lazy: false,
          child: const ReadingChild(),
        ),
      );
      expect(builds, ['read:0']);

      created.increment();
      await tester.pump();
      expect(builds, ['read:0']);
    });

    testWidgets('does not rebuild when the container is replaced',
        (tester) async {
      final first = CounterCubit(1);
      final second = CounterCubit(2);
      addTearDown(first.close);
      addTearDown(second.close);
      final key = GlobalKey<HostState>();

      await tester.pumpWidget(
        Host(
          key: key,
          (generation) => BlocSignalProvider<CounterCubit>.value(
            value: generation == 0 ? first : second,
            child: const ReadingChild(),
          ),
        ),
      );
      expect(builds, ['read:1']);

      // Reading registers no dependency, so the child keeps showing the first
      // container's value until something else rebuilds it.
      key.currentState!.bump();
      await tester.pump();
      expect(builds, ['read:1']);
    });
  });

  group('a watching child with no provider above it', () {
    testWidgets('fails with an error naming the container type',
        (tester) async {
      await tester.pumpWidget(const WatchingChild());

      final error = tester.takeException() as FlutterError;
      expect(error.message, contains('CounterCubit'));
      expect(builds, isEmpty);
    });
  });
}
