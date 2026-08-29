import 'package:bloc_signals_jaspr/bloc_signals_jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_test/jaspr_test.dart';

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
  });
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
