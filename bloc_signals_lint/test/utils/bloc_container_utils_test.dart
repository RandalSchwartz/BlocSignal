import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:bloc_signals_lint/src/utils/bloc_container_utils.dart';
import 'package:test/test.dart';

void main() {
  group('(Issue #505) BlocContainerUtils', () {
    test('isUiComponentOrState returns false for non-class, non-mixin '
        'declarations', () {
      final result = parseString(content: 'enum SampleEnum { a, b }');
      final enumDecl = result.unit.declarations
          .whereType<EnumDeclaration>()
          .single;

      expect(BlocContainerUtils.isUiComponentOrState(enumDecl), isFalse);
    });
  });
}
