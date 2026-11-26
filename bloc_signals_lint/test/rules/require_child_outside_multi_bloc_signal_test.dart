import 'package:bloc_signals_lint/src/rules/require_child_outside_multi_bloc_signal.dart';
import 'package:test/test.dart';

import '../src/lint_test_harness.dart';

void main() {
  tearDownAll(disposeLintTestHarness);

  group('(Issue #482) RequireChildOutsideMultiBlocSignal', () {
    test('flags BlocSignalProvider, .value, and BlocSignalListener omitting '
        'child: outside Multi*', () async {
      const badCode = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);
}

Widget buildWidgets(BuildContext context, CounterCubit cubit) {
  final a = BlocSignalProvider<CounterCubit>(
    create: (_) => CounterCubit(),
  );
  final b = BlocSignalProvider<CounterCubit>.value(
    value: cubit,
  );
  final c = BlocSignalListener<CounterCubit, int>(
    listener: (ctx, state) {},
  );
  return a;
}
''';
      final lints = await runLintRule(
        RequireChildOutsideMultiBlocSignal(),
        badCode,
      );
      expect(lints, hasLength(3));
    });

    test('allows child: outside Multi* and allows omitting child: inside '
        'MultiBlocSignalProvider / MultiBlocSignalListener', () async {
      const goodCode = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);
}

Widget buildWidgets(BuildContext context, CounterCubit cubit) {
  final single = BlocSignalProvider<CounterCubit>(
    create: (_) => CounterCubit(),
    child: Container(),
  );
  final multiProvider = MultiBlocSignalProvider(
    providers: [
      BlocSignalProvider<CounterCubit>(create: (_) => CounterCubit()),
      BlocSignalProvider<CounterCubit>.value(value: cubit),
    ],
    child: MultiBlocSignalListener(
      listeners: [
        BlocSignalListener<CounterCubit, int>(listener: (ctx, state) {}),
      ],
      child: single,
    ),
  );
  return multiProvider;
}
''';
      final lints = await runLintRule(
        RequireChildOutsideMultiBlocSignal(),
        goodCode,
      );
      expect(lints, isEmpty);
    });

    test('supports Jaspr BlocSignalProvider and BlocSignalListener', () async {
      const jasprCode = '''
import 'package:bloc_signals_jaspr/bloc_signals_jaspr.dart';

class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);
}

Component buildJaspr(BuildContext context) {
  final bad = BlocSignalProvider<CounterCubit>(
    create: (_) => CounterCubit(),
  );
  final good = MultiBlocSignalProvider(
    providers: [
      BlocSignalProvider<CounterCubit>(create: (_) => CounterCubit()),
    ],
    child: bad,
  );
  return good;
}
''';
      final lints = await runLintRule(
        RequireChildOutsideMultiBlocSignal(),
        jasprCode,
      );
      expect(lints, hasLength(1));
    });

    test('(Issue #482: NBO-1) allows collection-if, collection-for, ternary, '
        'and parenthesized elements inside Multi*', () async {
      const goodCode = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);
}

Widget buildMulti(BuildContext context, bool flag, List<int> items) {
  return MultiBlocSignalProvider(
    providers: [
      if (flag) BlocSignalProvider<CounterCubit>(create: (_) => CounterCubit()),
      for (final _ in items)
        BlocSignalProvider<CounterCubit>(create: (_) => CounterCubit()),
      flag
          ? BlocSignalProvider<CounterCubit>(create: (_) => CounterCubit())
          : (BlocSignalProvider<CounterCubit>(create: (_) => CounterCubit())),
    ],
    child: MultiBlocSignalListener(
      listeners: [
        if (flag)
          BlocSignalListener<CounterCubit, int>(listener: (ctx, state) {}),
      ],
      child: Container(),
    ),
  );
}
''';
      final lints = await runLintRule(
        RequireChildOutsideMultiBlocSignal(),
        goodCode,
      );
      expect(lints, isEmpty);
    });

    test('(Issue #482: Round 2 BLOCKER-4) allows spread-list elements inside '
        'MultiBlocSignalProvider and MultiBlocSignalListener', () async {
      const spreadCode = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);
}

Widget buildSpread(BuildContext context) {
  return MultiBlocSignalProvider(
    providers: [
      ...[
        BlocSignalProvider<CounterCubit>(create: (_) => CounterCubit()),
      ],
    ],
    child: MultiBlocSignalListener(
      listeners: [
        ...[
          BlocSignalListener<CounterCubit, int>(listener: (ctx, state) {}),
        ],
      ],
      child: Container(),
    ),
  );
}
''';
      final lints = await runLintRule(
        RequireChildOutsideMultiBlocSignal(),
        spreadCode,
      );
      expect(lints, isEmpty);
    });

    test(
      '(Issue #482: Round 2 BLOCKER-5) flags unresolved '
      'BlocSignalProvider / BlocSignalListener via rawName fallback',
      () async {
        const unresolvedCode = '''
import 'package:bloc_signals/bloc_signals.dart';

Object buildUnresolved() {
  return new BlocSignalProvider();
}
''';
        final lints = await runLintRule(
          RequireChildOutsideMultiBlocSignal(),
          unresolvedCode,
        );
        expect(lints, hasLength(1));
        expect(lints.single.lexeme, equals('BlocSignalProvider'));
      },
    );

    test('(Issue #482: Round 3 BLOCKER-4) allows conditional and parenthesized '
        'ListLiteral arguments in MultiBlocSignalProvider / '
        'MultiBlocSignalListener', () async {
      const wrappedListCode = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);
}

Widget buildWrapped(BuildContext context, bool cond) {
  return MultiBlocSignalProvider(
    providers: cond
        ? [BlocSignalProvider<CounterCubit>(create: (_) => CounterCubit())]
        : [BlocSignalProvider<CounterCubit>(create: (_) => CounterCubit())],
    child: MultiBlocSignalListener(
      listeners: ([
        BlocSignalListener<CounterCubit, int>(listener: (ctx, state) {}),
      ]),
      child: Container(),
    ),
  );
}
''';
      final lints = await runLintRule(
        RequireChildOutsideMultiBlocSignal(),
        wrappedListCode,
      );
      expect(lints, isEmpty);
    });
  });
}
