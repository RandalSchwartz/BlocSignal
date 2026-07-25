// Ignore deprecated_member_use due to custom_lint_builder parameter signature.
// ignore_for_file: deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// A lint rule that flags passing pre-existing variable references to
/// `BlocSignalProvider(create: ...)` instead of `BlocSignalProvider.value(value: ...)`.
class AvoidProvidingExistingInstanceWithCreate extends DartLintRule {
  /// Creates an [AvoidProvidingExistingInstanceWithCreate] lint rule.
  const AvoidProvidingExistingInstanceWithCreate() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_providing_existing_instance_with_create',
    problemMessage:
        'Passing an existing instance "{0}" to BlocSignalProvider(create: ...) '
        'will cause it to be automatically closed when unmounted.',
    correctionMessage:
        'Use BlocSignalProvider.value(value: ...) to provide existing instances without transferring disposal ownership.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    void checkArgumentList(
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
        if (arg is NamedExpression && arg.name.label.name == 'create') {
          final expression = arg.expression;
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
            final isExistingRef = returnedExpr is SimpleIdentifier ||
                returnedExpr is PropertyAccess ||
                returnedExpr is PrefixedIdentifier;

            if (isExistingRef && returnedExpr is! InstanceCreationExpression) {
              reporter.atNode(
                returnedExpr,
                code,
                arguments: [returnedExpr.toSource()],
              );
            }
          }
        }
      }
    }

    context.registry.addInstanceCreationExpression((node) {
      checkArgumentList(
        node.constructorName.type.toSource(),
        node.constructorName.name,
        node.argumentList,
      );
    });

    context.registry.addMethodInvocation((node) {
      if (node.target == null) {
        checkArgumentList(
          node.methodName.name,
          null,
          node.argumentList,
        );
      }
    });
  }
}
