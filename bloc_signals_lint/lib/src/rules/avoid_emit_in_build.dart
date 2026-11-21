import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:bloc_signals_lint/src/utils/type_checker.dart';

/// A lint rule that flags calls to `emit()` or `add()` on state containers
/// inside Flutter `Widget.build()` methods.
class AvoidEmitInBuild extends AnalysisRule {
  /// Creates an [AvoidEmitInBuild] lint rule.
  new()
    : super(
        name: 'avoid_emit_in_build',
        description:
            'Avoid calling emit() or add() on state containers inside '
            'Widget.build() methods.',
      );

  /// The diagnostic code reported by this rule.
  static const LintCode code = LintCode(
    'avoid_emit_in_build',
    'State mutations ("{0}") should not be invoked directly inside '
        'build() methods.',
    correctionMessage:
        'Move state mutation or event dispatch to an event '
        'callback, lifecycle method, or BlocSignalListener.',
  );

  static const _blocSignalBaseChecker = TypeChecker.fromName(
    'BlocSignalBase',
    packageName: 'bloc_signals',
  );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addMethodInvocation(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  new(this.rule);

  final AvoidEmitInBuild rule;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final methodName = node.methodName.name;
    if (methodName != 'emit' && methodName != 'add') return;

    final target = node.target;
    if (target == null) return;
    final targetType = target.staticType;
    if (targetType == null) return;

    if (AvoidEmitInBuild._blocSignalBaseChecker.isAssignableFromType(
      targetType,
    )) {
      final enclosingClosure = node.thisOrAncestorOfType<FunctionExpression>();
      if (enclosingClosure != null) return;

      final enclosingMethod = node.thisOrAncestorOfType<MethodDeclaration>();
      if (enclosingMethod != null && enclosingMethod.name.lexeme == 'build') {
        rule.reportAtNode(node.methodName, arguments: [methodName]);
      }
    }
  }
}
