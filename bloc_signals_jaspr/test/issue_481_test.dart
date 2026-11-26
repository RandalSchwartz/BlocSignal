import 'package:bloc_signals_jaspr/bloc_signals_jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_test/jaspr_test.dart';
import 'package:signals_core/signals_core.dart';

import 'helpers/counter_cubit.dart';

class _ConstMaybeReadProbe extends StatelessComponent {
  const _ConstMaybeReadProbe();

  static int buildCount = 0;

  @override
  Component build(BuildContext context) {
    buildCount++;
    BlocSignalProvider.maybeOf<CounterCubit>(context);
    context.maybeRead<CounterCubit>();
    return const Component.empty();
  }
}

class _SwapProviderHost extends StatefulComponent {
  const _SwapProviderHost({
    required this.initialCubit,
    required this.onCreated,
    required this.child,
  });

  final CounterCubit initialCubit;
  final void Function(void Function(CounterCubit) swap) onCreated;
  final Component child;

  @override
  State<_SwapProviderHost> createState() => _SwapProviderHostState();
}

class _SwapProviderHostState extends State<_SwapProviderHost> {
  late CounterCubit _cubit = component.initialCubit;

  @override
  void initState() {
    super.initState();
    component.onCreated((next) => setState(() => _cubit = next));
  }

  @override
  Component build(BuildContext context) {
    return BlocSignalProvider<CounterCubit>.value(
      value: _cubit,
      child: component.child,
    );
  }
}

class _ComputedSpyObserver extends SignalsObserver {
  final List<int> computedHashCodes = <int>[];

  @override
  void onComputedCreated<T>(Computed<T> instance) {}

  @override
  void onComputedUpdated<T>(Computed<T> instance, T value) {
    if (value != null) {
      computedHashCodes.add(value.hashCode);
    }
  }

  @override
  void onEffectCreated(Effect instance) {}

  @override
  void onSignalCreated<T>(Signal<T> instance, T value) {}

  @override
  void onSignalUpdated<T>(Signal<T> instance, T value) {}
}

class _MissingProviderComponent extends StatelessComponent {
  const _MissingProviderComponent();

  @override
  Component build(BuildContext context) {
    BlocSignalProvider.of<CounterCubit>(context);
    return const Component.empty();
  }
}

class _MissingSelectComponent extends StatelessComponent {
  const _MissingSelectComponent(this.onError);

  final void Function(Object error) onError;

  @override
  Component build(BuildContext context) {
    try {
      context.select<CounterCubit, int>((c) => c.stateValue);
    } on Object catch (e) {
      onError(e);
    }
    return const Component.empty();
  }
}

class _MissingGenericComponent extends StatelessComponent {
  const _MissingGenericComponent(this.onError);

  final void Function(Object error) onError;

  @override
  Component build(BuildContext context) {
    try {
      BlocSignalProvider.of(context);
    } on Object catch (e) {
      onError(e);
    }
    return const Component.empty();
  }
}

