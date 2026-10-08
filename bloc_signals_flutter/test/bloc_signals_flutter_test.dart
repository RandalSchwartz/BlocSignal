import 'dart:async';

import 'package:bloc_signals_flutter/bloc_signals_flutter.dart';
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
