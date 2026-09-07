// Ignore deprecated_member_use due to custom_lint_builder parameter signature.
// ignore_for_file: deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// An automated IDE quick-fix for `RequireEmitInHelperName` that renames
/// private helper methods calling `emit()` by appending `AndEmit` to the method
/// declaration and its internal call sites within the class.
class RequireEmitInHelperNameFix extends DartFix {
  /// Creates a [RequireEmitInHelperNameFix] instance.
  RequireEmitInHelperNameFix();

  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addMethodDeclaration((node) {
      if (!analysisError.sourceRange.intersects(node.name.sourceRange)) return;

      final classDeclaration = node.thisOrAncestorOfType<ClassDeclaration>();
      if (classDeclaration == null) return;

      final oldName = node.name.lexeme;
      final newName = '${oldName}AndEmit';

      reporter
          .createChangeBuilder(
        message: "Rename to '$newName'",
        priority: 100,
      )
          .addDartFileEdit((builder) {
        builder.addSimpleReplacement(node.name.sourceRange, newName);

        for (final member in classDeclaration.members) {
          member.visitChildren(
            _RenameInvocationVisitor(oldName, (invocation) {
              builder.addSimpleReplacement(
                invocation.methodName.sourceRange,
                newName,
              );
            }),
          );
        }
      });
    });
  }

  /// Helper for unit testing AST string transformation.
  static String computeRename({
    required String source,
    required ClassDeclaration classDeclaration,
    required MethodDeclaration methodToRename,
  }) {
    final oldName = methodToRename.name.lexeme;
    final newName = '${oldName}AndEmit';

    final replacements = <SourceRange>[
      methodToRename.name.sourceRange,
    ];

    for (final member in classDeclaration.members) {
      member.visitChildren(
        _RenameInvocationVisitor(oldName, (invocation) {
          replacements.add(invocation.methodName.sourceRange);
        }),
      );
    }

    replacements.sort((a, b) => b.offset.compareTo(a.offset));

    var result = source;
    for (final range in replacements) {
      result = result.replaceRange(range.offset, range.end, newName);
    }
    return result;
  }
}

class _RenameInvocationVisitor extends RecursiveAstVisitor<void> {
  _RenameInvocationVisitor(this.targetName, this.onMatch);

  final String targetName;
  final void Function(MethodInvocation node) onMatch;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == targetName) {
      final target = node.target;
      if (target == null || target is ThisExpression) {
        onMatch(node);
      }
    }
    super.visitMethodInvocation(node);
  }
}
