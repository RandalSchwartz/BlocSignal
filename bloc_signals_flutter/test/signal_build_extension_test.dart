import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signals_flutter/signals_flutter.dart';

class _CounterCubit extends CubitSignal<int> {
  _CounterCubit([int initial = 0]) : super(initialState: initial);

  void increment() => emit(stateValue + 1);

  void setValue(int value) => emit(value);
}

class _AlwaysEmitCubit extends CubitSignal<int> {
  _AlwaysEmitCubit([int initial = 0])
      : super(initialState: initial, equals: (_, __) => false);

  void emitValue(int value) => emit(value);
}

class _DeactivateMutator extends StatefulWidget {
  const _DeactivateMutator({
    required this.onDeactivate,
    required this.child,
  });

  final VoidCallback onDeactivate;
  final Widget child;

  @override
  State<_DeactivateMutator> createState() => _DeactivateMutatorState();
}

class _DeactivateMutatorState extends State<_DeactivateMutator> {
  @override
  void deactivate() {
    super.deactivate();
    widget.onDeactivate();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

sealed class _CounterEvent {}

final class _IncrementEvent extends _CounterEvent {}

class _CounterBloc extends BlocSignal<_CounterEvent, int> {
  _CounterBloc([int initial = 0]) : super(initialState: initial) {
    on<_IncrementEvent>((event, emit) => emit(stateValue + 1));
  }
}

class _BuildCountProbe extends StatelessWidget {
  const _BuildCountProbe({required this.onBuild});

  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    onBuild();
    return const SizedBox.shrink();
  }
}

class _SignalSwapHost extends StatefulWidget {
  const _SignalSwapHost({
    required this.initialSignal,
    required this.builder,
    super.key,
  });

  final ReadonlySignal<int> initialSignal;
  final Widget Function(ReadonlySignal<int> signal) builder;

  @override
  State<_SignalSwapHost> createState() => _SignalSwapHostState();
}

class _SignalSwapHostState extends State<_SignalSwapHost> {
  late ReadonlySignal<int> _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialSignal;
  }

  void swap(ReadonlySignal<int> next) {
    setState(() {
      _current = next;
    });
  }

  @override
  Widget build(BuildContext context) => widget.builder(_current);
}

