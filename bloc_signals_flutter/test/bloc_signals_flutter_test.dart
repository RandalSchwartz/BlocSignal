import 'dart:async';

import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
// Preserves sdk: ^3.5.0 compatibility on Flutter <3.47.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signals_flutter/signals_flutter.dart';

sealed class CounterEvent {}

class Increment extends CounterEvent {}

class CounterBloc extends BlocSignal<CounterEvent, int> {
  CounterBloc() : super(initialState: 0);

  @override
  void onEvent(CounterEvent event) {
    unawaited(Future.value(super.onEvent(event)));
    switch (event) {
      case Increment():
        emit(stateValue + 1);
    }
  }
}

class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void increment() => emit(stateValue + 1);
}

void main() {
  group('BlocSignal Flutter Bindings Tests', () {
    testWidgets('BlocSignalProvider injects and disposes BlocSignal', (
      tester,
    ) async {
      late CounterBloc bloc;

      final widget = BlocSignalProvider<CounterBloc>(
        create: (context) => bloc = CounterBloc(),
        child: Builder(
          builder: (context) {
            final retrievedBloc = context.read<CounterBloc>();
            expect(retrievedBloc, equals(bloc));
            return const SizedBox();
          },
        ),
      );

      await tester.pumpWidget(MaterialApp(home: widget));

      // Ensure the widget builds
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('BlocSignalBuilder rebuilds dynamically on state change', (
      tester,
    ) async {
      final bloc = CounterBloc();

      final widget = MaterialApp(
        home: Scaffold(
          body: BlocSignalBuilder<CounterBloc, int>(
            bloc: bloc,
            builder: (context, state) {
              return Text('Count: $state');
            },
          ),
        ),
      );

      await tester.pumpWidget(widget);
      expect(find.text('Count: 0'), findsOneWidget);

      bloc.add(Increment());
      await tester.pump(); // Pump frame to trigger watch rebuild

      expect(find.text('Count: 1'), findsOneWidget);
      await bloc.close();
    });

    testWidgets(
      'BlocSignalBuilder reacts to provided bloc changes',
      (tester) async {
        final bloc1 = CounterBloc();
        final bloc2 = CounterBloc()..emit(42);

        final builderWidget = BlocSignalBuilder<CounterBloc, int>(
          builder: (context, state) {
            return Text('Count: $state');
          },
        );

        Widget buildWidget(CounterBloc bloc) {
          return BlocSignalProvider<CounterBloc>.value(
            value: bloc,
            child: builderWidget,
          );
        }

        await tester.pumpWidget(MaterialApp(home: buildWidget(bloc1)));
        expect(find.text('Count: 0'), findsOneWidget);

        // Rebuild with bloc2
        await tester.pumpWidget(MaterialApp(home: buildWidget(bloc2)));
        expect(find.text('Count: 42'), findsOneWidget);

        await bloc1.close();
        await bloc2.close();
      },
    );

    testWidgets('MultiBlocSignalProvider provides multiple blocs', (
      tester,
    ) async {
      final bloc = CounterBloc();
      final widget = MaterialApp(
        home: MultiBlocSignalProvider(
          providers: [
            BlocSignalProvider<CounterBloc>(
              create: (_) => CounterBloc(),
            ),
            BlocSignalProvider<CounterBloc>.value(
              value: bloc,
            ),
          ],
          child: Builder(
            builder: (context) {
              final counterBloc = context.read<CounterBloc>();
              expect(counterBloc, isNotNull);
              return const SizedBox();
            },
          ),
        ),
      );

      await tester.pumpWidget(widget);
      expect(find.byType(SizedBox), findsOneWidget);
      await bloc.close();
    });

    testWidgets(
      'BlocSignalProvider and BlocSignalListener support optional child '
      'parameter',
      (tester) async {
        final bloc = CounterBloc();
        final states = <int>[];

        final widget = MaterialApp(
          home: MultiBlocSignalListener(
            listeners: [
              BlocSignalListener<CounterBloc, int>(
                bloc: bloc,
                listener: (context, state) => states.add(state),
              ),
            ],
            child: BlocSignalProvider<CounterBloc>.value(
              value: bloc,
            ),
          ),
        );

        await tester.pumpWidget(widget);
        expect(states, isEmpty);

        bloc.add(Increment());
        await tester.pump();
        expect(states, equals([1]));

        await bloc.close();
      },
    );

    testWidgets(
      'BlocSignalProvider.value injects existing bloc without closing it',
      (tester) async {
        final bloc = CounterBloc();

        final widget = BlocSignalProvider<CounterBloc>.value(
          value: bloc,
          child: Builder(
            builder: (context) {
              final retrievedBloc = context.read<CounterBloc>();
              expect(retrievedBloc, equals(bloc));
              return const SizedBox();
            },
          ),
        );

        await tester.pumpWidget(MaterialApp(home: widget));
        expect(find.byType(SizedBox), findsOneWidget);

        // Verify that disposing the provider does not close the bloc
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));

        bloc.add(Increment());
        expect(bloc.stateValue, equals(1));
        await bloc.close();
      },
    );

    testWidgets(
      'context.watch listens and rebuilds when the bloc instance changes',
      (tester) async {
        final bloc1 = CounterBloc();
        final bloc2 = CounterBloc()..emit(42);

        final widget1 = BlocSignalProvider<CounterBloc>.value(
          value: bloc1,
          child: Builder(
            builder: (context) {
              final watchedBloc = context.watch<CounterBloc>();
              return Text('Value: ${watchedBloc.stateValue}');
            },
          ),
        );

        await tester.pumpWidget(MaterialApp(home: widget1));
        expect(find.text('Value: 0'), findsOneWidget);

        final widget2 = BlocSignalProvider<CounterBloc>.value(
          value: bloc2,
          child: Builder(
            builder: (context) {
              final watchedBloc = context.watch<CounterBloc>();
              return Text('Value: ${watchedBloc.stateValue}');
            },
          ),
        );

        await tester.pumpWidget(MaterialApp(home: widget2));
        expect(find.text('Value: 42'), findsOneWidget);

        await bloc1.close();
        await bloc2.close();
      },
    );

    testWidgets(
      'BlocSignalProvider.of throws FlutterError when not found in context',
      (tester) async {
        final widget = MaterialApp(
          home: Builder(
            builder: (context) {
              expect(
                () => context.read<CounterBloc>(),
                throwsA(isA<FlutterError>()),
              );
              return const SizedBox();
            },
          ),
        );

        await tester.pumpWidget(widget);
        expect(find.byType(SizedBox), findsOneWidget);
      },
    );

    testWidgets(
        'CubitSignal works with BlocSignalProvider and BlocSignalBuilder', (
      tester,
    ) async {
      final cubit = CounterCubit();

      final widget = MaterialApp(
        home: BlocSignalProvider<CounterCubit>.value(
          value: cubit,
          child: Scaffold(
            body: BlocSignalBuilder<CounterCubit, int>(
              builder: (context, state) {
                final readCubit = context.read<CounterCubit>();
                expect(readCubit, equals(cubit));
                return Text('Count: $state');
              },
            ),
          ),
        ),
      );

      await tester.pumpWidget(widget);
      expect(find.text('Count: 0'), findsOneWidget);

      cubit.increment();
      await tester.pump();

      expect(find.text('Count: 1'), findsOneWidget);
      await cubit.close();
    });

    testWidgets('BlocSignalListener triggers callback on state changes', (
      tester,
    ) async {
      final bloc = CounterBloc();
      final states = <int>[];

      final widget = MaterialApp(
        home: BlocSignalListener<CounterBloc, int>(
          bloc: bloc,
          listener: (context, state) {
            states.add(state);
          },
          child: const SizedBox(),
        ),
      );

      await tester.pumpWidget(widget);
      expect(states, isEmpty);

      bloc.add(Increment());
      await tester.pump();
      expect(states, equals([1]));

      await bloc.close();
    });

    testWidgets('BlocSignalConsumer both builds and listens', (
      tester,
    ) async {
      final bloc = CounterBloc();
      final states = <int>[];

      final widget = MaterialApp(
        home: BlocSignalConsumer<CounterBloc, int>(
          bloc: bloc,
          listener: (context, state) {
            states.add(state);
          },
          builder: (context, state) {
            return Text('Consumer Count: $state');
          },
        ),
      );

      await tester.pumpWidget(widget);
      expect(find.text('Consumer Count: 0'), findsOneWidget);
      expect(states, isEmpty);

      bloc.add(Increment());
      await tester.pump();

      expect(find.text('Consumer Count: 1'), findsOneWidget);
      expect(states, equals([1]));

      await bloc.close();
    });

    testWidgets(
        'BlocSignalSelector only rebuilds when selected sub-state changes', (
      tester,
    ) async {
      final cubit = CounterCubit();
      var builds = 0;

      final widget = MaterialApp(
        home: BlocSignalSelector<CounterCubit, int, bool>(
          bloc: cubit,
          selector: (state) => state >= 2,
          builder: (context, isGreaterOrEqualTwo) {
            builds++;
            return Text('GEQ2: $isGreaterOrEqualTwo');
          },
        ),
      );

      await tester.pumpWidget(widget);
      expect(find.text('GEQ2: false'), findsOneWidget);
      expect(builds, equals(1));

      // Change state from 0 to 1 -> isGreaterOrEqualTwo is still false
      cubit.increment();
      await tester.pump();
      expect(find.text('GEQ2: false'), findsOneWidget);
      expect(builds, equals(1)); // No rebuild: selection didn't change

      // Change state from 1 to 2 -> isGreaterOrEqualTwo becomes true
      cubit.increment();
      await tester.pump();
      expect(find.text('GEQ2: true'), findsOneWidget);
      expect(builds, equals(2)); // Rebuilt!

      await cubit.close();
    });

    testWidgets(
      'BlocSignalListener reacts to provided bloc changes',
      (tester) async {
        final bloc1 = CounterBloc();
        final bloc2 = CounterBloc()..emit(42);
        final states = <int>[];

        Widget buildWidget(CounterBloc bloc) {
          return BlocSignalProvider<CounterBloc>.value(
            value: bloc,
            child: BlocSignalListener<CounterBloc, int>(
              listener: (context, state) {
                states.add(state);
              },
              child: const SizedBox(),
            ),
          );
        }

        await tester.pumpWidget(MaterialApp(home: buildWidget(bloc1)));
        expect(states, isEmpty);

        // Rebuild with bloc2
        await tester.pumpWidget(MaterialApp(home: buildWidget(bloc2)));
        expect(states, isEmpty);

        // Trigger change on bloc2
        bloc2.add(Increment());
        await tester.pump();
        expect(states, equals([43]));

        // Verify that changing bloc1 doesn't trigger anymore
        bloc1.add(Increment());
        await tester.pump();
        expect(states, equals([43]));

        await bloc1.close();
        await bloc2.close();
      },
    );

    testWidgets(
      'BlocSignalSelector rebuilds when selector function changes',
      (tester) async {
        final cubit = CounterCubit()..emit(1);
        var builds = 0;

        Widget buildWidget(bool Function(int) selector) {
          return BlocSignalSelector<CounterCubit, int, bool>(
            bloc: cubit,
            selector: selector,
            builder: (context, val) {
              builds++;
              return Text('Val: $val');
            },
          );
        }

        await tester
            .pumpWidget(MaterialApp(home: buildWidget((state) => state >= 2)));
        expect(find.text('Val: false'), findsOneWidget);
        expect(builds, equals(1));

        // Rebuild with new selector: state >= 1
        await tester
            .pumpWidget(MaterialApp(home: buildWidget((state) => state >= 1)));
        expect(find.text('Val: true'), findsOneWidget);
        expect(builds, equals(2));

        await cubit.close();
      },
    );

    testWidgets('BlocSignalProvider lazy creation works', (tester) async {
      var createCalls = 0;
      final widget = BlocSignalProvider<CounterBloc>(
        create: (context) {
          createCalls++;
          return CounterBloc();
        },
        child: Builder(
          builder: (context) {
            expect(createCalls, equals(0)); // Eagerly not created
            context.read<CounterBloc>();
            expect(createCalls, equals(1)); // Created on demand
            return const SizedBox();
          },
        ),
      );
      await tester.pumpWidget(MaterialApp(home: widget));
    });

    testWidgets('BlocSignalProvider non-lazy creation works', (tester) async {
      var createCalls = 0;
      final widget = BlocSignalProvider<CounterBloc>(
        create: (context) {
          createCalls++;
          return CounterBloc();
        },
        lazy: false,
        child: Builder(
          builder: (context) {
            expect(createCalls, equals(1)); // Eagerly created
            return const SizedBox();
          },
        ),
      );
      await tester.pumpWidget(MaterialApp(home: widget));
    });

    testWidgets('BlocSignalListener with listenWhen triggers conditionally', (
      tester,
    ) async {
      final bloc = CounterBloc();
      final states = <int>[];

      final widget = MaterialApp(
        home: BlocSignalListener<CounterBloc, int>(
          bloc: bloc,
          listenWhen: (previous, current) => current.isEven,
          listener: (context, state) {
            states.add(state);
          },
          child: const SizedBox(),
        ),
      );

      await tester.pumpWidget(widget);
      expect(states, isEmpty); // Initial state doesn't trigger listener

      bloc.add(Increment()); // State is 1
      await tester.pump();
      expect(states, isEmpty); // 1 is odd

      bloc.add(Increment()); // State is 2
      await tester.pump();
      expect(states, equals([2])); // 2 is even

      await bloc.close();
    });

    testWidgets('MultiBlocSignalListener triggers multiple callbacks', (
      tester,
    ) async {
      final bloc1 = CounterBloc();
      final bloc2 = CounterCubit();
      final states1 = <int>[];
      final states2 = <int>[];

      final widget = MaterialApp(
        home: MultiBlocSignalListener(
          listeners: [
            BlocSignalListener<CounterBloc, int>(
              bloc: bloc1,
              listener: (context, state) => states1.add(state),
              child: const SizedBox(),
            ),
            BlocSignalListener<CounterCubit, int>(
              bloc: bloc2,
              listener: (context, state) => states2.add(state),
              child: const SizedBox(),
            ),
          ],
          child: const SizedBox(),
        ),
      );

      await tester.pumpWidget(widget);

      bloc1.add(Increment());
      bloc2.increment();
      await tester.pump();

      expect(states1, equals([1]));
      expect(states2, equals([1]));

      await bloc1.close();
      await bloc2.close();
    });

    testWidgets('context.select rebuilds only when selected sub-state changes',
        (
      tester,
    ) async {
      final bloc = CounterBloc();
      var builds = 0;

      final widget = MaterialApp(
        home: BlocSignalProvider<CounterBloc>.value(
          value: bloc,
          child: Builder(
            builder: (context) {
              builds++;
              final isEven =
                  context.select<CounterBloc, bool>((b) => b.stateValue.isEven);
              return Text('isEven: $isEven');
            },
          ),
        ),
      );

      await tester.pumpWidget(widget);
      expect(find.text('isEven: true'), findsOneWidget);
      expect(builds, equals(1));

      bloc.add(Increment()); // State is 1 (isEven = false)
      await tester.pump();
      expect(find.text('isEven: false'), findsOneWidget);
      expect(builds, equals(2));

      bloc.add(Increment()); // State is 2 (isEven = true)
      await tester.pump();
      expect(find.text('isEven: true'), findsOneWidget);
      expect(builds, equals(3));

      await bloc.close();
    });

    testWidgets('Multiple context.select calls on the same element work', (
      tester,
    ) async {
      final bloc = CounterBloc();
      var builds = 0;

      final widget = MaterialApp(
        home: BlocSignalProvider<CounterBloc>.value(
          value: bloc,
          child: Builder(
            builder: (context) {
              builds++;
              final isEven =
                  context.select<CounterBloc, bool>((b) => b.stateValue.isEven);
              final isPositive =
                  context.select<CounterBloc, bool>((b) => b.stateValue >= 0);
              return Text('isEven: $isEven, isPositive: $isPositive');
            },
          ),
        ),
      );

      await tester.pumpWidget(widget);
      expect(find.text('isEven: true, isPositive: true'), findsOneWidget);
      expect(builds, equals(1));

      bloc.add(Increment()); // State is 1
      await tester.pump();
      expect(find.text('isEven: false, isPositive: true'), findsOneWidget);
      expect(builds, equals(2));

      await bloc.close();
    });

    testWidgets(
      'MultiBlocSignalProvider enables context lookups across providers',
      (tester) async {
        late CounterCubit cubit;
        late CounterBloc bloc;

        final widget = MultiBlocSignalProvider(
          providers: [
            BlocSignalProvider(create: (context) => cubit = CounterCubit()),
            BlocSignalProvider(
              create: (context) {
                // Ensure lower provider can read upper provider in create
                final parentCubit = context.read<CounterCubit>();
                expect(parentCubit, equals(cubit));
                return bloc = CounterBloc();
              },
            ),
          ],
          child: Builder(
            builder: (context) {
              final retrievedCubit = context.read<CounterCubit>();
              final retrievedBloc = context.read<CounterBloc>();
              expect(retrievedCubit, equals(cubit));
              expect(retrievedBloc, equals(bloc));
              return const SizedBox();
            },
          ),
        );

        await tester.pumpWidget(MaterialApp(home: widget));
        expect(find.byType(SizedBox), findsOneWidget);
      },
    );

    testWidgets(
      'BlocSignalBuilder respects buildWhen predicate',
      (tester) async {
        final bloc = CounterBloc();
        var buildCount = 0;

        final widget = MaterialApp(
          home: BlocSignalBuilder<CounterBloc, int>(
            bloc: bloc,
            buildWhen: (previous, current) => current.isEven,
            builder: (context, state) {
              buildCount++;
              return Text('State: $state');
            },
          ),
        );

        await tester.pumpWidget(widget);
        expect(find.text('State: 0'), findsOneWidget);
        expect(buildCount, equals(1));

        bloc.add(Increment()); // State becomes 1 (odd) -> skipped by buildWhen
        await tester.pump();
        expect(find.text('State: 0'), findsOneWidget);
        expect(buildCount, equals(1));

        bloc.add(Increment()); // State becomes 2 (even) -> built by buildWhen
        await tester.pump();
        expect(find.text('State: 2'), findsOneWidget);
        expect(buildCount, equals(2));

        await bloc.close();
      },
    );

    testWidgets(
      'BlocSignalConsumer respects buildWhen and listenWhen predicates',
      (tester) async {
        final bloc = CounterBloc();
        final listenedStates = <int>[];
        var buildCount = 0;

        final widget = MaterialApp(
          home: BlocSignalConsumer<CounterBloc, int>(
            bloc: bloc,
            buildWhen: (previous, current) => current.isEven,
            listenWhen: (previous, current) => current > 1,
            listener: (context, state) => listenedStates.add(state),
            builder: (context, state) {
              buildCount++;
              return Text('Count: $state');
            },
          ),
        );

        await tester.pumpWidget(widget);
        expect(find.text('Count: 0'), findsOneWidget);
        expect(buildCount, equals(1));

        bloc.add(Increment()); // State 1: buildWhen false, listenWhen false
        await tester.pump();
        expect(find.text('Count: 0'), findsOneWidget);
        expect(buildCount, equals(1));
        expect(listenedStates, isEmpty);

        bloc.add(Increment()); // State 2: buildWhen true, listenWhen true
        await tester.pump();
        expect(find.text('Count: 2'), findsOneWidget);
        expect(buildCount, equals(2));
        expect(listenedStates, equals([2]));

        await bloc.close();
      },
    );

    testWidgets(
      'MultiBlocSignalListener executes multiple listeners in list literal',
      (tester) async {
        final cubit = CounterCubit();
        final bloc = CounterBloc();
        final cubitStates = <int>[];
        final blocStates = <int>[];

        final widget = MultiBlocSignalListener(
          listeners: [
            BlocSignalListener<CounterCubit, int>(
              bloc: cubit,
              listener: (context, state) => cubitStates.add(state),
            ),
            BlocSignalListener<CounterBloc, int>(
              bloc: bloc,
              listener: (context, state) => blocStates.add(state),
            ),
          ],
          child: const SizedBox(),
        );

        await tester.pumpWidget(MaterialApp(home: widget));

        cubit.increment();
        bloc.add(Increment());
        await tester.pump();

        expect(cubitStates, equals([1]));
        expect(blocStates, equals([1]));

        await cubit.close();
        await bloc.close();
      },
    );

    testWidgets(
      'context.select transfers subscription when provider bloc instance '
      'is swapped above const subtree',
      (tester) async {
        final bloc1 = CounterBloc();
        final bloc2 = CounterBloc();

        Widget buildTree(CounterBloc bloc) {
          return MaterialApp(
            home: BlocSignalProvider<CounterBloc>.value(
              value: bloc,
              child: const _ConstSelectorChild(),
            ),
          );
        }

        await tester.pumpWidget(buildTree(bloc1));
        expect(find.text('Count: 0'), findsOneWidget);

        // Swap provider value to bloc2
        await tester.pumpWidget(buildTree(bloc2));
        expect(find.text('Count: 0'), findsOneWidget);

        // State changes on new bloc should trigger rebuild
        bloc2.add(Increment());
        await tester.pump();
        expect(find.text('Count: 1'), findsOneWidget);

        await bloc1.close();
        await bloc2.close();
      },
    );

    testWidgets(
      'context.value<T, S>() rebuilds reactively on state emission with '
      'explicit state type',
      (tester) async {
        final cubit = CounterCubit();
        var builds = 0;

        final widget = MaterialApp(
          home: BlocSignalProvider<CounterCubit>.value(
            value: cubit,
            child: Builder(
              builder: (context) {
                builds++;
                final count = context.value<CounterCubit, int>();
                // Assert type at compile-time by passing to typed helper
                expect(count, isA<int>());
                return Text('Count: $count');
              },
            ),
          ),
        );

        await tester.pumpWidget(widget);
        expect(find.text('Count: 0'), findsOneWidget);
        expect(builds, equals(1));

        cubit.increment();
        await tester.pump();
        expect(find.text('Count: 1'), findsOneWidget);
        expect(builds, equals(2));

        await cubit.close();
      },
    );

    testWidgets(
      'context.value<T, S>() scopes rebuilds when wrapped inside Builder',
      (tester) async {
        final cubit = CounterCubit();
        var parentBuilds = 0;
        var scopedBuilds = 0;

        final widget = MaterialApp(
          home: BlocSignalProvider<CounterCubit>.value(
            value: cubit,
            child: Builder(
              builder: (context) {
                parentBuilds++;
                return Column(
                  children: [
                    const Text('Parent'),
                    Builder(
                      builder: (innerContext) {
                        scopedBuilds++;
                        final count = innerContext.value<CounterCubit, int>();
                        return Text('Scoped: $count');
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        );

        await tester.pumpWidget(widget);
        expect(parentBuilds, equals(1));
        expect(scopedBuilds, equals(1));
        expect(find.text('Scoped: 0'), findsOneWidget);

        cubit.increment();
        await tester.pump();
        // Parent must not rebuild; only scoped inner builder rebuilds
        expect(parentBuilds, equals(1));
        expect(scopedBuilds, equals(2));
        expect(find.text('Scoped: 1'), findsOneWidget);

        await cubit.close();
      },
    );

    testWidgets(
      'context.state<T, S>() returns ReadonlySignal for computed signal '
      'composition without rebuilding context',
      (tester) async {
        final cubit = CounterCubit();
        var builds = 0;
        late Computed<String> derivedSummary;

        final widget = MaterialApp(
          home: BlocSignalProvider<CounterCubit>.value(
            value: cubit,
            child: Builder(
              builder: (context) {
                builds++;
                final stateSignal = context.state<CounterCubit, int>();
                derivedSummary =
                    computed(() => 'Computed: ${stateSignal.value}');
                return const Text('Static UI');
              },
            ),
          ),
        );

        await tester.pumpWidget(widget);
        expect(builds, equals(1));
        expect(derivedSummary.value, equals('Computed: 0'));

        cubit.increment();
        await tester.pump();
        // context.state must NOT trigger an element rebuild on context
        expect(builds, equals(1));
        // But the computed signal reacts synchronously to the underlying
        // state signal
        expect(derivedSummary.value, equals('Computed: 1'));

        await cubit.close();
      },
    );

    testWidgets(
      'context.state<T, S>() rebinds when ancestor provider container is '
      'swapped',
      (tester) async {
        final cubit1 = CounterCubit();
        final cubit2 = CounterCubit();
        var builds = 0;
        ReadonlySignal<int>? currentSignal;

        Widget buildTree(CounterCubit cubit) {
          return MaterialApp(
            home: BlocSignalProvider<CounterCubit>.value(
              value: cubit,
              child: Builder(
                builder: (context) {
                  builds++;
                  currentSignal = context.state<CounterCubit, int>();
                  return Text(
                    'Signal Hash: ${identityHashCode(currentSignal)}',
                  );
                },
              ),
            ),
          );
        }

        await tester.pumpWidget(buildTree(cubit1));
        expect(builds, equals(1));
        expect(currentSignal, equals(cubit1.state));

        // State emissions do not trigger rebuilds
        cubit1.increment();
        await tester.pump();
        expect(builds, equals(1));

        // Swapping provider instance DOES trigger rebuild to update signal
        await tester.pumpWidget(buildTree(cubit2));
        expect(builds, equals(2));
        expect(currentSignal, equals(cubit2.state));

        await cubit1.close();
        await cubit2.close();
      },
    );

    testWidgets(
      'BlocSignalListener rebinds when ancestor provider instance is swapped '
      'above const child',
      (tester) async {
        final cubit1 = CounterCubit();
        final cubit2 = CounterCubit();
        final states = <int>[];

        Widget buildTree(CounterCubit cubit) {
          return MaterialApp(
            home: BlocSignalProvider<CounterCubit>.value(
              value: cubit,
              child: _ConstListenerChild(
                onState: states.add,
              ),
            ),
          );
        }

        await tester.pumpWidget(buildTree(cubit1));
        cubit1.increment(); // 1
        await tester.pump();
        expect(states, equals([1]));

        // Swap provider to cubit2
        await tester.pumpWidget(buildTree(cubit2));

        // cubit2 emissions should be received by listener
        cubit2.increment(); // 1
        await tester.pump();
        expect(states, equals([1, 1]));

        // cubit1 is now disconnected/disposed; emissions should not be received
        cubit1.increment(); // 2
        await tester.pump();
        expect(states, equals([1, 1]));

        await cubit1.close();
        await cubit2.close();
      },
    );

    testWidgets(
      'BlocSignalConsumer rebinds when ancestor provider instance is swapped',
      (tester) async {
        final cubit1 = CounterCubit();
        final cubit2 = CounterCubit();
        final listenedStates = <int>[];

        Widget buildTree(CounterCubit cubit) {
          return MaterialApp(
            home: BlocSignalProvider<CounterCubit>.value(
              value: cubit,
              child: BlocSignalConsumer<CounterCubit, int>(
                listener: (context, state) => listenedStates.add(state),
                builder: (context, state) => Text('ConsumerState: $state'),
              ),
            ),
          );
        }

        await tester.pumpWidget(buildTree(cubit1));
        expect(find.text('ConsumerState: 0'), findsOneWidget);

        cubit1.increment();
        await tester.pump();
        expect(find.text('ConsumerState: 1'), findsOneWidget);
        expect(listenedStates, equals([1]));

        // Swap to cubit2 (which is at initial state 0)
        await tester.pumpWidget(buildTree(cubit2));
        expect(find.text('ConsumerState: 0'), findsOneWidget);

        cubit2.increment();
        await tester.pump();
        expect(find.text('ConsumerState: 1'), findsOneWidget);
        expect(listenedStates, equals([1, 1]));

        // cubit1 is now disconnected; emissions should not be received
        cubit1.increment(); // 2
        await tester.pump();
        expect(find.text('ConsumerState: 1'), findsOneWidget);
        expect(listenedStates, equals([1, 1]));

        await cubit1.close();
        await cubit2.close();
      },
    );
  });

  group(
    'Issue #320: R6 — Custom equals/equalityCheck and didUpdate fallback '
    'listen: true',
    () {
      testWidgets(
        'BlocSignalBuilder and BlocSignalListener respect custom equals '
        '(identical) when state operator == returns true for distinct '
        'instances',
        (tester) async {
          final initial = _ValueEqualBox('alpha');
          final cubit = _IdentityBoxCubit(initial);
          var buildCount = 0;
          final builderStates = <_ValueEqualBox>[];
          final listenerStates = <_ValueEqualBox>[];

          await tester.pumpWidget(
            MaterialApp(
              home: BlocSignalProvider<_IdentityBoxCubit>.value(
                value: cubit,
                child: BlocSignalListener<_IdentityBoxCubit, _ValueEqualBox>(
                  listener: (context, state) {
                    listenerStates.add(state);
                  },
                  child: BlocSignalBuilder<_IdentityBoxCubit, _ValueEqualBox>(
                    builder: (context, state) {
                      buildCount++;
                      builderStates.add(state);
                      return Text('Box: ${state.label}');
                    },
                  ),
                ),
              ),
            ),
          );

          expect(buildCount, equals(1));
          expect(identical(builderStates.last, initial), isTrue);
          expect(listenerStates, isEmpty);

          // Emit a distinct instance with the exact same label (`==` is true,
          // but `identical` is false).
          final next = _ValueEqualBox('alpha');
          expect(next == initial, isTrue);
          expect(identical(next, initial), isFalse);

          cubit.emitBox(next);
          await tester.pump();

          expect(buildCount, equals(2));
          expect(identical(builderStates.last, next), isTrue);
          expect(listenerStates, hasLength(1));
          expect(identical(listenerStates.single, next), isTrue);

          await cubit.close();
        },
      );

      testWidgets(
        'BlocSignalSelector respects SignalOptions equalityCheck, equals '
        'comparator, Computed memoization, and re-initializes computed when '
        'options or equals changes',
        (tester) async {
          final cubit = _IdentityBoxCubit(_ValueEqualBox('alpha'));
          var buildCount = 0;
          var selectorCallCount = 0;
          final selectedValues = <String>[];
          var watchedACount = 0;
          var watchedBCount = 0;

          String labelSelector(_ValueEqualBox state) {
            selectorCallCount++;
            return state.label;
          }

          bool caseInsensitiveEquals(String a, String b) =>
              a.toLowerCase() == b.toLowerCase();

          final optionsA = SignalOptions<String>(
            name: 'SelectorOptionsA',
            watched: () => watchedACount++,
            equality: SignalEquality<String>.custom(caseInsensitiveEquals),
          );

          await tester.pumpWidget(
            MaterialApp(
              home: BlocSignalProvider<_IdentityBoxCubit>.value(
                value: cubit,
                child: BlocSignalSelector<_IdentityBoxCubit, _ValueEqualBox,
                    String>(
                  selector: labelSelector,
                  options: optionsA,
                  builder: (context, selected) {
                    buildCount++;
                    selectedValues.add(selected);
                    return Text('Selected: $selected');
                  },
                ),
              ),
            ),
          );

          expect(buildCount, equals(1));
          expect(watchedACount, equals(1));
          expect(selectorCallCount, equals(1));
          expect(selectedValues, equals(['alpha']));

          // Emitting a state whose projected value is equal under
          // SignalOptions.equalityCheck ('alpha' vs 'ALPHA') evaluates
          // selector once inside Computed and suppresses widget rebuild.
          cubit.emitBox(_ValueEqualBox('ALPHA'));
          await tester.pump();

          expect(selectorCallCount, equals(2));
          expect(buildCount, equals(1));
          expect(selectedValues, equals(['alpha']));

          // Emitting a state whose projected value is NOT equal ('beta')
          // triggers a single selector evaluation and rebuilds the widget.
          cubit.emitBox(_ValueEqualBox('beta'));
          await tester.pump();

          expect(selectorCallCount, equals(3));
          expect(buildCount, equals(2));
          expect(selectedValues, equals(['alpha', 'beta']));

          // Update options and provide explicit equals via didUpdateWidget
          // and verify _initComputed() re-initializes the computed signal.
          final optionsB = ComputedOptions<String>(
            name: 'SelectorOptionsB',
            watched: () => watchedBCount++,
          );
          bool exactEquals(String a, String b) => a == b;

          await tester.pumpWidget(
            MaterialApp(
              home: BlocSignalProvider<_IdentityBoxCubit>.value(
                value: cubit,
                child: BlocSignalSelector<_IdentityBoxCubit, _ValueEqualBox,
                    String>(
                  selector: labelSelector,
                  options: optionsB,
                  equals: exactEquals,
                  builder: (context, selected) {
                    buildCount++;
                    selectedValues.add(selected);
                    return Text('Selected: $selected');
                  },
                ),
              ),
            ),
          );

          expect(watchedBCount, equals(1));
          expect(buildCount, equals(3));

          // With exactEquals, 'BETA' != 'beta' so it rebuilds.
          cubit.emitBox(_ValueEqualBox('BETA'));
          await tester.pump();
          expect(buildCount, equals(4));
          expect(selectedValues.last, equals('BETA'));

          // Update only equals parameter via didUpdateWidget (keeping optionsB
          // identical) to verify oldWidget.equals != widget.equals triggers
          // _initComputed().
          await tester.pumpWidget(
            MaterialApp(
              home: BlocSignalProvider<_IdentityBoxCubit>.value(
                value: cubit,
                child: BlocSignalSelector<_IdentityBoxCubit, _ValueEqualBox,
                    String>(
                  selector: labelSelector,
                  options: optionsB,
                  equals: caseInsensitiveEquals,
                  builder: (context, selected) {
                    buildCount++;
                    selectedValues.add(selected);
                    return Text('Selected: $selected');
                  },
                ),
              ),
            ),
          );

          expect(buildCount, equals(5));

          // Now case-insensitive 'beta' matches 'BETA', suppressing rebuild.
          cubit.emitBox(_ValueEqualBox('beta'));
          await tester.pump();
          expect(buildCount, equals(5));

          // Also support ReadonlySignalOptions<V> directly.
          var watchedCCount = 0;
          final optionsC = ReadonlySignalOptions<String>(
            name: 'SelectorOptionsC',
            watched: () => watchedCCount++,
          );
          await tester.pumpWidget(
            MaterialApp(
              home: BlocSignalProvider<_IdentityBoxCubit>.value(
                value: cubit,
                child: BlocSignalSelector<_IdentityBoxCubit, _ValueEqualBox,
                    String>(
                  selector: labelSelector,
                  options: optionsC,
                  equals: caseInsensitiveEquals,
                  builder: (context, selected) {
                    buildCount++;
                    selectedValues.add(selected);
                    return Text('Selected: $selected');
                  },
                ),
              ),
            ),
          );

          expect(watchedCCount, equals(1));
          expect(buildCount, equals(6));

          // Verify stricter-than-`==` custom equality (for example `identical`
          // when `V.operator ==` returns true for distinct instances) triggers
          // rebuilds both via `equals: identical` and via
          // `SignalOptions(equality: SignalEquality.identical())`.
          final box1 = _ValueEqualBox('same');
          final box2 = _ValueEqualBox('same');
          final box3 = _ValueEqualBox('same');
          expect(box1 == box2, isTrue);
          expect(identical(box1, box2), isFalse);
          expect(box2 == box3, isTrue);
          expect(identical(box2, box3), isFalse);

          final boxCubit = _IdentityBoxCubit(box1);
          var boxBuildCount = 0;
          final selectedBoxes = <_ValueEqualBox>[];

          await tester.pumpWidget(
            MaterialApp(
              home: BlocSignalProvider<_IdentityBoxCubit>.value(
                value: boxCubit,
                child: BlocSignalSelector<_IdentityBoxCubit, _ValueEqualBox,
                    _ValueEqualBox>(
                  selector: (state) => state,
                  equals: identical,
                  builder: (context, selectedBox) {
                    boxBuildCount++;
                    selectedBoxes.add(selectedBox);
                    return Text('BoxIdentity: ${selectedBox.label}');
                  },
                ),
              ),
            ),
          );

          expect(boxBuildCount, equals(1));
          expect(identical(selectedBoxes.last, box1), isTrue);

          boxCubit.emitBox(box2);
          await tester.pump();
          expect(boxBuildCount, equals(2));
          expect(identical(selectedBoxes.last, box2), isTrue);

          await tester.pumpWidget(
            MaterialApp(
              home: BlocSignalProvider<_IdentityBoxCubit>.value(
                value: boxCubit,
                child: BlocSignalSelector<_IdentityBoxCubit, _ValueEqualBox,
                    _ValueEqualBox>(
                  selector: (state) => state,
                  options: SignalOptions<_ValueEqualBox>(
                    equality: SignalEquality<_ValueEqualBox>.custom(identical),
                  ),
                  builder: (context, selectedBox) {
                    boxBuildCount++;
                    selectedBoxes.add(selectedBox);
                    return Text('BoxIdentity: ${selectedBox.label}');
                  },
                ),
              ),
            ),
          );

          expect(boxBuildCount, equals(3));

          boxCubit.emitBox(box3);
          await tester.pump();
          expect(boxBuildCount, equals(4));
          expect(identical(selectedBoxes.last, box3), isTrue);

          // Verify constructor assertion rejects unsupported options types.
          expect(
            () => BlocSignalSelector<_IdentityBoxCubit, _ValueEqualBox, String>(
              selector: (state) => state.label,
              options: 'invalid',
              builder: (context, selected) => Text(selected),
            ),
            throwsAssertionError,
          );

          await boxCubit.close();
          await cubit.close();
        },
      );

      testWidgets(
        'BlocSignalListener and BlocSignalSelector fallback from explicit bloc '
        'to null in didUpdateWidget subscribes to ancestor provider swaps',
        (tester) async {
          final explicitCubit = CounterCubit();
          final providerCubit1 = CounterCubit();
          final providerCubit2 = CounterCubit();
          final listenedStates = <int>[];
          final selectedStates = <int>[];

          await tester.pumpWidget(
            MaterialApp(
              home: _FlutterFallbackHarness(
                providerCubit: providerCubit1,
                explicitCubit: explicitCubit,
                onListened: listenedStates.add,
                onSelectedBuilt: selectedStates.add,
              ),
            ),
          );

          expect(selectedStates, equals([0]));

          // Step 1: Switch explicitCubit from explicit instance to null so
          // didUpdateWidget falls back to
          // BlocSignalProvider.of(context, listen: true) while providerCubit1
          // remains unchanged.
          await tester.pumpWidget(
            MaterialApp(
              home: _FlutterFallbackHarness(
                providerCubit: providerCubit1,
                explicitCubit: null,
                onListened: listenedStates.add,
                onSelectedBuilt: selectedStates.add,
              ),
            ),
          );

          providerCubit1.increment(); // 1
          await tester.pump();
          expect(listenedStates, equals([1]));
          expect(selectedStates.last, equals(1));

          // Step 2: Swap ancestor provider from providerCubit1 to
          // providerCubit2 above a cached child so only InheritedWidget
          // dependency notification (registered during step 1's
          // didUpdateWidget) can rebind them.
          await tester.pumpWidget(
            MaterialApp(
              home: _FlutterFallbackHarness(
                providerCubit: providerCubit2,
                explicitCubit: null,
                onListened: listenedStates.add,
                onSelectedBuilt: selectedStates.add,
              ),
            ),
          );

          // Verify old disconnected cubit (providerCubit1) and explicitCubit
          // do NOT trigger listener or selector before providerCubit2 emits.
          providerCubit1.increment(); // 2 on old cubit
          explicitCubit.increment(); // 1 on explicit cubit
          await tester.pump();
          expect(listenedStates, equals([1]));
          expect(selectedStates.last, equals(0));

          // Verify new providerCubit2 triggers both listener and selector.
          providerCubit2
            ..increment() // 1
            ..increment(); // 2
          await tester.pump();
          expect(listenedStates, equals([1, 1, 2]));
          expect(selectedStates.last, equals(2));

          await explicitCubit.close();
          await providerCubit1.close();
          await providerCubit2.close();
        },
      );
    },
  );

  group(
    'Typed MultiBlocSignalProvider & MultiBlocSignalListener (Issue #331: R17)',
    () {
      testWidgets(
        'MultiBlocSignalProvider.providers is typed as '
        'List<BlocSignalProviderSingleChildWidget> and merges heterogeneous '
        'providers and custom implementations in reverse order',
        (tester) async {
          final bloc = CounterBloc();
          final cubit = CounterCubit();
          final order = <String>[];

          final providers = <BlocSignalProviderSingleChildWidget>[
            _CustomProviderSingleChildWidget(
              label: 'first',
              onCopyWith: order.add,
            ),
            BlocSignalProvider<CounterBloc>.value(value: bloc),
            BlocSignalProvider<CounterCubit>.value(value: cubit),
            _CustomProviderSingleChildWidget(
              label: 'last',
              onCopyWith: order.add,
            ),
          ];

          final multiProvider = MultiBlocSignalProvider(
            providers: providers,
            child: Builder(
              builder: (context) {
                final readBloc = context.read<CounterBloc>();
                final readCubit = context.read<CounterCubit>();
                return Text('Bloc:${readBloc.value},Cubit:${readCubit.value}');
              },
            ),
          );

          expect(
            multiProvider.providers,
            isA<List<BlocSignalProviderSingleChildWidget>>(),
          );
          expect(multiProvider.providers, hasLength(4));

          await tester.pumpWidget(MaterialApp(home: multiProvider));

          expect(order, equals(['last', 'first']));
          expect(find.text('Bloc:0,Cubit:0'), findsOneWidget);

          await bloc.close();
          await cubit.close();
        },
      );

      testWidgets(
        'MultiBlocSignalListener.listeners is typed as '
        'List<BlocSignalListenerSingleChildWidget> and merges heterogeneous '
        'listeners and custom implementations in reverse order',
        (tester) async {
          final bloc = CounterBloc();
          final labelCubit = _LabelCubit();
          final events = <String>[];
          final copyOrder = <String>[];

          final listeners = <BlocSignalListenerSingleChildWidget>[
            _CustomListenerSingleChildWidget(
              label: 'first-listener',
              onCopyWith: copyOrder.add,
            ),
            BlocSignalListener<CounterBloc, int>(
              bloc: bloc,
              listener: (context, state) => events.add('count:$state'),
            ),
            BlocSignalListener<_LabelCubit, String>(
              bloc: labelCubit,
              listener: (context, state) => events.add('label:$state'),
            ),
            _CustomListenerSingleChildWidget(
              label: 'last-listener',
              onCopyWith: copyOrder.add,
            ),
          ];

          final multiListener = MultiBlocSignalListener(
            listeners: listeners,
            child: const Text('ChildWidget'),
          );

          expect(
            multiListener.listeners,
            isA<List<BlocSignalListenerSingleChildWidget>>(),
          );
          expect(multiListener.listeners, hasLength(4));

          await tester.pumpWidget(MaterialApp(home: multiListener));

          expect(copyOrder, equals(['last-listener', 'first-listener']));
          expect(find.text('ChildWidget'), findsOneWidget);

          bloc.add(Increment());
          labelCubit.setLabel('updated');
          await tester.pump();

          expect(events, equals(['count:1', 'label:updated']));

          await bloc.close();
          await labelCubit.close();
        },
      );
    },
  );

  group('(Issue #476: Flutter Builder, Listener, Selector & Provider)', () {
    testWidgets(
      '(Issue #476: BlocSignalBuilder buildWhen receives actual previous '
      'emitted state after skipped rebuilds)',
      (tester) async {
        final cubit = CounterCubit();
        addTearDown(cubit.close);
        final pairs = <(int, int)>[];

        await tester.pumpWidget(
          MaterialApp(
            home: BlocSignalBuilder<CounterCubit, int>(
              bloc: cubit,
              buildWhen: (previous, current) {
                pairs.add((previous, current));
                return current != 1;
              },
              builder: (context, state) => Text('Count: $state'),
            ),
          ),
        );

        expect(find.text('Count: 0'), findsOneWidget);
        expect(pairs, isEmpty);

        // 0 -> 1 (buildWhen returns false, rendered state stays 0)
        cubit.emit(1);
        await tester.pump();
        expect(find.text('Count: 0'), findsOneWidget);
        expect(pairs, equals([(0, 1)]));

        // 1 -> 2 (buildWhen must receive previous == 1, not 0)
        cubit.emit(2);
        await tester.pump();
        expect(find.text('Count: 2'), findsOneWidget);
        expect(pairs, equals([(0, 1), (1, 2)]));

        // 2 -> 1 (false) -> 2 (true): buildWhen must receive (1, 2)
        cubit.emit(1);
        await tester.pump();
        expect(find.text('Count: 2'), findsOneWidget);

        cubit.emit(2);
        await tester.pump();
        expect(find.text('Count: 2'), findsOneWidget);
        expect(pairs, equals([(0, 1), (1, 2), (2, 1), (1, 2)]));
      },
    );

    testWidgets(
      '(Issue #476: Builder, Listener, and Selector suppress initial-pass '
      'callbacks with non-reflexive equals)',
      (tester) async {
        final cubit = _NonReflexiveCubit();
        addTearDown(cubit.close);
        final buildWhenPairs = <(int, int)>[];
        final listenWhenPairs = <(int, int)>[];
        final listenedStates = <int>[];
        var selectorBuildCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: BlocSignalListener<_NonReflexiveCubit, int>(
              bloc: cubit,
              listenWhen: (previous, current) {
                listenWhenPairs.add((previous, current));
                return true;
              },
              listener: (context, state) => listenedStates.add(state),
              child: Column(
                children: [
                  BlocSignalBuilder<_NonReflexiveCubit, int>(
                    bloc: cubit,
                    buildWhen: (previous, current) {
                      buildWhenPairs.add((previous, current));
                      return true;
                    },
                    builder: (context, state) => Text('Builder: $state'),
                  ),
                  BlocSignalSelector<_NonReflexiveCubit, int, int>(
                    bloc: cubit,
                    selector: (state) => state,
                    equals: (_, __) => false,
                    builder: (context, value) {
                      selectorBuildCount++;
                      return Text('Selector: $value');
                    },
                  ),
                ],
              ),
            ),
          ),
        );

        expect(buildWhenPairs, isEmpty);
        expect(listenWhenPairs, isEmpty);
        expect(listenedStates, isEmpty);
        expect(selectorBuildCount, equals(1));

        cubit.emit(1);
        await tester.pump();

        expect(buildWhenPairs, equals([(0, 1)]));
        expect(listenWhenPairs, equals([(0, 1)]));
        expect(listenedStates, equals([1]));
        expect(selectorBuildCount, equals(2));
        expect(find.text('Builder: 1'), findsOneWidget);
        expect(find.text('Selector: 1'), findsOneWidget);
      },
    );

    testWidgets(
      '(Issue #476: BlocSignalProvider.value swaps distinct value-equal '
      'containers via !identical above const subtree)',
      (tester) async {
        _issue476FlutterEvents.clear();
        addTearDown(_issue476FlutterEvents.clear);
        final c1 = _ValueEqualCubit(1);
        final c2 = _ValueEqualCubit(2);
        addTearDown(c1.close);
        addTearDown(c2.close);
        expect(c1 == c2, isTrue);
        expect(identical(c1, c2), isFalse);

        late void Function(_ValueEqualCubit) swapCubit;

        await tester.pumpWidget(
          MaterialApp(
            home: _ValueEqualSwapHost(
              initialCubit: c1,
              onCreated: (setter) => swapCubit = setter,
            ),
          ),
        );

        expect(find.text('Watch: 1'), findsOneWidget);
        expect(find.text('Builder: 1'), findsOneWidget);
        expect(find.text('Selector: 1'), findsOneWidget);
        expect(find.text('Select: 1'), findsOneWidget);

        swapCubit(c2);
        await tester.pump();

        expect(find.text('Watch: 2'), findsOneWidget);
        expect(find.text('Builder: 2'), findsOneWidget);
        expect(find.text('Selector: 2'), findsOneWidget);
        expect(find.text('Select: 2'), findsOneWidget);

        // Old cubit must be unsubscribed; new cubit must be active.
        c1.emit(99);
        c2.emit(3);
        await tester.pump();

        expect(_issue476FlutterEvents, equals([3]));
        expect(find.text('Watch: 3'), findsOneWidget);
        expect(find.text('Builder: 3'), findsOneWidget);
        expect(find.text('Selector: 3'), findsOneWidget);
        expect(find.text('Select: 3'), findsOneWidget);
      },
    );

    testWidgets(
      '(Issue #476: BlocSignalProvider didUpdateWidget handles create <-> '
      'value switches and lazy true -> false above const subtree)',
      (tester) async {
        final createdCubits = <CounterCubit>[];
        final externalCubit = CounterCubit()..emit(42);
        addTearDown(externalCubit.close);
        late void Function({
          required bool useValue,
          required bool lazy,
          bool readInLazy,
        }) updateConfig;

        await tester.pumpWidget(
          MaterialApp(
            home: _ProviderModeSwitchHost(
              externalCubit: externalCubit,
              onCreated: createdCubits.add,
              onHostReady: (setter) => updateConfig = setter,
            ),
          ),
        );

        // Initially create: with lazy: true and no reader -> not created yet.
        expect(createdCubits, isEmpty);

        // Switch lazy: true -> false while in create: mode -> eagerly creates.
        updateConfig(useValue: false, lazy: false, readInLazy: true);
        await tester.pump();
        expect(createdCubits, hasLength(1));
        final ownedCubit = createdCubits.first;
        expect(ownedCubit.isClosed, isFalse);
        expect(find.text('ConstCount: 0'), findsOneWidget);

        // Switch create: -> .value -> closes ownedCubit and exposes external.
        updateConfig(useValue: true, lazy: false, readInLazy: true);
        await tester.pump();
        expect(ownedCubit.isClosed, isTrue);
        expect(find.text('ConstCount: 42'), findsOneWidget);

        // Switch .value -> create: -> creates a new owned cubit, external stays
        // open.
        updateConfig(useValue: false, lazy: false, readInLazy: true);
        await tester.pump();
        expect(externalCubit.isClosed, isFalse);
        expect(createdCubits, hasLength(2));
        expect(find.text('ConstCount: 0'), findsOneWidget);

        await createdCubits.last.close();
      },
    );

    testWidgets(
      '(Issue #476: lazy: true create provider materialized by const '
      'dependent rebinds const descendants when switched to .value)',
      (tester) async {
        _issue476FlutterEvents.clear();
        addTearDown(_issue476FlutterEvents.clear);
        final createdCubits = <CounterCubit>[];
        final externalCubit = CounterCubit()..emit(42);
        addTearDown(externalCubit.close);
        late void Function({
          required bool useValue,
          required bool lazy,
          bool readInLazy,
        }) updateConfig;

        await tester.pumpWidget(
          MaterialApp(
            home: _ProviderModeSwitchHost(
              externalCubit: externalCubit,
              onCreated: createdCubits.add,
              onHostReady: (setter) => updateConfig = setter,
              initialReadInLazy: true,
              useFullSubtree: true,
            ),
          ),
        );

        // Frame 1: lazy: true create: materialized B1 via const dependents.
        expect(createdCubits, hasLength(1));
        final lazyBloc = createdCubits.single;
        expect(find.text('Watch: 0'), findsOneWidget);
        expect(find.text('Builder: 0'), findsOneWidget);
        expect(find.text('Selector: 0'), findsOneWidget);
        expect(find.text('Select: 0'), findsOneWidget);

        // Frame 2: switch directly from lazy: true create: to .value(42).
        updateConfig(useValue: true, lazy: false, readInLazy: true);
        await tester.pump();

        expect(lazyBloc.isClosed, isTrue);
        expect(find.text('Watch: 42'), findsOneWidget);
        expect(find.text('Builder: 42'), findsOneWidget);
        expect(find.text('Selector: 42'), findsOneWidget);
        expect(find.text('Select: 42'), findsOneWidget);

        externalCubit.emit(43);
        await tester.pump();
        expect(_issue476FlutterEvents, equals([43]));
        expect(find.text('Watch: 43'), findsOneWidget);
        expect(find.text('Builder: 43'), findsOneWidget);
        expect(find.text('Selector: 43'), findsOneWidget);
        expect(find.text('Select: 43'), findsOneWidget);
      },
    );

    testWidgets(
      '(Issue #476: Builder, Listener, and Selector suppress callbacks after '
      'unmount)',
      (tester) async {
        final cubit = CounterCubit();
        addTearDown(cubit.close);
        var buildWhenCalls = 0;
        var builderCalls = 0;
        var listenWhenCalls = 0;
        var listenerCalls = 0;
        var selectorCalls = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: BlocSignalListener<CounterCubit, int>(
              bloc: cubit,
              listenWhen: (_, __) {
                listenWhenCalls++;
                return true;
              },
              listener: (_, __) => listenerCalls++,
              child: Column(
                children: [
                  BlocSignalBuilder<CounterCubit, int>(
                    bloc: cubit,
                    buildWhen: (_, __) {
                      buildWhenCalls++;
                      return true;
                    },
                    builder: (_, state) {
                      builderCalls++;
                      return Text('B: $state');
                    },
                  ),
                  BlocSignalSelector<CounterCubit, int, int>(
                    bloc: cubit,
                    selector: (s) {
                      selectorCalls++;
                      return s;
                    },
                    builder: (_, v) => Text('S: $v'),
                  ),
                ],
              ),
            ),
          ),
        );

        final initialBuilderCalls = builderCalls;
        final initialSelectorCalls = selectorCalls;

        // Unmount the entire subtree.
        await tester.pumpWidget(const SizedBox());

        cubit.emit(10);
        await tester.pump();

        expect(buildWhenCalls, equals(0));
        expect(builderCalls, equals(initialBuilderCalls));
        expect(listenWhenCalls, equals(0));
        expect(listenerCalls, equals(0));
        expect(selectorCalls, equals(initialSelectorCalls));
      },
    );

    testWidgets(
      '(Issue #476: BlocSignalProvider lazy: false caches factory error on '
      'initState)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: BlocSignalProvider<CounterCubit>(
              lazy: false,
              create: (_) => throw StateError('eager factory boom'),
              child: const SizedBox(),
            ),
          ),
        );

        expect(tester.takeException(), isA<StateError>());
      },
    );
  });
}

