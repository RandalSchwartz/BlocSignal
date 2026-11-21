import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:bloc_signals_lint/src/utils/bloc_container_utils.dart';

/// A lint rule that flags calling `context.select()` as an unused expression
/// statement where the returned value is discarded.
class AvoidUnusedSelectResult extends AnalysisRule {
  /// Creates an [AvoidUnusedSelectResult] lint rule.
  new()
    : super(
        name: 'avoid_unused_select_result',
        description:
            'Flag calling context.select() as an unused expression '
            'statement.',
      );

  /// The diagnostic code reported by this rule.
  static const LintCode code = LintCode(
    'avoid_unused_select_result',
    'The return value of "context.select(...)" is unused. Calling select '
        'without consuming the result creates an unnecessary reactive '
        'subscription.',
    correctionMessage:
        'Store the result in a variable (for example '
        '"final value = context.select(...)") '
        'or use "BlocSignalListener" if you intended a side-effect.',
  );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addExpressionStatement(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  new(this.rule);

  final AvoidUnusedSelectResult rule;

  @override
  void visitExpressionStatement(ExpressionStatement node) {
    final expr = node.expression;
    if (expr is MethodInvocation && expr.methodName.name == 'select') {
      if (BlocContainerUtils.isBuildContextReceiver(expr.target)) {
        rule.reportAtNode(expr.methodName);
      }
    }
  }
}
