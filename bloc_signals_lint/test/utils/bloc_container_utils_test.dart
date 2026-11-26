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

  group('(Issue #506) BlocContainerUtils extension helpers', () {
    test('handles non-NamedType ExtensionDeclaration and non-container '
        'declarations', () {
      final result = parseString(
        content: '''
enum SampleEnum { a, b }

extension on (int, int) {
  void f() {}
}
''',
      );
      final enumDecl = result.unit.declarations
          .whereType<EnumDeclaration>()
          .single;
      final extDecl = result.unit.declarations
          .whereType<ExtensionDeclaration>()
          .single;
      final methodNode = extDecl.body.members
          .whereType<MethodDeclaration>()
          .single;

      expect(
        BlocContainerUtils.nearestContainerOrExtensionDeclaration(methodNode),
        same(extDecl),
      );
      expect(BlocContainerUtils.isBlocContainerOrExtension(extDecl), isFalse);
      expect(BlocContainerUtils.isBlocSignalOrExtensionHost(extDecl), isFalse);
      expect(BlocContainerUtils.isBlocContainerOrExtension(enumDecl), isFalse);
      expect(BlocContainerUtils.isBlocSignalOrExtensionHost(enumDecl), isFalse);
    });
  });
}
