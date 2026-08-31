// Ignore deprecated_member_use due to custom_lint_builder parameter signature.
// ignore_for_file: deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// A lint rule that flags calling `context.select()` as an unused expression
/// statement where the returned value is discarded.
class AvoidUnusedSelectResult extends DartLintRule {
  /// Creates an [AvoidUnusedSelectResult] lint rule.
  const AvoidUnusedSelectResult() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_unused_select_result',
    problemMessage:
        'The return value of "context.select(...)" is unused. Calling select '
        'without consuming the result creates an unnecessary reactive '
        'subscription.',
    correctionMessage: 'Store the result in a variable (for example '
        '"final value = context.select(...)") '
        'or use "BlocSignalListener" if you intended a side-effect.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addExpressionStatement((node) {
      final expr = node.expression;
      if (expr is MethodInvocation && expr.methodName.name == 'select') {
        final target = expr.target;
        if (target != null && target.toSource().contains('context')) {
          reporter.atNode(
            expr.methodName,
            code,
          );
        }
      }
    });
  }
}
