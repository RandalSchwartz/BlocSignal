import 'package:bloc_signals_lint/src/rules/require_hydrated_storage_prefix.dart';
import 'package:test/test.dart';

import '../src/lint_test_harness.dart';

void main() {
  tearDownAll(disposeLintTestHarness);

  group('(Issue #482) RequireHydratedStoragePrefix', () {
    test('flags concrete HydratedCubitSignal, HydratedBlocSignal, and '
        'HydratedMixin classes omitting storagePrefix', () async {
      const badCode = '''
import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';

class CounterHydratedCubit extends HydratedCubitSignal<int> {
  CounterHydratedCubit() : super(initialState: 0);
}

class AuthEvent {}

class AuthHydratedBloc extends HydratedBlocSignal<AuthEvent, int> {
  AuthHydratedBloc() : super(initialState: 0);
}

class SettingsCubit extends CubitSignal<int> with HydratedMixin<int>;
''';
      final lints = await runLintRule(RequireHydratedStoragePrefix(), badCode);
      expect(lints, hasLength(3));
      expect(
        lints.map((l) => l.lexeme),
        containsAll([
          'CounterHydratedCubit',
          'AuthHydratedBloc',
          'SettingsCubit',
        ]),
      );
    });

    test(
      'allows abstract classes and concrete classes overriding storagePrefix',
      () async {
        const goodCode = '''
import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';

abstract class BaseHydratedCubit extends HydratedCubitSignal<int> {
  BaseHydratedCubit() : super(initialState: 0);
}

class CounterHydratedCubit extends BaseHydratedCubit {
  @override
  String get storagePrefix => 'counter_hydrated_cubit';
}

class SettingsCubit extends CubitSignal<int> with HydratedMixin<int> {
  @override
  String get storagePrefix => 'settings_cubit';
}

class FieldPrefixCubit extends HydratedCubitSignal<int> {
  FieldPrefixCubit() : super(initialState: 0);

  @override
  final String storagePrefix = 'field_prefix_cubit';
}

abstract class IntermediatePrefixCubit extends HydratedCubitSignal<int> {
  IntermediatePrefixCubit() : super(initialState: 0);

  @override
  String get storagePrefix => 'intermediate_prefix';
}

class ConcreteInheritedPrefixCubit extends IntermediatePrefixCubit {}
''';
        final lints = await runLintRule(
          RequireHydratedStoragePrefix(),
          goodCode,
        );
        expect(lints, isEmpty);
      },
    );

    test('(Issue #482: Round 2 BLOCKER-6) flags unresolved Hydrated extends '
        'and with fallback', () async {
      const unresolvedCode = '''
import 'package:bloc_signals/bloc_signals.dart';

class UnresolvedExtends extends HydratedCubitSignal<int> {}
class UnresolvedWith extends CubitSignal<int> with HydratedMixin<int>;
''';
      final lints = await runLintRule(
        RequireHydratedStoragePrefix(),
        unresolvedCode,
      );
      expect(lints, hasLength(2));
    });

    test('(Issue #482: Round 3 BLOCKER-2) skips sealed classes while flagging '
        'concrete subtypes omitting storagePrefix', () async {
      const sealedCode = '''
import 'package:bloc_signals/bloc_signals.dart';
import 'package:bloc_signals_hydrate/bloc_signals_hydrate.dart';

sealed class BaseSealedHydratedCubit extends HydratedCubitSignal<int> {
  BaseSealedHydratedCubit() : super(initialState: 0);
}

class ConcreteSealedChild extends BaseSealedHydratedCubit {}
''';
      final lints = await runLintRule(
        RequireHydratedStoragePrefix(),
        sealedCode,
      );
      expect(lints, hasLength(1));
      expect(lints.single.lexeme, equals('ConcreteSealedChild'));
    });
  });
}
