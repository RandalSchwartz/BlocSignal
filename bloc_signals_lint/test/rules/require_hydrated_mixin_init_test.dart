import 'package:bloc_signals_lint/src/rules/require_hydrated_mixin_init.dart';
import 'package:test/test.dart';

import '../src/lint_test_harness.dart';

void main() {
  tearDownAll(disposeLintTestHarness);

  group('(Issue #482) RequireHydratedMixinInit', () {
    test(
      'flags classes mixing HydratedMixin + CubitSignalMixin/BlocSignalMixin '
      'that omit hydrate() in non-factory, non-redirecting constructors',
      () async {
        const badCode = '''
import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';

class EmptyBodyCubit extends BlocSignalBase<int>
    with CubitSignalMixin<int>, HydratedMixin<int>;

class MissingHydrateCubit extends BlocSignalBase<int>
    with CubitSignalMixin<int>, HydratedMixin<int> {
  MissingHydrateCubit() {
    initCubitSignal(initialState: 0);
  }

  MissingHydrateCubit.redirect() : this();

  factory MissingHydrateCubit.fromZero() => MissingHydrateCubit();
}

class PrimaryNoBodyCubit(int initial) extends BlocSignalBase<int>
    with CubitSignalMixin<int>, HydratedMixin<int>;

class PrimaryMissingHydrateCubit(int initial) extends BlocSignalBase<int>
    with CubitSignalMixin<int>, HydratedMixin<int> {
  this {
    initCubitSignal(initialState: 0);
  }
}
''';
        final lints = await runLintRule(RequireHydratedMixinInit(), badCode);
        expect(lints, hasLength(4));
      },
    );

    test(
      'allows classes that call hydrate() in constructors or primary body',
      () async {
        const goodCode = '''
import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';

class GoodHydratedCubit extends BlocSignalBase<int>
    with CubitSignalMixin<int>, HydratedMixin<int> {
  GoodHydratedCubit() {
    initCubitSignal(initialState: 0);
    hydrate();
  }
}

class GoodPrimaryCubit(int initial) extends BlocSignalBase<int>
    with CubitSignalMixin<int>, HydratedMixin<int> {
  this {
    initCubitSignal(initialState: 0);
    hydrate();
  }
}

class SubclassWithoutMixin extends HydratedCubitSignal<int> {
  SubclassWithoutMixin() : super(initialState: 0);
}
''';
        final lints = await runLintRule(RequireHydratedMixinInit(), goodCode);
        expect(lints, isEmpty);
      },
    );

    test(
      '(Issue #482: NBO-2) ignores other.hydrate() and allows this.hydrate()',
      () async {
        const code = '''
import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';

class Helper {
  void hydrate() {}
}

class BadCubit extends BlocSignalBase<int>
    with CubitSignalMixin<int>, HydratedMixin<int> {
  BadCubit(Helper helper) {
    initCubitSignal(initialState: 0);
    helper.hydrate();
  }
}

class GoodCubit extends BlocSignalBase<int>
    with CubitSignalMixin<int>, HydratedMixin<int> {
  GoodCubit() {
    initCubitSignal(initialState: 0);
    this.hydrate();
  }
}
''';
        final lints = await runLintRule(RequireHydratedMixinInit(), code);
        expect(lints, hasLength(1));
        expect(lints.single.lexeme, equals('BadCubit'));
      },
    );

    test(
      '(Issue #482: Round 2 BLOCKER-3) handles HydratedMixin + '
      'BlocSignalMixin, single-mixin class, and unresolved typeSource',
      () async {
        const blocMixinCode = '''
import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';

class Ev {}

class BadHydratedBloc extends BlocSignalBase<int>
    with BlocSignalMixin<Ev, int>, HydratedMixin<int> {
  BadHydratedBloc() {
    initCubitSignal(initialState: 0);
  }
}

class SingleMixinCubit extends CubitSignal<int> with HydratedMixin<int> {
  SingleMixinCubit() : super(initialState: 0);
}
''';
        final blocLints = await runLintRule(
          RequireHydratedMixinInit(),
          blocMixinCode,
        );
        expect(blocLints, hasLength(1));
        expect(blocLints.single.lexeme, equals('BadHydratedBloc'));

        const unresolvedCode = '''
import 'package:bloc_signals/bloc_signals.dart';

class UnresolvedHydrated extends MissingBase
    with CubitSignalMixin<int>, HydratedMixin<int>;
''';
        final unresolvedLints = await runLintRule(
          RequireHydratedMixinInit(),
          unresolvedCode,
        );
        expect(unresolvedLints, hasLength(1));
        expect(unresolvedLints.single.lexeme, equals('UnresolvedHydrated'));

        const unresolvedBothCode = '''
import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';

class UnresolvedBlocMixin extends MissingBase
    with BlocSignalMixin<int, int>, HydratedMixin<int>;

class UnresolvedCubitMixin extends MissingBase
    with CubitSignalMixin<int>, HydratedMixin<int>;
''';
        final unresolvedBothLints = await runLintRule(
          RequireHydratedMixinInit(),
          unresolvedBothCode,
        );
        expect(unresolvedBothLints, hasLength(2));
        expect(
          unresolvedBothLints.map((l) => l.lexeme),
          containsAll(['UnresolvedBlocMixin', 'UnresolvedCubitMixin']),
        );
      },
    );
  });
}