void main() {
  group('Issue #393: Fluent .build widget builder extensions', () {
    test(
      '(Issue #393) SignalWidgetFunctor and BlocSignalWidgetFunctor are '
      'zero-allocation extension types',
      () {
        final counter = signal<int>(0);
        addTearDown(counter.dispose);

        final cubit = _CounterCubit();
        addTearDown(cubit.close);

        expect(identical(counter, counter.build), isTrue);
        expect(identical(cubit, cubit.build), isTrue);
      },
    );

    testWidgets(
      '(Issue #393) ReadonlySignal.build rebuilds on signal updates',
      (tester) async {
        final counter = signal<int>(0);
        addTearDown(counter.dispose);

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: counter.build((context, value) => Text('Value: $value')),
          ),
        );

        expect(find.text('Value: 0'), findsOneWidget);

        counter.value = 42;
        await tester.pump();

        expect(find.text('Value: 42'), findsOneWidget);
      },
    );

    testWidgets(
      '(Issue #393) Computed.build rebuilds when upstream signal changes',
      (tester) async {
        final base = signal<int>(2);
        addTearDown(base.dispose);
        final doubled = computed(() => base.value * 2);
        addTearDown(doubled.dispose);

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: doubled.build((context, value) => Text('Doubled: $value')),
          ),
        );

        expect(find.text('Doubled: 4'), findsOneWidget);

        base.value = 7;
        await tester.pump();

        expect(find.text('Doubled: 14'), findsOneWidget);
      },
    );

    testWidgets(
      '(Issue #393) CubitSignal.build and BlocSignal.build rebuild on state '
      'emissions',
      (tester) async {
        final cubit = _CounterCubit(10);
        addTearDown(cubit.close);
        final bloc = _CounterBloc(100);
        addTearDown(bloc.close);

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Column(
              children: [
                cubit.build((context, state) => Text('Cubit: $state')),
                bloc.build((context, state) => Text('Bloc: $state')),
              ],
            ),
          ),
        );

        expect(find.text('Cubit: 10'), findsOneWidget);
        expect(find.text('Bloc: 100'), findsOneWidget);

        cubit.increment();
        bloc.add(_IncrementEvent());
        await tester.pump();

        expect(find.text('Cubit: 11'), findsOneWidget);
        expect(find.text('Bloc: 101'), findsOneWidget);
      },
    );

    testWidgets(
      '(Issue #393) ReadonlySignal.build.child preserves static child across '
      'updates',
      (tester) async {
        final counter = signal<int>(0);
        addTearDown(counter.dispose);
        var childBuilds = 0;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: counter.build.child(
              _BuildCountProbe(onBuild: () => childBuilds++),
              (context, value, child) => Column(
                children: [
                  Text('Signal: $value'),
                  if (child != null) child,
                ],
              ),
            ),
          ),
        );

        expect(find.text('Signal: 0'), findsOneWidget);
        expect(childBuilds, 1);

        counter.value = 1;
        await tester.pump();
        counter.value = 2;
        await tester.pump();

        expect(find.text('Signal: 2'), findsOneWidget);
        expect(childBuilds, 1);
      },
    );

    testWidgets(
      '(Issue #393) BlocSignalBase.build.child preserves static child across '
      'state emissions',
      (tester) async {
        final cubit = _CounterCubit();
        addTearDown(cubit.close);
        var childBuilds = 0;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: cubit.build.child(
              _BuildCountProbe(onBuild: () => childBuilds++),
              (context, state, child) => Column(
                children: [
                  Text('Cubit: $state'),
                  if (child != null) child,
                ],
              ),
            ),
          ),
        );

        expect(find.text('Cubit: 0'), findsOneWidget);
        expect(childBuilds, 1);

        cubit.increment();
        await tester.pump();
        cubit.increment();
        await tester.pump();

        expect(find.text('Cubit: 2'), findsOneWidget);
        expect(childBuilds, 1);
      },
    );

    testWidgets(
      '(Issue #393) SignalWidgetFunctor respects buildWhen and equals',
      (tester) async {
        final counter = signal<int>(0);
        addTearDown(counter.dispose);
        var builds = 0;
        final buildWhenCalls = <(int, int)>[];

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: counter.build(
              (context, value) {
                builds++;
                return Text('Value: $value');
              },
              equals: (prev, curr) => (prev ~/ 2) == (curr ~/ 2),
              buildWhen: (prev, curr) {
                buildWhenCalls.add((prev, curr));
                return curr.isEven;
              },
            ),
          ),
        );

        expect(builds, 1);
        expect(buildWhenCalls, isEmpty);
        expect(find.text('Value: 0'), findsOneWidget);

        // 0 ~/ 2 == 1 ~/ 2 -> skipped by equals.
        counter.value = 1;
        await tester.pump();
        expect(builds, 1);
        expect(buildWhenCalls, isEmpty);
        expect(find.text('Value: 0'), findsOneWidget);

        // 2 ~/ 2 != 0 ~/ 2 and 2.isEven -> rebuilds.
        counter.value = 2;
        await tester.pump();
        expect(builds, 2);
        expect(buildWhenCalls, <(int, int)>[(0, 2)]);
        expect(find.text('Value: 2'), findsOneWidget);

        // 5 ~/ 2 != 2 ~/ 2, so equals is false and _previousValue updates to
        // 5, while 5.isEven is false so buildWhen suppresses the rebuild.
        counter.value = 5;
        await tester.pump();
        expect(builds, 2);
        expect(buildWhenCalls, <(int, int)>[(0, 2), (2, 5)]);
        expect(find.text('Value: 2'), findsOneWidget);

        // 6 ~/ 2 != 5 ~/ 2 and 6.isEven -> rebuilds with previous == 5.
        counter.value = 6;
        await tester.pump();
        expect(builds, 3);
        expect(buildWhenCalls, <(int, int)>[(0, 2), (2, 5), (5, 6)]);
        expect(find.text('Value: 6'), findsOneWidget);
      },
    );

    testWidgets(
      '(Issue #393) initial mount skips buildWhen even with non-reflexive '
      'equals',
      (tester) async {
        final counter = signal<int>(0);
        addTearDown(counter.dispose);
        var builds = 0;
        var equalsCalls = 0;
        final buildWhenCalls = <(int, int)>[];

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: counter.build(
              (context, value) {
                builds++;
                return Text('Value: $value');
              },
              equals: (_, __) {
                equalsCalls++;
                return false;
              },
              buildWhen: (prev, curr) {
                buildWhenCalls.add((prev, curr));
                return true;
              },
            ),
          ),
        );

        expect(builds, 1);
        expect(equalsCalls, 0);
        expect(buildWhenCalls, isEmpty);
        expect(find.text('Value: 0'), findsOneWidget);

        counter.value = 1;
        await tester.pump();
        expect(builds, 2);
        expect(equalsCalls, 1);
        expect(buildWhenCalls, <(int, int)>[(0, 1)]);
        expect(find.text('Value: 1'), findsOneWidget);
      },
    );

    testWidgets(
      '(Issue #393) ReadonlySignal.build.child enforces equals, buildWhen, '
      'and null child while preserving static child',
      (tester) async {
        final counter = signal<int>(0);
        addTearDown(counter.dispose);
        var childBuilds = 0;
        var builderBuilds = 0;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: counter.build.child(
              _BuildCountProbe(onBuild: () => childBuilds++),
              (context, value, child) {
                builderBuilds++;
                return Column(
                  children: [
                    Text('Value: $value'),
                    if (child != null) child,
                  ],
                );
              },
              equals: (prev, curr) => (prev ~/ 2) == (curr ~/ 2),
              buildWhen: (prev, curr) => curr.isEven,
            ),
          ),
        );

        expect(find.text('Value: 0'), findsOneWidget);
        expect(childBuilds, 1);
        expect(builderBuilds, 1);

        // Filtered by equals (0 ~/ 2 == 1 ~/ 2).
        counter.value = 1;
        await tester.pump();
        expect(find.text('Value: 0'), findsOneWidget);
        expect(childBuilds, 1);
        expect(builderBuilds, 1);

        // Filtered by buildWhen (3.isEven is false).
        counter.value = 3;
        await tester.pump();
        expect(find.text('Value: 0'), findsOneWidget);
        expect(childBuilds, 1);
        expect(builderBuilds, 1);

        // Unfiltered update rebuilds builder while preserving static child.
        counter.value = 4;
        await tester.pump();
        expect(find.text('Value: 4'), findsOneWidget);
        expect(childBuilds, 1);
        expect(builderBuilds, 2);

        // Verify null child case with equals and buildWhen.
        final nullChildSignal = signal<int>(0);
        addTearDown(nullChildSignal.dispose);
        var nullChildBuilds = 0;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: nullChildSignal.build.child(
              null,
              (context, value, child) {
                nullChildBuilds++;
                return Text('NullChild: $value (${child == null})');
              },
              equals: (prev, curr) => (prev ~/ 2) == (curr ~/ 2),
              buildWhen: (prev, curr) => curr.isEven,
            ),
          ),
        );

        expect(find.text('NullChild: 0 (true)'), findsOneWidget);
        expect(nullChildBuilds, 1);

        nullChildSignal.value = 1;
        await tester.pump();
        expect(find.text('NullChild: 0 (true)'), findsOneWidget);
        expect(nullChildBuilds, 1);

        nullChildSignal.value = 4;
        await tester.pump();
        expect(find.text('NullChild: 4 (true)'), findsOneWidget);
        expect(nullChildBuilds, 2);
      },
    );

    testWidgets(
      '(Issue #393) BlocSignalWidgetFunctor respects buildWhen',
      (tester) async {
        final cubit = _CounterCubit();
        addTearDown(cubit.close);
        var builds = 0;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: cubit.build(
              (context, state) {
                builds++;
                return Text('Even: $state');
              },
              buildWhen: (prev, curr) => curr.isEven,
            ),
          ),
        );

        expect(builds, 1);
        expect(find.text('Even: 0'), findsOneWidget);

        cubit.setValue(1);
        await tester.pump();
        expect(builds, 1);
        expect(find.text('Even: 0'), findsOneWidget);

        cubit.setValue(2);
        await tester.pump();
        expect(builds, 2);
        expect(find.text('Even: 2'), findsOneWidget);
      },
    );

    testWidgets(
      '(Issue #393) didUpdateWidget rebinds when signal changes and ignores '
      'identical signal updates',
      (tester) async {
        var firstWatched = 0;
        var firstUnwatched = 0;
        var secondWatched = 0;
        var secondUnwatched = 0;
        final first = signal<int>(
          1,
          options: SignalOptions<int>(
            watched: () => firstWatched++,
            unwatched: () => firstUnwatched++,
          ),
        );
        addTearDown(first.dispose);
        final second = signal<int>(
          100,
          options: SignalOptions<int>(
            watched: () => secondWatched++,
            unwatched: () => secondUnwatched++,
          ),
        );
        addTearDown(second.dispose);
        final hostKey = GlobalKey<_SignalSwapHostState>();
        var builds = 0;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: _SignalSwapHost(
              key: hostKey,
              initialSignal: first,
              builder: (sig) => sig.build(
                (context, value) {
                  builds++;
                  return Text('Value: $value');
                },
                buildWhen: (prev, curr) => curr != 3,
              ),
            ),
          ),
        );

        expect(find.text('Value: 1'), findsOneWidget);
        expect(builds, 1);
        expect(firstWatched, 1);
        expect(firstUnwatched, 0);
        expect(secondWatched, 0);
        expect(secondUnwatched, 0);

        // Emit a buildWhen-suppressed value (3) before same-signal rebuild.
        first.value = 3;
        await tester.pump();
        expect(find.text('Value: 1'), findsOneWidget);
        expect(builds, 1);

        // Re-pumping with the exact same signal instance does not re-subscribe
        // and preserves the buildWhen-suppressed rendered value.
        hostKey.currentState!.swap(first);
        await tester.pump();
        expect(find.text('Value: 1'), findsOneWidget);
        expect(builds, 2);
        expect(firstWatched, 1);
        expect(firstUnwatched, 0);

        first.value = 2;
        await tester.pump();
        expect(find.text('Value: 2'), findsOneWidget);
        expect(builds, 3);

        // Swapping to a new signal instance rebinds and detaches the old one.
        hostKey.currentState!.swap(second);
        await tester.pump();
        expect(find.text('Value: 100'), findsOneWidget);
        expect(builds, 4);
        expect(firstWatched, 1);
        expect(firstUnwatched, 1);
        expect(secondWatched, 1);
        expect(secondUnwatched, 0);

        // Mutating old signal no longer triggers rebuilds.
        first.value = 999;
        await tester.pump();
        expect(find.text('Value: 100'), findsOneWidget);
        expect(builds, 4);

        // Mutating new signal triggers rebuilds.
        second.value = 101;
        await tester.pump();
        expect(find.text('Value: 101'), findsOneWidget);
        expect(builds, 5);
      },
    );

    testWidgets(
      '(Issue #393) parent rebuild with identical signal applies updated '
      'equals, buildWhen, child, and .build/.build.child mode without '
      're-subscribing',
      (tester) async {
        var watched = 0;
        var unwatched = 0;
        final counter = signal<int>(
          0,
          options: SignalOptions<int>(
            watched: () => watched++,
            unwatched: () => unwatched++,
          ),
        );
        addTearDown(counter.dispose);

        bool Function(int, int)? activeEquals = (prev, curr) => prev == curr;
        bool Function(int, int)? activeBuildWhen = (prev, curr) => true;
        Widget? activeChild = const Text('Child A');
        var useChildBuilder = false;

        Widget buildHost() => Directionality(
              textDirection: TextDirection.ltr,
              child: useChildBuilder
                  ? counter.build.child(
                      activeChild,
                      (context, value, child) => Column(
                        children: [
                          Text('ChildBuilder: $value'),
                          if (child != null) child,
                        ],
                      ),
                      equals: activeEquals,
                      buildWhen: activeBuildWhen,
                    )
                  : counter.build(
                      (context, value) => Text('Builder: $value'),
                      equals: activeEquals,
                      buildWhen: activeBuildWhen,
                    ),
            );

        await tester.pumpWidget(buildHost());
        expect(find.text('Builder: 0'), findsOneWidget);
        expect(watched, 1);
        expect(unwatched, 0);

        // Update equals without changing signal instance.
        activeEquals = (prev, curr) => (prev ~/ 10) == (curr ~/ 10);
        await tester.pumpWidget(buildHost());
        expect(watched, 1);
        expect(unwatched, 0);

        counter.value = 5;
        await tester.pump();
        expect(find.text('Builder: 0'), findsOneWidget);

        counter.value = 10;
        await tester.pump();
        expect(find.text('Builder: 10'), findsOneWidget);

        // Update buildWhen without changing signal instance.
        activeBuildWhen = (prev, curr) => curr.isEven;
        await tester.pumpWidget(buildHost());
        expect(watched, 1);
        expect(unwatched, 0);

        counter.value = 21;
        await tester.pump();
        expect(find.text('Builder: 10'), findsOneWidget);

        counter.value = 30;
        await tester.pump();
        expect(find.text('Builder: 30'), findsOneWidget);

        // Switch from .build to .build.child without changing signal instance.
        useChildBuilder = true;
        await tester.pumpWidget(buildHost());
        expect(find.text('ChildBuilder: 30'), findsOneWidget);
        expect(find.text('Child A'), findsOneWidget);
        expect(watched, 1);
        expect(unwatched, 0);

        // Update child without changing signal instance.
        activeChild = const Text('Child B');
        await tester.pumpWidget(buildHost());
        expect(find.text('ChildBuilder: 30'), findsOneWidget);
        expect(find.text('Child B'), findsOneWidget);
        expect(watched, 1);
        expect(unwatched, 0);

        counter.value = 40;
        await tester.pump();
        expect(find.text('ChildBuilder: 40'), findsOneWidget);
        expect(find.text('Child B'), findsOneWidget);

        // Switch back from .build.child to .build without re-subscribing.
        useChildBuilder = false;
        await tester.pumpWidget(buildHost());
        expect(find.text('Builder: 40'), findsOneWidget);
        expect(find.text('Child B'), findsNothing);
        expect(watched, 1);
        expect(unwatched, 0);
      },
    );

    testWidgets(
      '(Issue #393) dispose cleans up effect subscription so post-unmount '
      'mutations do not trigger callbacks or setState',
      (tester) async {
        var watched = 0;
        var unwatched = 0;
        var equalsCalls = 0;
        var buildWhenCalls = 0;
        final counter = signal<int>(
          0,
          options: SignalOptions<int>(
            watched: () => watched++,
            unwatched: () => unwatched++,
          ),
        );
        addTearDown(counter.dispose);

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: counter.build(
              (context, value) => Text('Value: $value'),
              equals: (prev, curr) {
                equalsCalls++;
                return prev == curr;
              },
              buildWhen: (prev, curr) {
                buildWhenCalls++;
                return true;
              },
            ),
          ),
        );
        expect(find.text('Value: 0'), findsOneWidget);
        expect(watched, 1);
        expect(unwatched, 0);

        await tester.pumpWidget(const SizedBox.shrink());
        expect(watched, 1);
        expect(unwatched, 1);

        // Mutating after unmount must not invoke callbacks or trigger setState.
        counter.value = 50;
        await tester.pump();
        expect(equalsCalls, 0);
        expect(buildWhenCalls, 0);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '(Issue #393) throwing builder on initial mount surfaces exception '
      'and cleans up subscription on unmount',
      (tester) async {
        var watched = 0;
        var unwatched = 0;
        final counter = signal<int>(
          0,
          options: SignalOptions<int>(
            watched: () => watched++,
            unwatched: () => unwatched++,
          ),
        );
        addTearDown(counter.dispose);

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: counter.build(
              (context, value) => throw StateError('initial boom'),
            ),
          ),
        );

        expect(tester.takeException(), isA<StateError>());
        expect(watched, 1);

        await tester.pumpWidget(const SizedBox.shrink());
        expect(unwatched, 1);
      },
    );

    testWidgets(
      '(Issue #393) throwing builder on reactive update surfaces exception '
      'for .build and .build.child without leaking subscriptions',
      (tester) async {
        var watchedBuild = 0;
        var unwatchedBuild = 0;
        final buildSignal = signal<int>(
          0,
          options: SignalOptions<int>(
            watched: () => watchedBuild++,
            unwatched: () => unwatchedBuild++,
          ),
        );
        addTearDown(buildSignal.dispose);

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: buildSignal.build((context, value) {
              if (value == 1) {
                throw StateError('build update boom');
              }
              return Text('Build: $value');
            }),
          ),
        );
        expect(find.text('Build: 0'), findsOneWidget);
        expect(watchedBuild, 1);
        expect(unwatchedBuild, 0);

        buildSignal.value = 1;
        await tester.pump();
        expect(tester.takeException(), isA<StateError>());

        await tester.pumpWidget(const SizedBox.shrink());
        expect(unwatchedBuild, 1);

        var watchedChild = 0;
        var unwatchedChild = 0;
        final childSignal = signal<int>(
          0,
          options: SignalOptions<int>(
            watched: () => watchedChild++,
            unwatched: () => unwatchedChild++,
          ),
        );
        addTearDown(childSignal.dispose);

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: childSignal.build.child(
              const SizedBox.shrink(),
              (context, value, child) {
                if (value == 1) {
                  throw StateError('child update boom');
                }
                return Text('ChildBuild: $value');
              },
            ),
          ),
        );
        expect(find.text('ChildBuild: 0'), findsOneWidget);
        expect(watchedChild, 1);
        expect(unwatchedChild, 0);

        childSignal.value = 1;
        await tester.pump();
        expect(tester.takeException(), isA<StateError>());

        await tester.pumpWidget(const SizedBox.shrink());
        expect(unwatchedChild, 1);
      },
    );

    testWidgets(
      '(Issue #393) debugFillProperties includes signal and child',
      (tester) async {
        final counter = signal<int>(5);
        addTearDown(counter.dispose);
        const childWidget = SizedBox.shrink();

        final widget = counter.build.child(
          childWidget,
          (context, value, child) => child ?? const SizedBox.shrink(),
          buildWhen: (prev, curr) => prev != curr,
          equals: (prev, curr) => prev == curr,
        );

        final builder = DiagnosticPropertiesBuilder();
        widget.debugFillProperties(builder);

        final names = builder.properties.map((p) => p.name).toList();
        expect(
          names,
          containsAll(<String>['signal', 'child', 'buildWhen', 'equals']),
        );
      },
    );

    testWidgets(
      '(Issue #393) ReadonlySignal.build rebuilds on ListSignal in-place '
      'mutations',
      (tester) async {
        final items = listSignal<int>(<int>[1, 2]);
        addTearDown(items.dispose);

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: items.build((context, value) => Text('Items: $value')),
          ),
        );

        expect(find.text('Items: [1, 2]'), findsOneWidget);

        items.add(3);
        await tester.pump();

        expect(find.text('Items: [1, 2, 3]'), findsOneWidget);
      },
    );

    testWidgets(
      '(Issue #393) ReadonlySignal.build honors SignalEquality.custom when '
      'widget.equals is omitted',
      (tester) async {
        final counter = signal<int>(
          0,
          options: SignalOptions<int>(
            equality: SignalEquality.custom((_, __) => false),
          ),
        );
        addTearDown(counter.dispose);
        var builds = 0;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: counter.build((context, value) {
              builds++;
              return Text('Value: $value (builds: $builds)');
            }),
          ),
        );

        expect(find.text('Value: 0 (builds: 1)'), findsOneWidget);

        counter.value = 0;
        await tester.pump();

        expect(find.text('Value: 0 (builds: 2)'), findsOneWidget);
      },
    );

    testWidgets(
      '(Issue #393) cubit.state.build rebuilds on custom-equals CubitSignal '
      'emissions',
      (tester) async {
        final cubit = _AlwaysEmitCubit(5);
        addTearDown(cubit.close);
        var builds = 0;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: cubit.state.build((context, value) {
              builds++;
              return Text('State: $value (builds: $builds)');
            }),
          ),
        );

        expect(find.text('State: 5 (builds: 1)'), findsOneWidget);

        cubit.emitValue(5);
        await tester.pump();

        expect(find.text('State: 5 (builds: 2)'), findsOneWidget);
      },
    );

    testWidgets(
      '(Issue #393) auxiliary signals read in equals and buildWhen do not '
      'trigger rebuilds when primary signal is unchanged',
      (tester) async {
        final primary = signal<int>(0);
        addTearDown(primary.dispose);
        final auxEquals = signal<int>(0);
        addTearDown(auxEquals.dispose);
        final auxBuildWhen = signal<int>(0);
        addTearDown(auxBuildWhen.dispose);
        var builds = 0;
        var equalsCalls = 0;
        var buildWhenCalls = 0;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: primary.build(
              (context, value) {
                builds++;
                return Text('Primary: $value');
              },
              equals: (prev, curr) {
                equalsCalls++;
                final _ = auxEquals.value;
                return prev == curr;
              },
              buildWhen: (prev, curr) {
                buildWhenCalls++;
                final _ = auxBuildWhen.value;
                return true;
              },
            ),
          ),
        );

        expect(builds, 1);
        expect(equalsCalls, 0);
        expect(buildWhenCalls, 0);

        primary.value = 1;
        await tester.pump();
        expect(builds, 2);
        expect(equalsCalls, 1);
        expect(buildWhenCalls, 1);

        auxEquals.value = 42;
        auxBuildWhen.value = 99;
        await tester.pump();
        expect(builds, 2);
        expect(equalsCalls, 1);
        expect(buildWhenCalls, 1);
      },
    );

    testWidgets(
      '(Issue #393) signal mutation during sibling deactivate does not throw',
      (tester) async {
        final counter = signal<int>(0);
        addTearDown(counter.dispose);

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Column(
              children: [
                counter.build((context, value) => Text('Value: $value')),
                _DeactivateMutator(
                  onDeactivate: () => counter.value = 1,
                  child: const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        );

        expect(find.text('Value: 0'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '(Issue #393) GlobalKey reparenting reactivates widget and continues '
      'rebuilding on signal updates',
      (tester) async {
        final counter = signal<int>(10);
        addTearDown(counter.dispose);
        final widgetKey = GlobalKey();
        final builtWidget = counter.build(
          (context, value) => Text('Reparented: $value'),
          key: widgetKey,
        );

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Column(children: [builtWidget]),
          ),
        );
        expect(find.text('Reparented: 10'), findsOneWidget);

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(children: [builtWidget]),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Reparented: 10'), findsOneWidget);

        counter.value = 20;
        await tester.pump();
        expect(find.text('Reparented: 20'), findsOneWidget);
      },
    );

    testWidgets(
      '(Issue #393) GlobalKey reparenting reconciles signal update emitted '
      'between deactivate and activate',
      (tester) async {
        final counter = signal<int>(10);
        addTearDown(counter.dispose);
        final widgetKey = GlobalKey();
        final builtWidget = counter.build(
          (context, value) => Text('Reparented: $value'),
          key: widgetKey,
        );

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Column(
              children: [
                builtWidget,
                _DeactivateMutator(
                  onDeactivate: () => counter.value = 99,
                  child: const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        );
        expect(find.text('Reparented: 10'), findsOneWidget);

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(children: [builtWidget]),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Reparented: 99'), findsOneWidget);

        counter.value = 100;
        await tester.pump();
        expect(find.text('Reparented: 100'), findsOneWidget);
      },
    );

    testWidgets(
      '(Issue #393) BlocSignalBase.build ignores cubit emission during '
      'sibling deactivate without throwing',
      (tester) async {
        final cubit = _CounterCubit();
        addTearDown(cubit.close);

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Column(
              children: [
                cubit.build((context, state) => Text('Cubit: $state')),
                _DeactivateMutator(
                  onDeactivate: cubit.increment,
                  child: const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        );

        expect(find.text('Cubit: 0'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '(Issue #393) BlocSignalBase.build GlobalKey reparenting reconciles '
      'cubit emission between deactivate and activate',
      (tester) async {
        final cubit = _CounterCubit(10);
        addTearDown(cubit.close);
        final widgetKey = GlobalKey();
        final builtWidget = cubit.build(
          (context, state) => Text('CubitReparented: $state'),
          key: widgetKey,
        );

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Column(
              children: [
                builtWidget,
                _DeactivateMutator(
                  onDeactivate: () => cubit.setValue(99),
                  child: const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        );
        expect(find.text('CubitReparented: 10'), findsOneWidget);

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(children: [builtWidget]),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('CubitReparented: 99'), findsOneWidget);

        cubit.setValue(100);
        await tester.pump();
        expect(find.text('CubitReparented: 100'), findsOneWidget);
      },
    );

    testWidgets(
      '(Issue #393) auxiliary signals read in BlocSignalBase.build buildWhen '
      'do not trigger rebuilds when cubit state is unchanged',
      (tester) async {
        final cubit = _AlwaysEmitCubit();
        addTearDown(cubit.close);
        final auxBuildWhen = signal<int>(0);
        addTearDown(auxBuildWhen.dispose);
        var builds = 0;
        var buildWhenCalls = 0;

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: cubit.build(
              (context, state) {
                builds++;
                return Text('State: $state');
              },
              buildWhen: (prev, curr) {
                buildWhenCalls++;
                final _ = auxBuildWhen.value;
                return true;
              },
            ),
          ),
        );

        expect(builds, 1);
        expect(buildWhenCalls, 0);

        cubit.emitValue(0);
        await tester.pump();
        expect(builds, 2);
        expect(buildWhenCalls, 1);

        auxBuildWhen.value = 42;
        await tester.pump();
        expect(builds, 2);
        expect(buildWhenCalls, 1);
      },
    );
  });
}
