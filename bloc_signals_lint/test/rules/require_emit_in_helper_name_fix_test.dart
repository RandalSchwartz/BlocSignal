import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:bloc_signals_lint/src/fixes/require_emit_in_helper_name_fix.dart';
import 'package:test/test.dart';

void main() {
  group('RequireEmitInHelperNameFix AST Transformation', () {
    test('instantiates cleanly', () {
      final fix = RequireEmitInHelperNameFix();
      expect(fix, isA<RequireEmitInHelperNameFix>());
    });

    test('renames helper method declaration and internal call sites to AndEmit',
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
      final classDeclaration =
          parseResult.unit.declarations.whereType<ClassDeclaration>().first;
      final helperMethod = classDeclaration.members
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
    });
  });
}