void main() {
  group('Issue #481: Jaspr maybeOf / maybeRead / maybeWatch', () {
    testComponents(
      '(Issue #481: maybeOf/maybeRead/maybeWatch) returns null when absent',
      (tester) async {
        CounterCubit? fromMaybeOf;
        CounterCubit? fromMaybeOfListen;
        CounterCubit? fromMaybeRead;
        CounterCubit? fromMaybeWatch;

        tester.pumpComponent(
          Builder(
            builder: (context) {
              fromMaybeOf = BlocSignalProvider.maybeOf<CounterCubit>(context);
              fromMaybeOfListen = BlocSignalProvider.maybeOf<CounterCubit>(
                context,
                listen: true,
              );
              fromMaybeRead = context.maybeRead<CounterCubit>();
              fromMaybeWatch = context.maybeWatch<CounterCubit>();
              return const Component.empty();
            },
          ),
        );

        expect(fromMaybeOf, isNull);
        expect(fromMaybeOfListen, isNull);
        expect(fromMaybeRead, isNull);
        expect(fromMaybeWatch, isNull);
      },
    );

    testComponents(
      '(Issue #481: maybeOf/maybeRead) triggers lazy _initBloc and returns T',
      (tester) async {
        var createdCount = 0;
        CounterCubit? fromMaybeRead;
        CounterCubit? fromMaybeOf;

        tester.pumpComponent(
          BlocSignalProvider<CounterCubit>(
            create: (_) {
              createdCount++;
              return CounterCubit(initial: 42);
            },
            child: Builder(
              builder: (context) {
                expect(createdCount, 0);
                fromMaybeRead = context.maybeRead<CounterCubit>();
                fromMaybeOf = BlocSignalProvider.maybeOf<CounterCubit>(context);
                return const Component.empty();
              },
            ),
          ),
        );

        expect(createdCount, 1);
        expect(fromMaybeRead, isNotNull);
        expect(fromMaybeRead!.stateValue, 42);
        expect(identical(fromMaybeRead, fromMaybeOf), isTrue);
      },
    );

    testComponents(
      '(Issue #481: maybeWatch) rebuilds when ancestor provider swaps bloc',
      (tester) async {
        final cubitA = CounterCubit(initial: 1);
        final cubitB = CounterCubit(initial: 2);
        addTearDown(() async {
          await cubitA.close();
          await cubitB.close();
        });

        final observedValues = <int?>[];

        tester
          ..pumpComponent(
            BlocSignalProvider<CounterCubit>.value(
              value: cubitA,
              child: Builder(
                builder: (context) {
                  observedValues.add(
                    context.maybeWatch<CounterCubit>()?.stateValue,
                  );
                  return const Component.empty();
                },
              ),
            ),
          )
          ..pumpComponent(
            BlocSignalProvider<CounterCubit>.value(
              value: cubitB,
              child: Builder(
                builder: (context) {
                  observedValues.add(
                    context.maybeWatch<CounterCubit>()?.stateValue,
                  );
                  return const Component.empty();
                },
              ),
            ),
          );

        expect(observedValues, <int?>[1, 2]);
      },
    );

    testComponents(
      '(Issue #481: maybeOf(listen: false)/maybeRead) does not rebuild when '
      'ancestor provider swaps bloc',
      (tester) async {
        final cubitA = CounterCubit(initial: 1);
        final cubitB = CounterCubit(initial: 2);
        addTearDown(() async {
          await cubitA.close();
          await cubitB.close();
        });

        _ConstMaybeReadProbe.buildCount = 0;
        late void Function(CounterCubit) swapCubit;

        tester.pumpComponent(
          _SwapProviderHost(
            initialCubit: cubitA,
            onCreated: (setter) => swapCubit = setter,
            child: const _ConstMaybeReadProbe(),
          ),
        );
        expect(_ConstMaybeReadProbe.buildCount, 1);

        swapCubit(cubitB);
        await tester.pump();
        expect(_ConstMaybeReadProbe.buildCount, 1);
      },
    );
  });

  group('Issue #481: Jaspr BlocSignalProviderNotFoundError', () {
    testComponents(
      '(Issue #481: ProviderNotFoundError) extends StateError, names T and '
      'caller component, and includes Builder/Navigator hints',
      (tester) async {
        Object? caught;
        tester.pumpComponent(
          Builder(
            builder: (context) {
              try {
                const _MissingProviderComponent().build(context);
              } on Object catch (e) {
                caught = e;
              }
              return const Component.empty();
            },
          ),
        );

        expect(caught, isA<StateError>());
        expect(caught, isA<BlocSignalProviderNotFoundError<CounterCubit>>());
        final message = caught.toString();
        expect(message, contains('CounterCubit'));
        expect(message, contains('Builder'));
        expect(message, contains('Navigator'));
        expect(message, contains('.value'));
      },
    );

    testComponents(
      '(Issue #481: ProviderNotFoundError) names Element caller component '
      'runtimeType and warns on BlocSignalBase<dynamic>',
      (tester) async {
        Object? genericError;
        tester.pumpComponent(
          Builder(
            builder: (context) {
              try {
                BlocSignalProvider.of(context);
              } on Object catch (e) {
                genericError = e;
              }
              return const Component.empty();
            },
          ),
        );

        expect(
          genericError,
          isA<BlocSignalProviderNotFoundError<BlocSignalBase<dynamic>>>(),
        );
        expect(genericError.toString(), contains('BlocSignalBase<dynamic>'));
        expect(genericError.toString(), contains('Builder'));

        Object? elementGenericError;
        tester.pumpComponent(
          _MissingGenericComponent((e) => elementGenericError = e),
        );
        expect(
          elementGenericError,
          isA<BlocSignalProviderNotFoundError<BlocSignalBase<dynamic>>>()
              .having(
            (e) => e.toString(),
            'toString()',
            contains('_MissingGenericComponent'),
          ),
        );
      },
    );

    testComponents(
      '(Issue #481: context.select) throws BlocSignalProviderNotFoundError<T>',
      (tester) async {
        Object? selectError;
        tester.pumpComponent(
          _MissingSelectComponent((e) => selectError = e),
        );
        expect(
          selectError,
          isA<BlocSignalProviderNotFoundError<CounterCubit>>().having(
            (e) => e.toString(),
            'toString()',
            contains('_MissingSelectComponent'),
          ),
        );
      },
    );
  });

  group('Issue #481: Jaspr Listener.transition & Consumer.transition', () {
    testComponents(
      '(Issue #481: Listener.transition) delivers (context, previous, current),'
      ' respects listenWhen, and preserves listener getter',
      (tester) async {
        final cubit = CounterCubit(initial: 10);
        addTearDown(cubit.close);

        final transitions = <(int, int)>[];
        BuildContext? capturedContext;

        final listenerComponent =
            BlocSignalListener<CounterCubit, int>.transition(
          bloc: cubit,
          listenWhen: (previous, current) => current.isEven,
          listener: (context, previous, current) {
            transitions.add((previous, current));
          },
          child: Builder(
            builder: (context) {
              capturedContext = context;
              return const div([Component.text('child')]);
            },
          ),
        );

        tester.pumpComponent(listenerComponent);

        cubit
          ..increment() // 10 -> 11 (filtered)
          ..increment() // 11 -> 12 (delivered)
          ..increment() // 12 -> 13 (filtered)
          ..increment(); // 13 -> 14 (delivered)

        expect(transitions, <(int, int)>[(11, 12), (13, 14)]);

        // Non-nullable public listener getter compatibility.
        listenerComponent.listener(capturedContext!, 99);
        expect(transitions.last, (99, 99));

        // copyWith preserves transition listener.
        final copied = listenerComponent.copyWith(
          const div([Component.text('copied')]),
        );
        tester.pumpComponent(copied);
        cubit
          ..increment() // 14 -> 15 (filtered)
          ..increment(); // 15 -> 16 (delivered)
        expect(find.text('copied'), findsOneComponent);
        expect(transitions.last, (15, 16));
      },
    );

    testComponents(
      '(Issue #481: Consumer.transition) delivers (context, previous, current),'
      ' respects listenWhen/buildWhen, and preserves listener getter',
      (tester) async {
        final cubit = CounterCubit();
        addTearDown(cubit.close);

        final transitions = <(int, int)>[];
        BuildContext? capturedContext;

        final consumer = BlocSignalConsumer<CounterCubit, int>.transition(
          bloc: cubit,
          listenWhen: (previous, current) => current > previous,
          buildWhen: (previous, current) => current.isOdd,
          listener: (context, previous, current) {
            transitions.add((previous, current));
          },
          builder: (context, state) {
            capturedContext = context;
            return div([Component.text('count:$state')]);
          },
        );

        tester.pumpComponent(consumer);
        expect(find.text('count:0'), findsOneComponent);

        cubit.increment(); // 0 -> 1
        await tester.pump();
        expect(find.text('count:1'), findsOneComponent);
        expect(transitions, <(int, int)>[(0, 1)]);

        cubit.emit(0); // 1 -> 0 (filtered)
        await tester.pump();
        expect(find.text('count:1'), findsOneComponent);
        expect(transitions, <(int, int)>[(0, 1)]);

        // Non-nullable public listener getter compatibility.
        consumer.listener(capturedContext!, 42);
        expect(transitions.last, (42, 42));
      },
    );
  });

  group('Issue #481: Jaspr context.select equals, Computed, & unmount gate',
      () {
    testComponents(
      '(Issue #481: context.select equals) suppresses rebuilds when custom '
      'equals returns true, reinitializes on equals change, and memoizes',
      (tester) async {
        final cubit = CounterCubit();
        addTearDown(cubit.close);

        var buildCount = 0;
        var useDecadeEquals = true;

        Component buildTree() {
          return BlocSignalProvider<CounterCubit>.value(
            value: cubit,
            child: Builder(
              builder: (context) {
                buildCount++;
                final selected = context.select<CounterCubit, int>(
                  (c) => c.stateValue,
                  equals: useDecadeEquals
                      ? (prev, next) => prev ~/ 10 == next ~/ 10
                      : (prev, next) => prev == next,
                );
                return div([Component.text('sel:$selected')]);
              },
            ),
          );
        }

        tester.pumpComponent(buildTree());
        expect(buildCount, 1);
        expect(find.text('sel:0'), findsOneComponent);

        cubit.emit(5);
        await tester.pump();
        expect(buildCount, 1);

        cubit.emit(10);
        await tester.pump();
        expect(buildCount, 2);
        expect(find.text('sel:10'), findsOneComponent);

        useDecadeEquals = false;
        tester.pumpComponent(buildTree());
        expect(buildCount, 3);

        cubit.emit(11);
        await tester.pump();
        expect(buildCount, 4);
        expect(find.text('sel:11'), findsOneComponent);
      },
    );

    testComponents(
      '(Issue #481: SCAR-JASPR-01) unmounted context.select does not evaluate '
      'Computed selector on subsequent state emission',
      (tester) async {
        final cubit = CounterCubit();
        addTearDown(cubit.close);

        var selectorCalls = 0;
        var showChild = true;

        Component buildTree() {
          return BlocSignalProvider<CounterCubit>.value(
            value: cubit,
            child: showChild
                ? Builder(
                    builder: (context) {
                      final val = context.select<CounterCubit, int>((c) {
                        selectorCalls++;
                        return c.stateValue;
                      });
                      return div([Component.text('v:$val')]);
                    },
                  )
                : const div([Component.text('empty')]),
          );
        }

        tester.pumpComponent(buildTree());
        expect(selectorCalls, 1);

        showChild = false;
        tester.pumpComponent(buildTree());
        await tester.pump();

        // After unmount, state emissions must not evaluate Computed selector.
        cubit.increment();
        await tester.pump();
        expect(selectorCalls, 1);
      },
    );

    testComponents(
      '(Issue #481: context.select reactivity) tracks auxiliary signals and '
      'absorbs dirty Computed updates',
      (tester) async {
        final cubit = CounterCubit(initial: 1);
        final multiplier = signal<int>(10);
        addTearDown(() async {
          await cubit.close();
          multiplier.dispose();
        });

        var buildCount = 0;

        tester.pumpComponent(
          BlocSignalProvider<CounterCubit>.value(
            value: cubit,
            child: Builder(
              builder: (context) {
                buildCount++;
                // Read both bloc state (parity) and an auxiliary Signal.
                final selected = context.select<CounterCubit, int>(
                  (c) => (c.stateValue.isEven ? 2 : 1) * multiplier.value,
                );
                return div([Component.text('res:$selected')]);
              },
            ),
          ),
        );

        expect(buildCount, 1);
        expect(find.text('res:10'), findsOneComponent);

        // Unrelated state change (1 -> 3: still odd) is absorbed by Computed.
        cubit.emit(3);
        await tester.pump();
        expect(buildCount, 1);

        // Auxiliary signal update triggers rebuild even without bloc emission.
        multiplier.value = 20;
        await tester.pump();
        expect(buildCount, 2);
        expect(find.text('res:20'), findsOneComponent);

        // Relevant bloc state change (3 -> 4: odd -> even) triggers rebuild.
        cubit.emit(4);
        await tester.pump();
        expect(buildCount, 3);
        expect(find.text('res:40'), findsOneComponent);
      },
    );

    testComponents(
      '(Issue #481: _SelectorSlot.hashCode) exercises slot hashCode via '
      'SignalsObserver',
      (tester) async {
        final cubit = CounterCubit();
        addTearDown(cubit.close);

        final previousObserver = SignalsObserver.instance;
        final spy = _ComputedSpyObserver();
        SignalsObserver.instance = spy;
        addTearDown(() => SignalsObserver.instance = previousObserver);

        tester.pumpComponent(
          BlocSignalProvider<CounterCubit>.value(
            value: cubit,
            child: Builder(
              builder: (context) {
                final val = context.select<CounterCubit, int>(
                  (c) => c.stateValue,
                  equals: (prev, next) => prev == next,
                );
                return div([Component.text('slot:$val')]);
              },
            ),
          ),
        );

        cubit.increment();
        await tester.pump();
        expect(spy.computedHashCodes, isNotEmpty);
      },
    );

    testComponents(
      '(Issue #481: _NullComponent removal) default child is Component.empty()',
      (tester) async {
        final cubit = CounterCubit();
        addTearDown(cubit.close);

        final provider = BlocSignalProvider<CounterCubit>.value(value: cubit);
        final listener = BlocSignalListener<CounterCubit, int>(
          bloc: cubit,
          listener: (context, state) {},
        );

        expect(identical(provider.child, const Component.empty()), isTrue);
        expect(identical(listener.child, const Component.empty()), isTrue);
      },
    );
  });
}
