import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:bloc_signals_lint/src/utils/type_checker.dart';
import 'package:test/test.dart';

void main() {
  group('TypeChecker', () {
    late Directory tempDir;
    late ResolvedUnitResult unitResult;

    setUpAll(() async {
      tempDir = Directory.systemTemp.createTempSync('type_checker_test_');
      final rootPath = tempDir.resolveSymbolicLinksSync();
      Directory('$rootPath/.dart_tool').createSync(recursive: true);
      File('$rootPath/.dart_tool/package_config.json').writeAsStringSync('''
{
  "configVersion": 2,
  "packages": [
    {
      "name": "sample_pkg",
      "rootUri": "..",
      "packageUri": "lib/",
      "languageVersion": "3.5"
    }
  ]
}
''');
      Directory('$rootPath/lib').createSync(recursive: true);
      final filePath = '$rootPath/lib/sample.dart';
      File(filePath).writeAsStringSync('''
class Base {}
class Sub extends Base {}
void topLevelFn() {}
void genericFn<T extends Sub, U extends Comparable<U>, A extends B, B extends A>(
  T t,
  U u,
  A a,
) {}
''');

      String? sdkPath;
      final execDir = File(Platform.resolvedExecutable).parent;
      final defaultCandidate = execDir.parent.path;
      if (!File('$defaultCandidate/lib/_internal/allowed_experiments.json')
          .existsSync()) {
        var current = execDir;
        for (var i = 0; i < 6; i++) {
          final candidate = '${current.path}/dart-sdk';
          if (File('$candidate/lib/_internal/allowed_experiments.json')
              .existsSync()) {
            sdkPath = candidate;
            break;
          }
          current = current.parent;
        }
      }

      final collection = AnalysisContextCollection(
        includedPaths: [rootPath],
        sdkPath: sdkPath,
      );
      final context = collection.contextFor(filePath);
      final result = await context.currentSession.getResolvedUnit(filePath);
      unitResult = result as ResolvedUnitResult;
    });

    tearDownAll(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('matches without packageName and rejects mismatched packageName', () {
      const anyPkgChecker = TypeChecker.fromName('Base');
      const otherPkgChecker = TypeChecker.fromName(
        'Base',
        packageName: 'other_pkg',
      );
      const samePkgChecker = TypeChecker.fromName(
        'Base',
        packageName: 'sample_pkg',
      );

      final subDecl = unitResult.unit.declarations
          .whereType<ClassDeclaration>()
          .firstWhere((c) => c.namePart.typeName.lexeme == 'Sub');
      final subElement = subDecl.declaredFragment!.element;

      expect(anyPkgChecker.isSuperOf(subElement), isTrue);
      expect(samePkgChecker.isSuperOf(subElement), isTrue);
      expect(otherPkgChecker.isSuperOf(subElement), isFalse);
    });

    test('returns false for non-InterfaceElement', () {
      const checker = TypeChecker.fromName('topLevelFn');
      final fnDecl = unitResult.unit.declarations
          .whereType<FunctionDeclaration>()
          .firstWhere((f) => f.name.lexeme == 'topLevelFn');
      final fnElement = fnDecl.declaredFragment!.element;

      expect(checker.isExactly(fnElement), isFalse);
      expect(checker.isSuperOf(fnElement), isFalse);
    });

    test(
      'resolves TypeParameterType bounds and guards against cyclic bounds',
      () {
        const baseChecker = TypeChecker.fromName('Base');
        const missingChecker = TypeChecker.fromName('Missing');

        final genericFn = unitResult.unit.declarations
            .whereType<FunctionDeclaration>()
            .firstWhere((f) => f.name.lexeme == 'genericFn');
        final params = genericFn.functionExpression.parameters!.parameters;
        final tType = params[0].declaredFragment!.element.type;
        final uType = params[1].declaredFragment!.element.type;
        final aType = params[2].declaredFragment!.element.type;

        expect(tType, isA<TypeParameterType>());
        expect(baseChecker.isAssignableFromType(tType), isTrue);
        expect(missingChecker.isAssignableFromType(uType), isFalse);
        expect(missingChecker.isAssignableFromType(aType), isFalse);
      },
    );
  });
}
