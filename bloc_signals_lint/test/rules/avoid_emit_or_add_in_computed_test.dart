import 'package:analyzer/error/error.dart';
import 'package:bloc_signals_lint/src/rules/avoid_emit_or_add_in_computed.dart';
import 'package:test/test.dart';

import '../src/lint_test_harness.dart';

void main() {
  tearDownAll(disposeLintTestHarness);

  group('(Issue #500) AvoidEmitOrAddInComputed', () {
    test('rule metadata is properly configured with ERROR severity', () {
      final rule = AvoidEmitOrAddInComputed();
      expect(
        rule.diagnosticCode.lowerCaseName,
        equals('avoid_emit_or_add_in_computed'),
      );
      expect(rule.diagnosticCode.severity, equals(DiagnosticSeverity.ERROR));
      expect(rule.diagnosticCode.problemMessage, contains('computed()'));
      expect(rule.diagnosticCode.correctionMessage, isNotNull);
    });

    test('flags unqualified emit() inside computed() in CubitSignal', () async {
      const badCode = '''
import 'package:bloc_signals/bloc_signals.dart';

class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  late final doubled = computed(() {
    emit(stateValue * 2);
    return stateValue * 2;
  });
}
''';
      final diagnostics = await runLintRule(
        AvoidEmitOrAddInComputed(),
        badCode,
      );
      expect(diagnostics, hasLength(1));
      expect(diagnostics.first.lexeme, equals('emit'));
    });

    test('flags unqualified add() inside computed() in BlocSignal', () async {
      const badCode = '''
import 'package:bloc_signals/bloc_signals.dart';

sealed class CounterEvent {}
class Increment extends CounterEvent {}

class CounterBloc extends BlocSignal<CounterEvent, int> {
  CounterBloc() : super(initialState: 0);

  late final derived = computed(() {
    add(Increment());
    return stateValue;
  });
}
''';
      final diagnostics = await runLintRule(
        AvoidEmitOrAddInComputed(),
        badCode,
      );
      expect(diagnostics, hasLength(1));
      expect(diagnostics.first.lexeme, equals('add'));
    });

    test(
      'flags qualified cubit.emit() and bloc.add() inside top-level computed()',
      () async {
        const badCode = '''
import 'package:bloc_signals/bloc_signals.dart';

sealed class CounterEvent {}
class Increment extends CounterEvent {}

class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);
}

class CounterBloc extends BlocSignal<CounterEvent, int> {
  CounterBloc() : super(initialState: 0);
}

void setup(CounterCubit cubit, CounterBloc bloc) {
  final derived = computed(() {
    cubit.emit(1);
    bloc.add(Increment());
    return cubit.stateValue + bloc.stateValue;
  });
}
''';
        final diagnostics = await runLintRule(
          AvoidEmitOrAddInComputed(),
          badCode,
        );
        expect(diagnostics, hasLength(2));
      },
    );

    test(
      'flags emit() inside CubitSignalMixin and BlocSignalMixin computed()',
      () async {
        const badCode = '''
import 'package:bloc_signals/bloc_signals.dart';

mixin MyCubitMixin on CubitSignal<int> {
  late final derived = computed(() {
    this.emit(1);
    return value;
  });
}
''';
        final diagnostics = await runLintRule(
          AvoidEmitOrAddInComputed(),
          badCode,
        );
        expect(diagnostics, hasLength(1));
      },
    );

    test(
      'does not flag List.add() or unrelated emit() inside computed()',
      () async {
        const goodCode = '''
import 'package:bloc_signals/bloc_signals.dart';

class CustomEmitter {
  void emit(int v) {}
  void add(int v) {}
}

class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  final CustomEmitter custom = CustomEmitter();

  late final items = computed(() {
    final list = <int>[];
    list.add(stateValue);
    custom.emit(stateValue);
    custom.add(stateValue);
    return list;
  });
}
''';
        final diagnostics = await runLintRule(
          AvoidEmitOrAddInComputed(),
          goodCode,
        );
        expect(diagnostics, isEmpty);
      },
    );

    test(
      'does not flag emit() or add() in normal methods or effect()',
      () async {
        const goodCode = '''
import 'package:bloc_signals/bloc_signals.dart';

sealed class CounterEvent {}
class Increment extends CounterEvent {}

class CounterBloc extends BlocSignal<CounterEvent, int> {
  CounterBloc() : super(initialState: 0);

  void trigger() {
    add(Increment());
    effect(() {
      emit(stateValue + 1);
    });
  }
}
''';
        final diagnostics = await runLintRule(
          AvoidEmitOrAddInComputed(),
          goodCode,
        );
        expect(diagnostics, isEmpty);
      },
    );

    test(
      'ignores top-level emit() in computed() and emit() outside computed()',
      () async {
        const goodCode = '''
import 'package:bloc_signals/bloc_signals.dart';

class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);
}

void emit(int v) {}

void topLevel(CounterCubit cubit) {
  cubit.emit(1);
  computed(() {
    emit(1);
    return 1;
  });
}
''';
        final diagnostics = await runLintRule(
          AvoidEmitOrAddInComputed(),
          goodCode,
        );
        expect(diagnostics, isEmpty);
      },
    );

    test(
      'does not flag custom add() on CubitSignal inside computed()',
      () async {
        const goodCode = '''
import 'package:bloc_signals/bloc_signals.dart';

class CustomCubit extends CubitSignal<int> {
  CustomCubit() : super(initialState: 0);
  void add(int item) {}
}

void run(CustomCubit cubit) {
  computed(() {
    cubit.add(42);
    return cubit.stateValue;
  });
}
''';
        final diagnostics = await runLintRule(
          AvoidEmitOrAddInComputed(),
          goodCode,
        );
        expect(diagnostics, isEmpty);
      },
    );

    test('flags CubitSignalMixin and BlocSignalMixin class/mixin hosts '
        '(self, qualified, and cascade)', () async {
      const badCode = '''
import 'package:bloc_signals/bloc_signals.dart';

sealed class CounterEvent {}
class Increment extends CounterEvent {}

class MixedCubit with CubitSignalMixin<int> {
  MixedCubit() {
    initCubitSignal(initialState: 0);
    emit(0);
  }

  late final derived = computed(() {
    emit(1);
    this..emit(2);
    return value;
  });
}

class MixedBloc extends BlocSignalBase<int>
    with BlocSignalMixin<CounterEvent, int> {
  MixedBloc() : super(initialState: 0) {
    initCubitSignal(initialState: 0);
  }

  late final derived = computed(() {
    add(Increment());
    return value;
  });
}

mixin MyBlocMixin on BlocSignal<CounterEvent, int> {
  late final derived = computed(() {
    add(Increment());
    return value;
  });
}

void external(MixedCubit cubit, MixedBloc bloc) {
  computed(() {
    cubit.emit(3);
    bloc.add(Increment());
    return 0;
  });
}
''';
      final diagnostics = await runLintRule(
        AvoidEmitOrAddInComputed(),
        badCode,
      );
      expect(diagnostics, hasLength(6));
    });

    test(
      'flags prefixed bs.computed() and ignores user-defined computed()',
      () async {
        const code = '''
import 'package:bloc_signals/bloc_signals.dart' as bs;

class CounterCubit extends bs.CubitSignal<int> {
  CounterCubit() : super(initialState: 0);
}

T computed<T>(T Function() fn) => fn();

void testFn(CounterCubit cubit) {
  bs.computed(() {
    cubit.emit(1);
    return 1;
  });
  computed(() {
    cubit.emit(2);
    return 2;
  });
}
''';
        final diagnostics = await runLintRule(AvoidEmitOrAddInComputed(), code);
        expect(diagnostics, hasLength(1));
      },
    );
  });
}
