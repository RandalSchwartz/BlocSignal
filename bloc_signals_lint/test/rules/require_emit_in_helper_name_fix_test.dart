import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:bloc_signals_lint/src/fixes/require_emit_in_helper_name_fix.dart';
import 'package:bloc_signals_lint/src/rules/require_emit_in_helper_name.dart';
import 'package:test/test.dart';

import '../src/lint_test_harness.dart';

void main() {
  tearDownAll(disposeLintTestHarness);

  group('RequireEmitInHelperNameFix AST Transformation', () {
    test(
      'renames helper method declaration and internal call sites via fix',
      () async {
        const sourceCode = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void update() {
    _prune();
    this._prune();
  }

  void _prune() {
    emit(stateValue + 1);
  }
}
''';
        final transformed = await runLintFix(
          RequireEmitInHelperName(),
          RequireEmitInHelperNameFix.new,
          sourceCode,
        );

        expect(transformed, contains('void _pruneAndEmit()'));
        expect(transformed, contains('_pruneAndEmit();'));
        expect(transformed, contains('this._pruneAndEmit();'));
        expect(transformed, isNot(contains('void _prune()')));
      },
    );

    test(
      'computeRename renames helper method declaration and internal calls',
      () {
        const sourceCode = '''
class CounterCubit extends CubitSignal<int> {
  CounterCubit() : super(initialState: 0);

  void update() {
    _prune();
    this._prune();
  }

  void _prune() {
    emit(stateValue + 1);
  }
}
''';
        final parseResult = parseString(content: sourceCode);
        final classDeclaration = parseResult.unit.declarations
            .whereType<ClassDeclaration>()
            .first;
        final body = classDeclaration.body as BlockClassBody;
        final helperMethod = body.members
            .whereType<MethodDeclaration>()
            .firstWhere((m) => m.name.lexeme == '_prune');

        final transformed = RequireEmitInHelperNameFix.computeRename(
          source: sourceCode,
          classDeclaration: classDeclaration,
          methodToRename: helperMethod,
        );

        expect(transformed, contains('void _pruneAndEmit()'));
        expect(transformed, contains('_pruneAndEmit();'));
        expect(transformed, contains('this._pruneAndEmit();'));
        expect(transformed, isNot(contains('void _prune()')));
      },
    );
  });
}