class _LabelCubit extends CubitSignal<String> {
  _LabelCubit() : super(initialState: 'initial');

  void setLabel(String value) => emit(value);
}

class _CustomProviderSingleChildWidget extends StatelessWidget
    implements BlocSignalProviderSingleChildWidget {
  const _CustomProviderSingleChildWidget({
    required this.label,
    required this.onCopyWith,
    this.child = const SizedBox.shrink(),
  });

  final String label;
  final void Function(String label) onCopyWith;
  final Widget child;

  @override
  Widget copyWith(Widget child) {
    onCopyWith(label);
    return _CustomProviderSingleChildWidget(
      label: label,
      onCopyWith: onCopyWith,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) => child;
}

class _CustomListenerSingleChildWidget extends StatelessWidget
    implements BlocSignalListenerSingleChildWidget {
  const _CustomListenerSingleChildWidget({
    required this.label,
    required this.onCopyWith,
    this.child = const SizedBox.shrink(),
  });

  final String label;
  final void Function(String label) onCopyWith;
  final Widget child;

  @override
  Widget copyWith(Widget child) {
    onCopyWith(label);
    return _CustomListenerSingleChildWidget(
      label: label,
      onCopyWith: onCopyWith,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) => child;
}

@immutable
class _ValueEqualBox {
  // Intentionally non-const constructor to test distinct heap allocations with
  // identical values.
  // ignore: prefer_const_constructors_in_immutables
  _ValueEqualBox(this.label);

  final String label;

  @override
  bool operator ==(Object other) =>
      other is _ValueEqualBox && other.label == label;

  @override
  int get hashCode => label.hashCode;
}

class _IdentityBoxCubit extends CubitSignal<_ValueEqualBox> {
  _IdentityBoxCubit(_ValueEqualBox initial)
      : super(
          initialState: initial,
          equals: identical,
        );

  void emitBox(_ValueEqualBox next) => emit(next);
}

class _FlutterFallbackHarness extends StatelessWidget {
  const _FlutterFallbackHarness({
    required this.providerCubit,
    required this.explicitCubit,
    required this.onListened,
    required this.onSelectedBuilt,
  });

  final CounterCubit providerCubit;
  final CounterCubit? explicitCubit;
  final void Function(int state) onListened;
  final void Function(int state) onSelectedBuilt;

  @override
  Widget build(BuildContext context) {
    return BlocSignalProvider<CounterCubit>.value(
      value: providerCubit,
      child: _FlutterFallbackInner(
        explicitCubit: explicitCubit,
        onListened: onListened,
        onSelectedBuilt: onSelectedBuilt,
      ),
    );
  }
}

class _FlutterFallbackInner extends StatefulWidget {
  const _FlutterFallbackInner({
    required this.explicitCubit,
    required this.onListened,
    required this.onSelectedBuilt,
  });

  final CounterCubit? explicitCubit;
  final void Function(int state) onListened;
  final void Function(int state) onSelectedBuilt;

  @override
  State<_FlutterFallbackInner> createState() => _FlutterFallbackInnerState();
}

class _FlutterFallbackInnerState extends State<_FlutterFallbackInner> {
  late Widget _cachedSubtree;

  @override
  void initState() {
    super.initState();
    _cachedSubtree = _buildSubtree();
  }

  @override
  void didUpdateWidget(_FlutterFallbackInner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.explicitCubit != widget.explicitCubit) {
      _cachedSubtree = _buildSubtree();
    }
  }

  Widget _buildSubtree() {
    return BlocSignalListener<CounterCubit, int>(
      bloc: widget.explicitCubit,
      listener: (context, state) => widget.onListened(state),
      child: BlocSignalSelector<CounterCubit, int, int>(
        bloc: widget.explicitCubit,
        selector: (state) => state,
        builder: (context, value) {
          widget.onSelectedBuilt(value);
          return Text('FallbackSelected: $value');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _cachedSubtree;
  }
}

class _ConstSelectorChild extends StatelessWidget {
  const _ConstSelectorChild();

  @override
  Widget build(BuildContext context) {
    final count = context.select<CounterBloc, int>((b) => b.stateValue);
    return Text('Count: $count');
  }
}

class _ConstListenerChild extends StatelessWidget {
  const _ConstListenerChild({required this.onState});

  final void Function(int state) onState;

  @override
  Widget build(BuildContext context) {
    return BlocSignalListener<CounterCubit, int>(
      listener: (context, state) => onState(state),
      child: const Text('ConstListenerContent'),
    );
  }
}

class _NonReflexiveCubit extends CubitSignal<int> {
  _NonReflexiveCubit()
      : super(
          initialState: 0,
          equals: (_, __) => false,
        );
}

class _ValueEqualCubit extends CubitSignal<int> {
  _ValueEqualCubit(int initial) : super(initialState: initial);

  @override
  // Intentionally overrides == on a CubitSignal test double for !identical().
  // ignore: avoid_equals_and_hash_code_on_mutable_classes
  bool operator ==(Object other) => other is _ValueEqualCubit;

  @override
  // Matches custom == override on this test double.
  // ignore: avoid_equals_and_hash_code_on_mutable_classes
  int get hashCode => 0;
}

final List<int> _issue476FlutterEvents = <int>[];

class _ValueEqualSwapHost extends StatefulWidget {
  const _ValueEqualSwapHost({
    required this.initialCubit,
    required this.onCreated,
  });

  final _ValueEqualCubit initialCubit;
  final void Function(void Function(_ValueEqualCubit)) onCreated;

  @override
  State<_ValueEqualSwapHost> createState() => _ValueEqualSwapHostState();
}

class _ValueEqualSwapHostState extends State<_ValueEqualSwapHost> {
  late _ValueEqualCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = widget.initialCubit;
    widget.onCreated((next) {
      setState(() {
        _cubit = next;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocSignalProvider<_ValueEqualCubit>.value(
      value: _cubit,
      child: const _ValueEqualConstSubtree(),
    );
  }
}

class _ValueEqualConstSubtree extends StatelessWidget {
  const _ValueEqualConstSubtree();

  @override
  Widget build(BuildContext context) {
    final watched = context.watch<_ValueEqualCubit>().stateValue;
    final selected = context.select<_ValueEqualCubit, int>((b) => b.stateValue);
    return BlocSignalListener<_ValueEqualCubit, int>(
      listener: (context, state) => _issue476FlutterEvents.add(state),
      child: Column(
        children: [
          Text('Watch: $watched'),
          BlocSignalBuilder<_ValueEqualCubit, int>(
            builder: (context, state) => Text('Builder: $state'),
          ),
          BlocSignalSelector<_ValueEqualCubit, int, int>(
            selector: (state) => state,
            builder: (context, value) => Text('Selector: $value'),
          ),
          Text('Select: $selected'),
        ],
      ),
    );
  }
}

class _ProviderModeSwitchHost extends StatefulWidget {
  const _ProviderModeSwitchHost({
    required this.externalCubit,
    required this.onCreated,
    required this.onHostReady,
    this.initialReadInLazy = false,
    this.useFullSubtree = false,
  });

  final CounterCubit externalCubit;
  final void Function(CounterCubit) onCreated;
  final void Function(
    void Function({
      required bool useValue,
      required bool lazy,
      bool readInLazy,
    }),
  ) onHostReady;
  final bool initialReadInLazy;
  final bool useFullSubtree;

  @override
  State<_ProviderModeSwitchHost> createState() =>
      _ProviderModeSwitchHostState();
}

class _ProviderModeSwitchHostState extends State<_ProviderModeSwitchHost> {
  bool _useValue = false;
  bool _lazy = true;
  late bool _readInLazy = widget.initialReadInLazy;

  @override
  void initState() {
    super.initState();
    widget.onHostReady(({
      required useValue,
      required lazy,
      readInLazy = false,
    }) {
      setState(() {
        _useValue = useValue;
        _lazy = lazy;
        _readInLazy = readInLazy;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (!_readInLazy && _lazy && !_useValue) {
      child = const Text('Lazy');
    } else if (widget.useFullSubtree) {
      child = const _CounterConstFullSubtree();
    } else {
      child = const _CounterConstWatcher();
    }
    if (_useValue) {
      return BlocSignalProvider<CounterCubit>.value(
        value: widget.externalCubit,
        child: child,
      );
    }
    return BlocSignalProvider<CounterCubit>(
      lazy: _lazy,
      create: (context) {
        final c = CounterCubit();
        widget.onCreated(c);
        return c;
      },
      child: child,
    );
  }
}

class _CounterConstWatcher extends StatelessWidget {
  const _CounterConstWatcher();

  @override
  Widget build(BuildContext context) {
    final count = context.watch<CounterCubit>().stateValue;
    return Text('ConstCount: $count');
  }
}

class _CounterConstFullSubtree extends StatelessWidget {
  const _CounterConstFullSubtree();

  @override
  Widget build(BuildContext context) {
    final watched = context.watch<CounterCubit>().stateValue;
    final selected = context.select<CounterCubit, int>((b) => b.stateValue);
    return BlocSignalListener<CounterCubit, int>(
      listener: (context, state) => _issue476FlutterEvents.add(state),
      child: Column(
        children: [
          Text('Watch: $watched'),
          BlocSignalBuilder<CounterCubit, int>(
            builder: (context, state) => Text('Builder: $state'),
          ),
          BlocSignalSelector<CounterCubit, int, int>(
            selector: (state) => state,
            builder: (context, value) => Text('Selector: $value'),
          ),
          Text('Select: $selected'),
        ],
      ),
    );
  }
}
