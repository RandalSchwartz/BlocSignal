import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

/// A lint rule that flags passing pre-existing variable references to
/// `BlocSignalProvider(create: ...)` instead of
/// `BlocSignalProvider.value(value: ...)`.
class AvoidProvidingExistingInstanceWithCreate extends AnalysisRule {
  /// Creates an [AvoidProvidingExistingInstanceWithCreate] lint rule.
  new()
    : super(
        name: 'avoid_providing_existing_instance_with_create',
        description:
            'Flag passing existing instance references to '
            'BlocSignalProvider(create: ...) instead of '
            'BlocSignalProvider.value(value: ...).',
      );

  /// The diagnostic code reported by this rule.
  static const LintCode code = LintCode(
    'avoid_providing_existing_instance_with_create',
    'Passing an existing instance "{0}" to BlocSignalProvider(create: ...) '
        'will cause it to be automatically closed when unmounted.',
    correctionMessage:
        'Use BlocSignalProvider.value(value: ...) to provide existing '
        'instances without transferring disposal ownership.',
  );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final visitor = _Visitor(this);
    registry
      ..addInstanceCreationExpression(this, visitor)
      ..addMethodInvocation(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  new(this.rule);

  final AvoidProvidingExistingInstanceWithCreate rule;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    _checkArgumentList(
      node.constructorName.type.toSource(),
      node.constructorName.name,
      node.argumentList,
    );
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target == null) {
      _checkArgumentList(node.methodName.name, null, node.argumentList);
    }
  }

  void _checkArgumentList(
    String providerName,
    Identifier? constructorName,
    ArgumentList argumentList,
  ) {
    if (!providerName.contains('BlocSignalProvider') &&
        !providerName.contains('BlocProvider')) {
      return;
    }

    // Check if constructor is default constructor (not .value)
    if (constructorName != null && constructorName.name == 'value') return;

    for (final arg in argumentList.arguments) {
      if (arg is NamedArgument && arg.name.lexeme == 'create') {
        final expression = arg.argumentExpression;
        Expression? returnedExpr;

        if (expression is FunctionExpression) {
          final body = expression.body;
          if (body is ExpressionFunctionBody) {
            returnedExpr = body.expression;
          } else if (body is BlockFunctionBody) {
            for (final statement in body.block.statements) {
              if (statement is ReturnStatement) {
                returnedExpr = statement.expression;
                break;
              }
            }
          }
        }

        if (returnedExpr != null) {
          final isExistingRef =
              returnedExpr is SimpleIdentifier ||
              returnedExpr is PropertyAccess ||
              returnedExpr is PrefixedIdentifier;

          if (isExistingRef && returnedExpr is! InstanceCreationExpression) {
            rule.reportAtNode(
              returnedExpr,
              arguments: [returnedExpr.toSource()],
            );
          }
        }
      }
    }
  }
}
