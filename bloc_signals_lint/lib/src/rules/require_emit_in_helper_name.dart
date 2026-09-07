// Ignore deprecated_member_use due to custom_lint_builder parameter signature.
// ignore_for_file: deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/listener.dart';
import 'package:bloc_signals_lint/src/fixes/require_emit_in_helper_name_fix.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// A lint rule that requires private helper methods invoking `emit()` to have
/// a name reflecting state emission (for example `_pruneAndEmit` or
/// `_emitUpdate`).
///
/// Disguised state mutations violate state atomicity by hiding side-effects
/// inside innocent-sounding helper methods.
class RequireEmitInHelperName extends DartLintRule {
  /// Creates a [RequireEmitInHelperName] lint rule.
  const RequireEmitInHelperName() : super(code: _code);

  static const _code = LintCode(
    name: 'require_emit_in_helper_name',
    problemMessage:
        "Private helper method '{0}' calls `emit()`, but its name does not "
        'reflect state emission.',
    correctionMessage:
        "Rename to '{0}AndEmit' to declare state transition side-effects.",
  );

  static const _blocSignalBaseChecker = TypeChecker.fromName(
    'BlocSignalBase',
    packageName: 'bloc_signals',
  );

  static final _emittingNameRegex = RegExp(
    r'(^_?emit($|[_0-9A-Z])|(_emit($|[_0-9A-Z])|[a-z]Emit($|[_0-9A-Z])))',
  );

  /// Checks whether an identifier name reflects state emission.
  static bool isEmittingName(String name) {
    if (name.isEmpty) return false;
    return _emittingNameRegex.hasMatch(name);
  }

  /// Checks whether [method] invokes `emit()` directly on this state container.
  static bool callsEmit(MethodDeclaration method) {
    var hasEmit = false;
    method.body.visitChildren(
      _EmitInvocationVisitor(() {
        hasEmit = true;
      }),
    );
    return hasEmit;
  }

  /// Determines whether a method is a private helper calling `emit()` without
  /// indicating state emission in its name.
  static bool isFlaggedHelper(MethodDeclaration method) {
    if (method.isGetter || method.isSetter) return false;
    final name = method.name.lexeme;
    if (!name.startsWith('_')) return false;
    if (isEmittingName(name)) return false;
    return callsEmit(method);
  }

  @override
  List<Fix> getFixes() => [RequireEmitInHelperNameFix()];

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      final classElement = node.declaredFragment?.element;
      final extendsClause = node.extendsClause?.superclass.toSource();
      final withClause = node.withClause?.toSource();

      final isBlocContainer = (classElement != null &&
              _blocSignalBaseChecker.isSuperOf(classElement)) ||
          (extendsClause != null &&
              (extendsClause.contains('BlocSignal') ||
                  extendsClause.contains('CubitSignal') ||
                  extendsClause.contains('ReplayCubit') ||
                  extendsClause.contains('ReplayBloc'))) ||
          (withClause != null &&
              (withClause.contains('CubitSignalMixin') ||
                  withClause.contains('BlocSignalMixin')));

      if (!isBlocContainer) return;

      for (final member in node.members.whereType<MethodDeclaration>()) {
        if (isFlaggedHelper(member)) {
          reporter.atToken(
            member.name,
            code,
            arguments: [member.name.lexeme],
          );
        }
      }
    });
  }
}

class _EmitInvocationVisitor extends RecursiveAstVisitor<void> {
  _EmitInvocationVisitor(this.onEmitFound);

  final void Function() onEmitFound;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'emit') {
      final target = node.target;
      if (target == null || target is ThisExpression) {
        onEmitFound();
      }
    }
    super.visitMethodInvocation(node);
  }
}
