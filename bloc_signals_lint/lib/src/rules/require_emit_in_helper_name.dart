import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:bloc_signals_lint/src/utils/bloc_container_utils.dart';

/// A lint rule that requires private helper methods invoking `emit()` to have
/// a name reflecting state emission (for example `_pruneAndEmit` or
/// `_emitUpdate`).
///
/// Disguised state mutations violate state atomicity by hiding side-effects
/// inside innocent-sounding helper methods.
class RequireEmitInHelperName extends AnalysisRule {
  /// Creates a [RequireEmitInHelperName] lint rule.
  new()
    : super(
        name: 'require_emit_in_helper_name',
        description:
            'Require private helper methods invoking emit() to have a name '
            'reflecting state emission.',
      );

  /// The diagnostic code reported by this rule.
  static const LintCode code = LintCode(
    'require_emit_in_helper_name',
    "Private helper method '{0}' calls `emit()`, but its name does not "
        'reflect state emission.',
    correctionMessage:
        "Rename to '{0}AndEmit' to declare state transition side-effects.",
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
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final visitor = _Visitor(this);
    registry
      ..addClassDeclaration(this, visitor)
      ..addMixinDeclaration(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  new(this.rule);

  final RequireEmitInHelperName rule;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    _checkBody(node, node.body);
  }

  @override
  void visitMixinDeclaration(MixinDeclaration node) {
    _checkBody(node, node.body);
  }

  void _checkBody(AstNode declaration, ClassBody body) {
    switch (body) {
      case EmptyClassBody():
        return;
      case BlockClassBody(:final members):
        if (!BlocContainerUtils.isBlocContainerDeclaration(declaration)) {
          return;
        }

        for (final member in members.whereType<MethodDeclaration>()) {
          if (RequireEmitInHelperName.isFlaggedHelper(member)) {
            rule.reportAtToken(member.name, arguments: [member.name.lexeme]);
          }
        }
    }
  }
}

class _EmitInvocationVisitor extends RecursiveAstVisitor<void> {
  new(this.onEmitFound);

  final void Function() onEmitFound;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'emit' &&
        BlocContainerUtils.isSelfOrUnqualifiedTarget(node.realTarget)) {
      onEmitFound();
    }
    super.visitMethodInvocation(node);
  }
}
