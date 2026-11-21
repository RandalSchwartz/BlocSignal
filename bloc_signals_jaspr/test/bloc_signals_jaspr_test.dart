import 'package:bloc_signals_jaspr/bloc_signals_jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_test/jaspr_test.dart';
import 'package:signals_core/signals_core.dart';

import 'helpers/counter_cubit.dart';

void main() {
  group('BlocSignalProvider & Jaspr components', () {
    testComponents('provides BlocSignal and renders child', (tester) async {
      tester.pumpComponent(
        BlocSignalProvider<CounterCubit>(
          create: (context) => CounterCubit(),
          child: Builder(
            builder: (context) {
              final c = context.read<CounterCubit>();
              return div([Component.text('Count: ${c.stateValue}')]);
            },
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneComponent);
    });

    testComponents('eager provider initializes on initState', (tester) async {
      var isCreated = false;

      tester.pumpComponent(
        BlocSignalProvider<CounterCubit>(
          lazy: false,
          create: (context) {
            isCreated = true;
            return CounterCubit();
          },
          child: const div([Component.text('Eager')]),
        ),
      );

      expect(isCreated, isTrue);
      expect(find.text('Eager'), findsOneComponent);
    });

    testComponents('throws StateError when provider of type T is not found',
        (tester) async {
      tester.pumpComponent(
        Builder(
          builder: (context) {
            expect(
              () => context.read<CounterCubit>(),
              throwsA(isA<StateError>()),
            );
            return const div([Component.text('ErrorTest')]);
          },
        ),
      );
    });

    testComponents('context.watch listens to provider dependency',
        (tester) async {
      final cubit = CounterCubit();

      tester.pumpComponent(
        BlocSignalProvider<CounterCubit>.value(
          value: cubit,
          child: Builder(
            builder: (context) {
              final c = context.watch<CounterCubit>();
              return div([Component.text('Watch: ${c.stateValue}')]);
            },
          ),
        ),
      );

      expect(find.text('Watch: 0'), findsOneComponent);
    });

    testComponents('context.select listens to selected state slice',
        (tester) async {
      final cubit = CounterCubit();
      var buildCount = 0;

      tester.pumpComponent(
        BlocSignalProvider<CounterCubit>.value(
          value: cubit,
          child: Builder(
            builder: (context) {
              buildCount++;
              final isPositive = context.select<CounterCubit, bool>(
                (c) => c.stateValue > 0,
              );
              return div([Component.text('Positive: $isPositive')]);
            },
          ),
        ),
      );

      expect(find.text('Positive: false'), findsOneComponent);
      expect(buildCount, 1);

      cubit.increment(); // 1 (isPositive becomes true)
      await tester.pump();

      expect(find.text('Positive: true'), findsOneComponent);
      expect(buildCount, 2);
    });

    testComponents('BlocSignalBuilder rebuilds component on state change',
        (tester) async {
      final cubit = CounterCubit();

      tester.pumpComponent(
        BlocSignalProvider<CounterCubit>.value(
          value: cubit,
          child: BlocSignalBuilder<CounterCubit, int>(
            builder: (context, state) {
              return div([Component.text('State: $state')]);
            },
          ),
        ),
      );

      expect(find.text('State: 0'), findsOneComponent);

      cubit.increment();
      await tester.pump();

      expect(find.text('State: 1'), findsOneComponent);
    });

    testComponents('BlocSignalListener triggers callback on state change',
        (tester) async {
      final cubit = CounterCubit();
      final states = <int>[];

      tester.pumpComponent(
        BlocSignalProvider<CounterCubit>.value(
          value: cubit,
          child: BlocSignalListener<CounterCubit, int>(
            listener: (context, state) {
              states.add(state);
            },
            listenWhen: (prev, curr) => curr.isEven,
            child: const div([Component.text('Child')]),
          ),
        ),
      );

      expect(states, isEmpty);

      cubit.increment(); // 1 (odd -> listenWhen false)
      await tester.pump();
      expect(states, isEmpty);

      cubit.increment(); // 2 (even -> listenWhen true)
      await tester.pump();
      expect(states, [2]);
    });

    testComponents('BlocSignalConsumer combines builder and listener',
        (tester) async {
      final cubit = CounterCubit();
      final states = <int>[];

      tester.pumpComponent(
        BlocSignalProvider<CounterCubit>.value(
          value: cubit,
          child: BlocSignalConsumer<CounterCubit, int>(
            listener: (context, state) {
              states.add(state);
            },
            builder: (context, state) {
              return div([Component.text('Count: $state')]);
            },
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneComponent);
      expect(states, isEmpty);

      cubit.increment();
      await tester.pump();

      expect(find.text('Count: 1'), findsOneComponent);
      expect(states, [1]);
    });

    testComponents(
        'BlocSignalSelector rebuilds only when selector value changes',
        (tester) async {
      final cubit = CounterCubit();
      var buildCount = 0;

      tester.pumpComponent(
        BlocSignalProvider<CounterCubit>.value(
          value: cubit,
          child: BlocSignalSelector<CounterCubit, int, bool>(
            selector: (state) => state > 5,
            builder: (context, isGreaterThanFive) {
              buildCount++;
              return div([Component.text('Is > 5: $isGreaterThanFive')]);
            },
          ),
        ),
      );

      expect(find.text('Is > 5: false'), findsOneComponent);
      expect(buildCount, 1);

      cubit.increment(); // 1
      await tester.pump();
      expect(buildCount, 1);

      for (var i = 0; i < 5; i++) {
        cubit.increment();
      }
      await tester.pump();

      expect(find.text('Is > 5: true'), findsOneComponent);
      expect(buildCount, 2);
    });

    testComponents('MultiBlocSignalProvider provides multiple blocs',
        (tester) async {
      final counterCubit = CounterCubit();
      final themeCubit = ThemeCubit();

      tester.pumpComponent(
        MultiBlocSignalProvider(
          providers: [
            BlocSignalProvider<CounterCubit>.value(value: counterCubit),
            BlocSignalProvider<ThemeCubit>.value(value: themeCubit),
          ],
          child: Builder(
            builder: (context) {
              final counter = context.read<CounterCubit>();
              final theme = context.read<ThemeCubit>();
              return div([
                Component.text('${theme.stateValue}:${counter.stateValue}'),
              ]);
            },
          ),
        ),
      );

      expect(find.text('light:0'), findsOneComponent);
    });

    testComponents('MultiBlocSignalListener runs multiple listeners',
        (tester) async {
      final counterCubit = CounterCubit();
      final themeCubit = ThemeCubit();
      final events = <String>[];

      tester.pumpComponent(
        MultiBlocSignalProvider(
          providers: [
            BlocSignalProvider<CounterCubit>.value(value: counterCubit),
            BlocSignalProvider<ThemeCubit>.value(value: themeCubit),
          ],
          child: MultiBlocSignalListener(
            listeners: [
              BlocSignalListener<CounterCubit, int>(
                listener: (context, state) => events.add('counter:$state'),
              ),
              BlocSignalListener<ThemeCubit, String>(
                listener: (context, state) => events.add('theme:$state'),
              ),
            ],
            child: const div([Component.text('MultiListenerChild')]),
          ),
        ),
      );

      counterCubit.increment();
      themeCubit.toggle();
      await tester.pump();

      expect(events, containsAll(['counter:1', 'theme:dark']));
    });

    testComponents(
      'context.select transfers subscription when provider bloc instance '
      'is swapped above const subtree',
      (tester) async {
        final cubit1 = CounterCubit();
        final cubit2 = CounterCubit();
        late _JasprSwapProviderState swapState;

        tester.pumpComponent(
          _JasprSwapProvider(
            initialCubit: cubit1,
            onCreated: (state) => swapState = state,
          ),
        );
        expect(find.text('Count: 0'), findsOneComponent);

        // Swap provider to cubit2 via stateful component
        swapState.setCubit(cubit2);
        await tester.pump();
        expect(find.text('Count: 0'), findsOneComponent);

        // State changes on cubit2 should trigger rebuild
        cubit2.increment();
        await tester.pump();
        expect(find.text('Count: 1'), findsOneComponent);

        await cubit1.close();
        await cubit2.close();
      },
    );

    testComponents(
      'context.value<T, S>() rebuilds component on state emission',
      (tester) async {
        final cubit = CounterCubit();
        var buildCount = 0;

        tester.pumpComponent(
          BlocSignalProvider<CounterCubit>.value(
            value: cubit,
            child: Builder(
              builder: (context) {
                buildCount++;
                final count = context.value<CounterCubit, int>();
                return div([Component.text('ValueCount: $count')]);
              },
            ),
          ),
        );

        expect(find.text('ValueCount: 0'), findsOneComponent);
        expect(buildCount, 1);

        cubit.increment();
        await tester.pump();

        expect(find.text('ValueCount: 1'), findsOneComponent);
        expect(buildCount, 2);

        await cubit.close();
      },
    );

    testComponents(
      'context.state<T, S>() returns ReadonlySignal without rebuilding context',
      (tester) async {
        final cubit = CounterCubit();
        var buildCount = 0;
        late Computed<String> derivedSummary;

        tester.pumpComponent(
          BlocSignalProvider<CounterCubit>.value(
            value: cubit,
            child: Builder(
              builder: (context) {
                buildCount++;
                final stateSignal = context.state<CounterCubit, int>();
                derivedSummary =
                    computed(() => 'Computed: ${stateSignal.value}');
                return const div([Component.text('StaticUI')]);
              },
            ),
          ),
        );

        expect(buildCount, 1);
        expect(derivedSummary.value, 'Computed: 0');

        cubit.increment();
        await tester.pump();

        // context.state must NOT trigger an element rebuild on context
        expect(buildCount, 1);
        // But the computed signal reacts synchronously
        expect(derivedSummary.value, 'Computed: 1');

        await cubit.close();
      },
    );

    testComponents(
      'BlocSignalListener rebinds when ancestor provider instance is swapped '
      'above const component',
      (tester) async {
        final cubit1 = CounterCubit();
        final cubit2 = CounterCubit();
        final states = <int>[];
        late _JasprSwapListenerProviderState swapState;

        tester.pumpComponent(
          _JasprSwapListenerProvider(
            initialCubit: cubit1,
            onCreated: (state) => swapState = state,
            onState: states.add,
          ),
        );

        cubit1.increment(); // 1
        await tester.pump();
        expect(states, equals([1]));

        // Swap provider to cubit2 via stateful component above const child
        swapState.setCubit(cubit2);
        await tester.pump();

        // cubit2 emissions should be received by listener
        cubit2.increment(); // 1
        await tester.pump();
        expect(states, equals([1, 1]));

        // cubit1 is disconnected; emissions should not be received
        cubit1.increment(); // 2
        await tester.pump();
        expect(states, equals([1, 1]));

        await cubit1.close();
        await cubit2.close();
      },
    );

    testComponents(
      'BlocSignalConsumer rebinds when ancestor provider instance is swapped '
      'above const component',
      (tester) async {
        final cubit1 = CounterCubit();
        final cubit2 = CounterCubit();
        final listenedStates = <int>[];
        late _JasprSwapConsumerProviderState swapState;

        tester.pumpComponent(
          _JasprSwapConsumerProvider(
            initialCubit: cubit1,
            onCreated: (state) => swapState = state,
            onState: listenedStates.add,
          ),
        );

        expect(find.text('ConsumerCount: 0'), findsOneComponent);

        cubit1.increment(); // 1
        await tester.pump();
        expect(find.text('ConsumerCount: 1'), findsOneComponent);
        expect(listenedStates, equals([1]));

        // Swap provider to cubit2 (starts at 0)
        swapState.setCubit(cubit2);
        await tester.pump();
        expect(find.text('ConsumerCount: 0'), findsOneComponent);

        // cubit2 emissions should be received by consumer builder and listener
        cubit2.increment(); // 1
        await tester.pump();
        expect(find.text('ConsumerCount: 1'), findsOneComponent);
        expect(listenedStates, equals([1, 1]));

        // cubit1 is now disconnected; emissions should not be received
        cubit1.increment(); // 2
        await tester.pump();
        expect(find.text('ConsumerCount: 1'), findsOneComponent);
        expect(listenedStates, equals([1, 1]));

        await cubit1.close();
        await cubit2.close();
      },
    );

    testComponents(
      'BlocSignalBuilder respects buildWhen predicate',
      (tester) async {
        final cubit = CounterCubit();
        var buildCount = 0;

        tester.pumpComponent(
          BlocSignalBuilder<CounterCubit, int>(
            bloc: cubit,
            buildWhen: (previous, current) => current.isEven,
            builder: (context, state) {
              buildCount++;
              return div([Component.text('State: $state')]);
            },
          ),
        );

        expect(find.text('State: 0'), findsOneComponent);
        expect(buildCount, equals(1));

        cubit.increment(); // 1 (odd) -> buildWhen returns false
        await tester.pump();
        expect(find.text('State: 0'), findsOneComponent);
        expect(buildCount, equals(1));

        cubit.increment(); // 2 (even) -> buildWhen returns true
        await tester.pump();
        expect(find.text('State: 2'), findsOneComponent);
        expect(buildCount, equals(2));

        await cubit.close();
      },
    );

    testComponents(
      'BlocSignalConsumer respects buildWhen and listenWhen predicates',
      (tester) async {
        final cubit = CounterCubit();
        final listenedStates = <int>[];
        var buildCount = 0;

        tester.pumpComponent(
          BlocSignalConsumer<CounterCubit, int>(
            bloc: cubit,
            buildWhen: (previous, current) => current.isEven,
            listenWhen: (previous, current) => current > 1,
            listener: (context, state) => listenedStates.add(state),
            builder: (context, state) {
              buildCount++;
              return div([Component.text('Count: $state')]);
            },
          ),
        );

        expect(find.text('Count: 0'), findsOneComponent);
        expect(buildCount, equals(1));

        cubit.increment(); // 1: buildWhen false, listenWhen false
        await tester.pump();
        expect(find.text('Count: 0'), findsOneComponent);
        expect(buildCount, equals(1));
        expect(listenedStates, isEmpty);

        cubit.increment(); // 2: buildWhen true, listenWhen true
        await tester.pump();
        expect(find.text('Count: 2'), findsOneComponent);
        expect(buildCount, equals(2));
        expect(listenedStates, equals([2]));

        await cubit.close();
      },
    );

    testComponents(
      'MultiBlocSignalProvider accepts typed list with different generic types',
      (tester) async {
        late CounterCubit cubit;
        late ThemeCubit themeCubit;

        tester.pumpComponent(
          MultiBlocSignalProvider(
            providers: [
              BlocSignalProvider<CounterCubit>(
                create: (context) => cubit = CounterCubit(),
              ),
              BlocSignalProvider<ThemeCubit>(
                create: (context) => themeCubit = ThemeCubit(),
              ),
            ],
            child: Builder(
              builder: (context) {
                final retrievedCubit = context.read<CounterCubit>();
                final retrievedTheme = context.read<ThemeCubit>();
                expect(retrievedCubit, equals(cubit));
                expect(retrievedTheme, equals(themeCubit));
                return const div([Component.text('MultiSuccess')]);
              },
            ),
          ),
        );

        expect(find.text('MultiSuccess'), findsOneComponent);
      },
    );

    testComponents(
      'MultiBlocSignalListener executes multiple listeners in list literal',
      (tester) async {
        final counterCubit = CounterCubit();
        final themeCubit = ThemeCubit();
        final counterStates = <int>[];
        final themeStates = <String>[];

        tester.pumpComponent(
          MultiBlocSignalListener(
            listeners: [
              BlocSignalListener<CounterCubit, int>(
                bloc: counterCubit,
                listener: (context, state) => counterStates.add(state),
              ),
              BlocSignalListener<ThemeCubit, String>(
                bloc: themeCubit,
                listener: (context, state) => themeStates.add(state),
              ),
            ],
            child: const div([Component.text('MultiListener')]),
          ),
        );

        counterCubit.increment();
        themeCubit.toggle();
        await tester.pump();

        expect(counterStates, equals([1]));
        expect(themeStates, equals(['dark']));

        await counterCubit.close();
        await themeCubit.close();
      },
    );
  });

  group(
    'Issue #320: R6 — Custom equals/equalityCheck and didUpdate fallback '
    'listen: true',
    () {
      testComponents(
        'BlocSignalBuilder and BlocSignalListener respect custom equals '
        '(identical) when state operator == returns true for distinct '
        'instances',
        (tester) async {
          final initial = _JasprValueEqualBox('alpha');
          final cubit = _JasprIdentityBoxCubit(initial);
          var buildCount = 0;
          final builderStates = <_JasprValueEqualBox>[];
          final listenerStates = <_JasprValueEqualBox>[];

          tester.pumpComponent(
            BlocSignalProvider<_JasprIdentityBoxCubit>.value(
              value: cubit,
              child: BlocSignalListener<_JasprIdentityBoxCubit,
                  _JasprValueEqualBox>(
                listener: (context, state) {
                  listenerStates.add(state);
                },
                child: BlocSignalBuilder<_JasprIdentityBoxCubit,
                    _JasprValueEqualBox>(
                  builder: (context, state) {
                    buildCount++;
                    builderStates.add(state);
                    return div([Component.text('Box: ${state.label}')]);
                  },
                ),
              ),
            ),
          );

          expect(buildCount, equals(1));
          expect(identical(builderStates.last, initial), isTrue);
          expect(listenerStates, isEmpty);

          final next = _JasprValueEqualBox('alpha');
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

      testComponents(
        'BlocSignalSelector respects SignalOptions equalityCheck, equals '
        'comparator, Computed memoization, and re-initializes computed when '
        'options or equals changes',
        (tester) async {
          final cubit = _JasprIdentityBoxCubit(_JasprValueEqualBox('alpha'));
          var buildCount = 0;
          var selectorCallCount = 0;
          final selectedValues = <String>[];
          late _JasprSelectorOptionsHostState hostState;
          var watchedACount = 0;
          var watchedBCount = 0;

          bool caseInsensitiveEquals(String a, String b) =>
              a.toLowerCase() == b.toLowerCase();

          final optionsA = SignalOptions<String>(
            name: 'JasprSelectorOptionsA',
            watched: () => watchedACount++,
            equality: SignalEquality<String>.custom(caseInsensitiveEquals),
          );

          tester.pumpComponent(
            _JasprSelectorOptionsHost(
              cubit: cubit,
              initialOptions: optionsA,
              onCreated: (state) => hostState = state,
              onSelectorCalled: () => selectorCallCount++,
              onBuilt: (selectedLabel) {
                buildCount++;
                selectedValues.add(selectedLabel);
              },
            ),
          );

          expect(buildCount, equals(1));
          expect(watchedACount, equals(1));
          expect(selectorCallCount, equals(1));
          expect(selectedValues, equals(['alpha']));

          // Emitting a state whose projected value is equal under
          // SignalOptions.equalityCheck ('alpha' vs 'ALPHA') evaluates
          // selector once inside Computed and suppresses component rebuild.
          cubit.emitBox(_JasprValueEqualBox('ALPHA'));
          await tester.pump();

          expect(selectorCallCount, equals(2));
          expect(buildCount, equals(1));
          expect(selectedValues, equals(['alpha']));

          // Emitting a state whose projected value is NOT equal ('beta')
          // triggers a single selector evaluation and rebuilds the component.
          cubit.emitBox(_JasprValueEqualBox('beta'));
          await tester.pump();

          expect(selectorCallCount, equals(3));
          expect(buildCount, equals(2));
          expect(selectedValues, equals(['alpha', 'beta']));

          // Update options and provide explicit equals via didUpdateComponent
          // and verify _initComputed() re-initializes the computed signal.
          final optionsB = ComputedOptions<String>(
            name: 'JasprSelectorOptionsB',
            watched: () => watchedBCount++,
          );
          bool exactEquals(String a, String b) => a == b;

          hostState.setOptionsAndEquals(optionsB, exactEquals);
          await tester.pump();
          expect(watchedBCount, equals(1));
          expect(buildCount, equals(3));

          // With exactEquals, 'BETA' != 'beta' so it rebuilds.
          cubit.emitBox(_JasprValueEqualBox('BETA'));
          await tester.pump();
          expect(buildCount, equals(4));
          expect(selectedValues.last, equals('BETA'));

          // Update only equals parameter via didUpdateComponent (keeping
          // optionsB identical) to verify oldComponent.equals !=
          // component.equals triggers _initComputed().
          hostState.setOptionsAndEquals(optionsB, caseInsensitiveEquals);
          await tester.pump();
          expect(buildCount, equals(5));

          // Now case-insensitive 'beta' matches 'BETA', suppressing rebuild.
          cubit.emitBox(_JasprValueEqualBox('beta'));
          await tester.pump();
          expect(buildCount, equals(5));

          // Also support ReadonlySignalOptions<V> directly.
          var watchedCCount = 0;
          final optionsC = ReadonlySignalOptions<String>(
            name: 'JasprSelectorOptionsC',
            watched: () => watchedCCount++,
          );
          hostState.setOptionsAndEquals(optionsC, caseInsensitiveEquals);
          await tester.pump();
          expect(watchedCCount, equals(1));
          expect(buildCount, equals(6));

          // Verify stricter-than-`==` custom equality (for example `identical`
          // when `V.operator ==` returns true for distinct instances) triggers
          // rebuilds both via `equals: identical` and via
          // `SignalOptions(equality: SignalEquality.identical())`.
          final box1 = _JasprValueEqualBox('same');
          final box2 = _JasprValueEqualBox('same');
          final box3 = _JasprValueEqualBox('same');
          expect(box1 == box2, isTrue);
          expect(identical(box1, box2), isFalse);
          expect(box2 == box3, isTrue);
          expect(identical(box2, box3), isFalse);

          final boxCubit1 = _JasprIdentityBoxCubit(box1);
          var boxBuildCount = 0;
          final selectedBoxes = <_JasprValueEqualBox>[];

          tester.pumpComponent(
            BlocSignalProvider<_JasprIdentityBoxCubit>.value(
              value: boxCubit1,
              child: BlocSignalSelector<_JasprIdentityBoxCubit,
                  _JasprValueEqualBox, _JasprValueEqualBox>(
                selector: (state) => state,
                equals: identical,
                builder: (context, selectedBox) {
                  boxBuildCount++;
                  selectedBoxes.add(selectedBox);
                  return div([Component.text('Box: ${selectedBox.label}')]);
                },
              ),
            ),
          );

          expect(boxBuildCount, equals(1));
          expect(identical(selectedBoxes.last, box1), isTrue);

          boxCubit1.emitBox(box2);
          await tester.pump();
          expect(boxBuildCount, equals(2));
          expect(identical(selectedBoxes.last, box2), isTrue);
          await boxCubit1.close();

          final boxCubit2 = _JasprIdentityBoxCubit(box2);
          tester.pumpComponent(
            BlocSignalProvider<_JasprIdentityBoxCubit>.value(
              value: boxCubit2,
              child: BlocSignalSelector<_JasprIdentityBoxCubit,
                  _JasprValueEqualBox, _JasprValueEqualBox>(
                selector: (state) => state,
                options: SignalOptions<_JasprValueEqualBox>(
                  equality:
                      SignalEquality<_JasprValueEqualBox>.custom(identical),
                ),
                builder: (context, selectedBox) {
                  boxBuildCount++;
                  selectedBoxes.add(selectedBox);
                  return div([Component.text('Box: ${selectedBox.label}')]);
                },
              ),
            ),
          );

          expect(boxBuildCount, equals(3));

          boxCubit2.emitBox(box3);
          await tester.pump();
          expect(boxBuildCount, equals(4));
          expect(identical(selectedBoxes.last, box3), isTrue);

          // Verify constructor assertion rejects unsupported options types.
          expect(
            () => BlocSignalSelector<_JasprIdentityBoxCubit,
                _JasprValueEqualBox, String>(
              selector: (state) => state.label,
              options: 'invalid',
              builder: (context, selected) => div([Component.text(selected)]),
            ),
            throwsAssertionError,
          );

          await boxCubit2.close();
          await cubit.close();
        },
      );

      testComponents(
        'BlocSignalListener and BlocSignalSelector fallback from explicit bloc '
        'to null in didUpdateComponent subscribes to ancestor provider swaps',
        (tester) async {
          final explicitCubit = CounterCubit();
          final providerCubit1 = CounterCubit();
          final providerCubit2 = CounterCubit();
          final listenedStates = <int>[];
          final selectedStates = <int>[];
          late _JasprFallbackHarnessState harnessState;

          tester.pumpComponent(
            _JasprFallbackHarness(
              initialProviderCubit: providerCubit1,
              initialExplicitCubit: explicitCubit,
              onCreated: (state) => harnessState = state,
              onListened: listenedStates.add,
              onSelectedBuilt: selectedStates.add,
            ),
          );

          expect(selectedStates, equals([0]));

          // Step 1: Switch explicitCubit from explicit instance to null so
          // didUpdateComponent falls back to
          // BlocSignalProvider.of(context, listen: true) while providerCubit1
          // remains unchanged.
          harnessState.clearExplicitCubit();
          await tester.pump();

          providerCubit1.increment(); // 1
          await tester.pump();
          expect(listenedStates, equals([1]));
          expect(selectedStates.last, equals(1));

          // Step 2: Swap ancestor provider from providerCubit1 to
          // providerCubit2 while keeping the inner subtree cached so only
          // InheritedComponent dependency notification (registered during
          // step 1's didUpdateComponent) can rebind them.
          harnessState.swapProviderCubit(providerCubit2);
          await tester.pump();

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
      testComponents(
        'MultiBlocSignalProvider.providers is typed as '
        'List<BlocSignalProviderSingleChildComponent> (with '
        'BlocSignalProviderSingleChildWidget alias) and merges heterogeneous '
        'providers and custom implementations in reverse order',
        (tester) async {
          final counterCubit = CounterCubit();
          final themeCubit = ThemeCubit();
          final copyOrder = <String>[];

          final providers = <BlocSignalProviderSingleChildComponent>[
            _CustomJasprProviderSingleChildComponent(
              label: 'first-provider',
              onCopyWith: copyOrder.add,
            ),
            BlocSignalProvider<CounterCubit>.value(value: counterCubit),
            BlocSignalProvider<ThemeCubit>.value(value: themeCubit),
            _CustomJasprProviderSingleChildComponent(
              label: 'last-provider',
              onCopyWith: copyOrder.add,
            ),
          ];

          final widgetAliasProviders = <BlocSignalProviderSingleChildWidget>[
            ...providers,
          ];
          expect(
            providers,
            isA<List<BlocSignalProviderSingleChildWidget>>(),
          );

          final multiProvider = MultiBlocSignalProvider(
            providers: widgetAliasProviders,
            child: Builder(
              builder: (context) {
                final readCounter = context.read<CounterCubit>();
                final readTheme = context.read<ThemeCubit>();
                return div([
                  Component.text(
                    'Counter:${readCounter.value},Theme:${readTheme.value}',
                  ),
                ]);
              },
            ),
          );

          expect(
            multiProvider.providers,
            isA<List<BlocSignalProviderSingleChildComponent>>(),
          );
          expect(multiProvider.providers, hasLength(4));

          tester.pumpComponent(multiProvider);

          expect(copyOrder, equals(['last-provider', 'first-provider']));
          expect(find.text('Counter:0,Theme:light'), findsOneComponent);

          await counterCubit.close();
          await themeCubit.close();
        },
      );

      testComponents(
        'MultiBlocSignalListener.listeners is typed as '
        'List<BlocSignalListenerSingleChildComponent> (with '
        'BlocSignalListenerSingleChildWidget alias) and merges heterogeneous '
        'listeners and custom implementations in reverse order',
        (tester) async {
          final counterCubit = CounterCubit();
          final themeCubit = ThemeCubit();
          final events = <String>[];
          final copyOrder = <String>[];

          final listeners = <BlocSignalListenerSingleChildComponent>[
            _CustomJasprListenerSingleChildComponent(
              label: 'first-listener',
              onCopyWith: copyOrder.add,
            ),
            BlocSignalListener<CounterCubit, int>(
              bloc: counterCubit,
              listener: (context, state) => events.add('counter:$state'),
            ),
            BlocSignalListener<ThemeCubit, String>(
              bloc: themeCubit,
              listener: (context, state) => events.add('theme:$state'),
            ),
            _CustomJasprListenerSingleChildComponent(
              label: 'last-listener',
              onCopyWith: copyOrder.add,
            ),
          ];

          final widgetAliasListeners = <BlocSignalListenerSingleChildWidget>[
            ...listeners,
          ];
          expect(
            listeners,
            isA<List<BlocSignalListenerSingleChildWidget>>(),
          );

          final multiListener = MultiBlocSignalListener(
            listeners: widgetAliasListeners,
            child: const div([Component.text('JasprChild')]),
          );

          expect(
            multiListener.listeners,
            isA<List<BlocSignalListenerSingleChildComponent>>(),
          );
          expect(multiListener.listeners, hasLength(4));

          tester.pumpComponent(multiListener);

          expect(copyOrder, equals(['last-listener', 'first-listener']));
          expect(find.text('JasprChild'), findsOneComponent);

          counterCubit.increment();
          themeCubit.toggle();
          await tester.pump();

          expect(events, equals(['counter:1', 'theme:dark']));

          await counterCubit.close();
          await themeCubit.close();
        },
      );
    },
  );

  group('(Issue #476: Jaspr Builder, Listener, Selector & Provider)', () {
    testComponents(
      '(Issue #476: BlocSignalBuilder buildWhen receives actual previous '
      'emitted state after skipped rebuilds)',
      (tester) async {
        final cubit = CounterCubit();
        addTearDown(cubit.close);
        final pairs = <(int, int)>[];

        tester.pumpComponent(
          BlocSignalBuilder<CounterCubit, int>(
            bloc: cubit,
            buildWhen: (previous, current) {
              pairs.add((previous, current));
              return current != 1;
            },
            builder: (context, state) => div([Component.text('Count: $state')]),
          ),
        );

        expect(find.text('Count: 0'), findsOneComponent);
        expect(pairs, isEmpty);

        cubit.emit(1);
        await tester.pump();
        expect(find.text('Count: 0'), findsOneComponent);
        expect(pairs, equals([(0, 1)]));

        cubit.emit(2);
        await tester.pump();
        expect(find.text('Count: 2'), findsOneComponent);
        expect(pairs, equals([(0, 1), (1, 2)]));

        cubit.emit(1);
        await tester.pump();
        expect(find.text('Count: 2'), findsOneComponent);

        cubit.emit(2);
        await tester.pump();
        expect(find.text('Count: 2'), findsOneComponent);
        expect(pairs, equals([(0, 1), (1, 2), (2, 1), (1, 2)]));
      },
    );

    testComponents(
      '(Issue #476: Builder, Listener, and Selector suppress initial-pass '
      'callbacks with non-reflexive equals)',
      (tester) async {
        final cubit = _NonReflexiveJasprCubit();
        addTearDown(cubit.close);
        final buildWhenPairs = <(int, int)>[];
        final listenWhenPairs = <(int, int)>[];
        final listenedStates = <int>[];
        var selectorBuildCount = 0;

        tester.pumpComponent(
          BlocSignalListener<_NonReflexiveJasprCubit, int>(
            bloc: cubit,
            listenWhen: (previous, current) {
              listenWhenPairs.add((previous, current));
              return true;
            },
            listener: (context, state) => listenedStates.add(state),
            child: div([
              BlocSignalBuilder<_NonReflexiveJasprCubit, int>(
                bloc: cubit,
                buildWhen: (previous, current) {
                  buildWhenPairs.add((previous, current));
                  return true;
                },
                builder: (context, state) =>
                    div([Component.text('Builder: $state')]),
              ),
              BlocSignalSelector<_NonReflexiveJasprCubit, int, int>(
                bloc: cubit,
                selector: (state) => state,
                equals: (_, __) => false,
                builder: (context, value) {
                  selectorBuildCount++;
                  return div([Component.text('Selector: $value')]);
                },
              ),
            ]),
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
        expect(find.text('Builder: 1'), findsOneComponent);
        expect(find.text('Selector: 1'), findsOneComponent);
      },
    );

    testComponents(
      '(Issue #476: BlocSignalProvider.value swaps distinct value-equal '
      'containers via !identical above const subtree)',
      (tester) async {
        _issue476JasprEvents.clear();
        addTearDown(_issue476JasprEvents.clear);
        final c1 = _ValueEqualJasprCubit(1);
        final c2 = _ValueEqualJasprCubit(2);
        addTearDown(c1.close);
        addTearDown(c2.close);
        expect(c1 == c2, isTrue);
        expect(identical(c1, c2), isFalse);

        late void Function(_ValueEqualJasprCubit) swapCubit;

        tester.pumpComponent(
          _ValueEqualJasprSwapHost(
            initialCubit: c1,
            onCreated: (setter) => swapCubit = setter,
          ),
        );

        expect(find.text('Watch: 1'), findsOneComponent);
        expect(find.text('Builder: 1'), findsOneComponent);
        expect(find.text('Selector: 1'), findsOneComponent);
        expect(find.text('Select: 1'), findsOneComponent);

        swapCubit(c2);
        await tester.pump();

        expect(find.text('Watch: 2'), findsOneComponent);
        expect(find.text('Builder: 2'), findsOneComponent);
        expect(find.text('Selector: 2'), findsOneComponent);
        expect(find.text('Select: 2'), findsOneComponent);

        c1.emit(99);
        c2.emit(3);
        await tester.pump();

        expect(_issue476JasprEvents, equals([3]));
        expect(find.text('Watch: 3'), findsOneComponent);
        expect(find.text('Builder: 3'), findsOneComponent);
        expect(find.text('Selector: 3'), findsOneComponent);
        expect(find.text('Select: 3'), findsOneComponent);
      },
    );

    testComponents(
      '(Issue #476: BlocSignalProvider didUpdateComponent handles create <-> '
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

        tester.pumpComponent(
          _ProviderModeSwitchJasprHost(
            externalCubit: externalCubit,
            onCreated: createdCubits.add,
            onHostReady: (setter) => updateConfig = setter,
          ),
        );

        expect(createdCubits, isEmpty);

        updateConfig(useValue: false, lazy: false, readInLazy: true);
        await tester.pump();
        expect(createdCubits, hasLength(1));
        final ownedCubit = createdCubits.first;
        expect(ownedCubit.isClosed, isFalse);
        expect(find.text('ConstCount: 0'), findsOneComponent);

        updateConfig(useValue: true, lazy: false, readInLazy: true);
        await tester.pump();
        expect(ownedCubit.isClosed, isTrue);
        expect(find.text('ConstCount: 42'), findsOneComponent);

        updateConfig(useValue: false, lazy: false, readInLazy: true);
        await tester.pump();
        expect(externalCubit.isClosed, isFalse);
        expect(createdCubits, hasLength(2));
        expect(find.text('ConstCount: 0'), findsOneComponent);

        await createdCubits.last.close();
      },
    );

    testComponents(
      '(Issue #476: lazy: true create provider materialized by const '
      'dependent rebinds const descendants when switched to .value)',
      (tester) async {
        _issue476JasprEvents.clear();
        addTearDown(_issue476JasprEvents.clear);
        final createdCubits = <CounterCubit>[];
        final externalCubit = CounterCubit()..emit(42);
        addTearDown(externalCubit.close);
        late void Function({
          required bool useValue,
          required bool lazy,
          bool readInLazy,
        }) updateConfig;

        tester.pumpComponent(
          _ProviderModeSwitchJasprHost(
            externalCubit: externalCubit,
            onCreated: createdCubits.add,
            onHostReady: (setter) => updateConfig = setter,
            initialReadInLazy: true,
            useFullSubtree: true,
          ),
        );

        expect(createdCubits, hasLength(1));
        final lazyBloc = createdCubits.single;
        expect(find.text('Watch: 0'), findsOneComponent);
        expect(find.text('Builder: 0'), findsOneComponent);
        expect(find.text('Selector: 0'), findsOneComponent);
        expect(find.text('Select: 0'), findsOneComponent);

        updateConfig(useValue: true, lazy: false, readInLazy: true);
        await tester.pump();

        expect(lazyBloc.isClosed, isTrue);
        expect(find.text('Watch: 42'), findsOneComponent);
        expect(find.text('Builder: 42'), findsOneComponent);
        expect(find.text('Selector: 42'), findsOneComponent);
        expect(find.text('Select: 42'), findsOneComponent);

        externalCubit.emit(43);
        await tester.pump();
        expect(_issue476JasprEvents, equals([43]));
        expect(find.text('Watch: 43'), findsOneComponent);
        expect(find.text('Builder: 43'), findsOneComponent);
        expect(find.text('Selector: 43'), findsOneComponent);
        expect(find.text('Select: 43'), findsOneComponent);
      },
    );

    testComponents(
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

        void Function()? unmountSubtree;

        tester.pumpComponent(
          _UnmountJasprHost(
            onReady: (unmount) => unmountSubtree = unmount,
            child: BlocSignalListener<CounterCubit, int>(
              bloc: cubit,
              listenWhen: (_, __) {
                listenWhenCalls++;
                return true;
              },
              listener: (_, __) => listenerCalls++,
              child: div([
                BlocSignalBuilder<CounterCubit, int>(
                  bloc: cubit,
                  buildWhen: (_, __) {
                    buildWhenCalls++;
                    return true;
                  },
                  builder: (_, state) {
                    builderCalls++;
                    return div([Component.text('B: $state')]);
                  },
                ),
                BlocSignalSelector<CounterCubit, int, int>(
                  bloc: cubit,
                  selector: (state) {
                    selectorCalls++;
                    return state;
                  },
                  builder: (_, v) => div([Component.text('S: $v')]),
                ),
              ]),
            ),
          ),
        );

        final initialBuilderCalls = builderCalls;
        final initialSelectorCalls = selectorCalls;

        // Unmount the entire component subtree via host state change.
        unmountSubtree!();
        await tester.pump();

        cubit.emit(10);
        await tester.pump();

        expect(buildWhenCalls, equals(0));
        expect(builderCalls, equals(initialBuilderCalls));
        expect(listenWhenCalls, equals(0));
        expect(listenerCalls, equals(0));
        expect(selectorCalls, equals(initialSelectorCalls));
      },
    );
  });
}

class _CustomJasprProviderSingleChildComponent extends StatelessComponent
    implements BlocSignalProviderSingleChildComponent {
  const _CustomJasprProviderSingleChildComponent({
    required this.label,
    required this.onCopyWith,
    this.child = const Component.empty(),
  });

  final String label;
  final void Function(String label) onCopyWith;
  final Component child;

  @override
  Component copyWith(Component child) {
    onCopyWith(label);
    return _CustomJasprProviderSingleChildComponent(
      label: label,
      onCopyWith: onCopyWith,
      child: child,
    );
  }

  @override
  Component build(BuildContext context) => child;
}

class _CustomJasprListenerSingleChildComponent extends StatelessComponent
    implements BlocSignalListenerSingleChildWidget {
  const _CustomJasprListenerSingleChildComponent({
    required this.label,
    required this.onCopyWith,
    this.child = const Component.empty(),
  });

  final String label;
  final void Function(String label) onCopyWith;
  final Component child;

  @override
  Component copyWith(Component child) {
    onCopyWith(label);
    return _CustomJasprListenerSingleChildComponent(
      label: label,
      onCopyWith: onCopyWith,
      child: child,
    );
  }

  @override
  Component build(BuildContext context) => child;
}

@immutable
class _JasprValueEqualBox {
  // Intentionally non-const constructor to test distinct heap allocations with
  // identical values.
  // ignore: prefer_const_constructors_in_immutables
  _JasprValueEqualBox(this.label);

  final String label;

  @override
  bool operator ==(Object other) =>
      other is _JasprValueEqualBox && other.label == label;

  @override
  int get hashCode => label.hashCode;
}

class _JasprIdentityBoxCubit extends CubitSignal<_JasprValueEqualBox> {
  _JasprIdentityBoxCubit(_JasprValueEqualBox initial)
      : super(
          initialState: initial,
          equals: identical,
        );

  void emitBox(_JasprValueEqualBox next) => emit(next);
}

class _JasprSelectorOptionsHost extends StatefulComponent {
  const _JasprSelectorOptionsHost({
    required this.cubit,
    required this.initialOptions,
    required this.onCreated,
    required this.onSelectorCalled,
    required this.onBuilt,
  });

  final _JasprIdentityBoxCubit cubit;
  final BlocSignalSelectorOptions<String> initialOptions;
  final void Function(_JasprSelectorOptionsHostState state) onCreated;
  final void Function() onSelectorCalled;
  final void Function(String selectedLabel) onBuilt;

  @override
  State<_JasprSelectorOptionsHost> createState() =>
      _JasprSelectorOptionsHostState();
}

class _JasprSelectorOptionsHostState extends State<_JasprSelectorOptionsHost> {
  late BlocSignalSelectorOptions<String> _options;
  bool Function(String previous, String current)? _equals;

  @override
  void initState() {
    super.initState();
    _options = component.initialOptions;
    component.onCreated(this);
  }

  void setOptionsAndEquals(
    BlocSignalSelectorOptions<String> nextOptions,
    bool Function(String previous, String current)? nextEquals,
  ) {
    setState(() {
      _options = nextOptions;
      _equals = nextEquals;
    });
  }

  String _labelSelector(_JasprValueEqualBox state) {
    component.onSelectorCalled();
    return state.label;
  }

  @override
  Component build(BuildContext context) {
    return BlocSignalProvider<_JasprIdentityBoxCubit>.value(
      value: component.cubit,
      child: BlocSignalSelector<_JasprIdentityBoxCubit, _JasprValueEqualBox,
          String>(
        selector: _labelSelector,
        options: _options,
        equals: _equals,
        builder: (context, selected) {
          component.onBuilt(selected);
          return div([Component.text('Selected: $selected')]);
        },
      ),
    );
  }
}

class _JasprFallbackHarness extends StatefulComponent {
  const _JasprFallbackHarness({
    required this.initialProviderCubit,
    required this.initialExplicitCubit,
    required this.onCreated,
    required this.onListened,
    required this.onSelectedBuilt,
  });

  final CounterCubit initialProviderCubit;
  final CounterCubit? initialExplicitCubit;
  final void Function(_JasprFallbackHarnessState state) onCreated;
  final void Function(int state) onListened;
  final void Function(int state) onSelectedBuilt;

  @override
  State<_JasprFallbackHarness> createState() => _JasprFallbackHarnessState();
}

class _JasprFallbackHarnessState extends State<_JasprFallbackHarness> {
  late CounterCubit _providerCubit;
  CounterCubit? _explicitCubit;
  late Component _cachedSubtree;

  @override
  void initState() {
    super.initState();
    _providerCubit = component.initialProviderCubit;
    _explicitCubit = component.initialExplicitCubit;
    _cachedSubtree = _buildSubtree();
    component.onCreated(this);
  }

  void clearExplicitCubit() {
    setState(() {
      _explicitCubit = null;
      _cachedSubtree = _buildSubtree();
    });
  }

  void swapProviderCubit(CounterCubit nextProviderCubit) {
    setState(() {
      _providerCubit = nextProviderCubit;
      // Intentionally do NOT rebuild _cachedSubtree so that didUpdateComponent
      // is NOT called during step 2; only InheritedComponent dependency
      // notification from step 1's didUpdateComponent can trigger
      // didChangeDependencies!
    });
  }

  Component _buildSubtree() {
    return BlocSignalListener<CounterCubit, int>(
      bloc: _explicitCubit,
      listener: (context, state) => component.onListened(state),
      child: BlocSignalSelector<CounterCubit, int, int>(
        bloc: _explicitCubit,
        selector: (state) => state,
        builder: (context, value) {
          component.onSelectedBuilt(value);
          return div([Component.text('FallbackSelected: $value')]);
        },
      ),
    );
  }

  @override
  Component build(BuildContext context) {
    return BlocSignalProvider<CounterCubit>.value(
      value: _providerCubit,
      child: _cachedSubtree,
    );
  }
}

class _JasprSwapProvider extends StatefulComponent {
  const _JasprSwapProvider({
    required this.initialCubit,
    required this.onCreated,
  });

  final CounterCubit initialCubit;
  final void Function(_JasprSwapProviderState state) onCreated;

  @override
  State<_JasprSwapProvider> createState() => _JasprSwapProviderState();
}

class _JasprSwapProviderState extends State<_JasprSwapProvider> {
  late CounterCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = component.initialCubit;
    component.onCreated(this);
  }

  void setCubit(CounterCubit newCubit) {
    setState(() {
      _cubit = newCubit;
    });
  }

  @override
  Component build(BuildContext context) {
    return BlocSignalProvider<CounterCubit>.value(
      value: _cubit,
      child: const _ConstSelectComponent(),
    );
  }
}

class _ConstSelectComponent extends StatelessComponent {
  const _ConstSelectComponent();

  @override
  Component build(BuildContext context) {
    final count = context.select<CounterCubit, int>((c) => c.stateValue);
    return div([Component.text('Count: $count')]);
  }
}

class _JasprSwapListenerProvider extends StatefulComponent {
  const _JasprSwapListenerProvider({
    required this.initialCubit,
    required this.onCreated,
    required this.onState,
  });

  final CounterCubit initialCubit;
  final void Function(_JasprSwapListenerProviderState state) onCreated;
  final void Function(int state) onState;

  @override
  State<_JasprSwapListenerProvider> createState() =>
      _JasprSwapListenerProviderState();
}

class _JasprSwapListenerProviderState
    extends State<_JasprSwapListenerProvider> {
  late CounterCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = component.initialCubit;
    component.onCreated(this);
  }

  void setCubit(CounterCubit newCubit) {
    setState(() {
      _cubit = newCubit;
    });
  }

  @override
  Component build(BuildContext context) {
    return BlocSignalProvider<CounterCubit>.value(
      value: _cubit,
      child: _ConstListenerComponent(onState: component.onState),
    );
  }
}

class _ConstListenerComponent extends StatelessComponent {
  const _ConstListenerComponent({required this.onState});

  final void Function(int state) onState;

  @override
  Component build(BuildContext context) {
    return BlocSignalListener<CounterCubit, int>(
      listener: (context, state) => onState(state),
      child: const div([Component.text('ConstListener')]),
    );
  }
}

class _JasprSwapConsumerProvider extends StatefulComponent {
  const _JasprSwapConsumerProvider({
    required this.initialCubit,
    required this.onCreated,
    required this.onState,
  });

  final CounterCubit initialCubit;
  final void Function(_JasprSwapConsumerProviderState state) onCreated;
  final void Function(int state) onState;

  @override
  State<_JasprSwapConsumerProvider> createState() =>
      _JasprSwapConsumerProviderState();
}

class _JasprSwapConsumerProviderState
    extends State<_JasprSwapConsumerProvider> {
  late CounterCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = component.initialCubit;
    component.onCreated(this);
  }

  void setCubit(CounterCubit newCubit) {
    setState(() {
      _cubit = newCubit;
    });
  }

  @override
  Component build(BuildContext context) {
    return BlocSignalProvider<CounterCubit>.value(
      value: _cubit,
      child: _ConstConsumerComponent(onState: component.onState),
    );
  }
}

class _ConstConsumerComponent extends StatelessComponent {
  const _ConstConsumerComponent({required this.onState});

  final void Function(int state) onState;

  @override
  Component build(BuildContext context) {
    return BlocSignalConsumer<CounterCubit, int>(
      listener: (context, state) => onState(state),
      builder: (context, state) =>
          div([Component.text('ConsumerCount: $state')]),
    );
  }
}

class _NonReflexiveJasprCubit extends CubitSignal<int> {
  _NonReflexiveJasprCubit()
      : super(
          initialState: 0,
          equals: (_, __) => false,
        );
}

class _ValueEqualJasprCubit extends CubitSignal<int> {
  _ValueEqualJasprCubit(int initial) : super(initialState: initial);

  @override
  // Intentionally overrides == on a CubitSignal test double for !identical().
  // ignore: avoid_equals_and_hash_code_on_mutable_classes
  bool operator ==(Object other) => other is _ValueEqualJasprCubit;

  @override
  // Matches custom == override on this test double.
  // ignore: avoid_equals_and_hash_code_on_mutable_classes
  int get hashCode => 0;
}

final List<int> _issue476JasprEvents = <int>[];

class _ValueEqualJasprSwapHost extends StatefulComponent {
  const _ValueEqualJasprSwapHost({
    required this.initialCubit,
    required this.onCreated,
  });

  final _ValueEqualJasprCubit initialCubit;
  final void Function(void Function(_ValueEqualJasprCubit)) onCreated;

  @override
  State<_ValueEqualJasprSwapHost> createState() =>
      _ValueEqualJasprSwapHostState();
}

class _ValueEqualJasprSwapHostState extends State<_ValueEqualJasprSwapHost> {
  late _ValueEqualJasprCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = component.initialCubit;
    component.onCreated((next) {
      setState(() {
        _cubit = next;
      });
    });
  }

  @override
  Component build(BuildContext context) {
    return BlocSignalProvider<_ValueEqualJasprCubit>.value(
      value: _cubit,
      child: const _ValueEqualJasprConstSubtree(),
    );
  }
}

class _ValueEqualJasprConstSubtree extends StatelessComponent {
  const _ValueEqualJasprConstSubtree();

  @override
  Component build(BuildContext context) {
    final watched = context.watch<_ValueEqualJasprCubit>().stateValue;
    final selected =
        context.select<_ValueEqualJasprCubit, int>((bloc) => bloc.stateValue);
    return BlocSignalListener<_ValueEqualJasprCubit, int>(
      listener: (context, state) => _issue476JasprEvents.add(state),
      child: div([
        div([Component.text('Watch: $watched')]),
        BlocSignalBuilder<_ValueEqualJasprCubit, int>(
          builder: (context, state) => div([Component.text('Builder: $state')]),
        ),
        BlocSignalSelector<_ValueEqualJasprCubit, int, int>(
          selector: (state) => state,
          builder: (context, value) =>
              div([Component.text('Selector: $value')]),
        ),
        div([Component.text('Select: $selected')]),
      ]),
    );
  }
}

class _ProviderModeSwitchJasprHost extends StatefulComponent {
  const _ProviderModeSwitchJasprHost({
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
  State<_ProviderModeSwitchJasprHost> createState() =>
      _ProviderModeSwitchJasprHostState();
}

class _ProviderModeSwitchJasprHostState
    extends State<_ProviderModeSwitchJasprHost> {
  bool _useValue = false;
  bool _lazy = true;
  late bool _readInLazy = component.initialReadInLazy;

  @override
  void initState() {
    super.initState();
    component.onHostReady(({
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
  Component build(BuildContext context) {
    final Component child;
    if (!_readInLazy && _lazy && !_useValue) {
      child = const div([Component.text('Lazy')]);
    } else if (component.useFullSubtree) {
      child = const _CounterJasprConstFullSubtree();
    } else {
      child = const _CounterJasprConstWatcher();
    }
    if (_useValue) {
      return BlocSignalProvider<CounterCubit>.value(
        value: component.externalCubit,
        child: child,
      );
    }
    return BlocSignalProvider<CounterCubit>(
      lazy: _lazy,
      create: (context) {
        final c = CounterCubit();
        component.onCreated(c);
        return c;
      },
      child: child,
    );
  }
}

class _CounterJasprConstWatcher extends StatelessComponent {
  const _CounterJasprConstWatcher();

  @override
  Component build(BuildContext context) {
    final count = context.watch<CounterCubit>().stateValue;
    return div([Component.text('ConstCount: $count')]);
  }
}

class _CounterJasprConstFullSubtree extends StatelessComponent {
  const _CounterJasprConstFullSubtree();

  @override
  Component build(BuildContext context) {
    final watched = context.watch<CounterCubit>().stateValue;
    final selected =
        context.select<CounterCubit, int>((bloc) => bloc.stateValue);
    return BlocSignalListener<CounterCubit, int>(
      listener: (context, state) => _issue476JasprEvents.add(state),
      child: div([
        div([Component.text('Watch: $watched')]),
        BlocSignalBuilder<CounterCubit, int>(
          builder: (context, state) => div([Component.text('Builder: $state')]),
        ),
        BlocSignalSelector<CounterCubit, int, int>(
          selector: (state) => state,
          builder: (context, value) =>
              div([Component.text('Selector: $value')]),
        ),
        div([Component.text('Select: $selected')]),
      ]),
    );
  }
}

class _UnmountJasprHost extends StatefulComponent {
  const _UnmountJasprHost({
    required this.onReady,
    required this.child,
  });

  final void Function(void Function()) onReady;
  final Component child;

  @override
  State<_UnmountJasprHost> createState() => _UnmountJasprHostState();
}

class _UnmountJasprHostState extends State<_UnmountJasprHost> {
  bool _mounted = true;

  @override
  void initState() {
    super.initState();
    component.onReady(() {
      setState(() {
        _mounted = false;
      });
    });
  }

  @override
  Component build(BuildContext context) {
    return _mounted ? component.child : const div([]);
  }
}
