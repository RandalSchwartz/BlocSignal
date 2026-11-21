import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';
import 'package:bloc_signals_lint/src/utils/bloc_container_utils.dart';

/// An automated IDE quick-fix for `RequireEmitInHelperName` that renames
/// private helper methods calling `emit()` by appending `AndEmit` to the method
/// declaration and its internal call sites within the class or mixin.
class RequireEmitInHelperNameFix extends ResolvedCorrectionProducer {
  /// Creates a [RequireEmitInHelperNameFix] instance.
  new({required super.context});

  static const _fixKind = FixKind(
    'bloc_signals_lint.fix.requireEmitInHelperName',
    DartFixKindPriority.standard,
    "Append 'AndEmit' to helper method name",
  );

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final method = node.thisOrAncestorOfType<MethodDeclaration>();
    if (method == null) return;

    final container = BlocContainerUtils.nearestContainerDeclaration(method);
    final body = switch (container) {
      ClassDeclaration(:final body) => body,
      MixinDeclaration(:final body) => body,
      _ => null,
    };
    if (body is! BlockClassBody) return;

    final oldName = method.name.lexeme;
    final newName = '${oldName}AndEmit';

    await builder.addDartFileEdit(file, (builder) {
      builder.addSimpleReplacement(method.name.sourceRange, newName);

      for (final member in body.members) {
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
  }

  /// Helper for unit testing AST string transformation.
  static String computeRename({
    required String source,
    required MethodDeclaration methodToRename,
    ClassDeclaration? classDeclaration,
    MixinDeclaration? mixinDeclaration,
  }) {
    final body = classDeclaration?.body ?? mixinDeclaration?.body;
    if (body is! BlockClassBody) return source;

    final oldName = methodToRename.name.lexeme;
    final newName = '${oldName}AndEmit';

    final replacements = <SourceRange>[methodToRename.name.sourceRange];

    for (final member in body.members) {
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
  new(this.targetName, this.onMatch);

  final String targetName;
  final void Function(MethodInvocation node) onMatch;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == targetName &&
        BlocContainerUtils.isSelfOrUnqualifiedTarget(node.realTarget)) {
      onMatch(node);
    }
    super.visitMethodInvocation(node);
  }
}
