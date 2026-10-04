// Ignore deprecated_member_use due to custom_lint_builder parameter signature.
// ignore_for_file: deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// An automated IDE quick-fix for `AvoidProvidingExistingInstanceWithCreate`
/// that rewrites `create:` to `value:` using the `.value` constructor.
///
/// Example:
/// ```dart
/// // Before:
/// BlocSignalProvider(create: (_) => existingBloc)
///
/// // After:
/// BlocSignalProvider.value(value: existingBloc)
/// ```
class UseProviderValueFix extends DartFix {
  /// Creates a [UseProviderValueFix] instance.
  UseProviderValueFix();

  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addNamedExpression((node) {
      if (!analysisError.sourceRange.intersects(node.sourceRange)) return;
      if (node.name.label.name != 'create') return;

      Expression? returnedExpr;
      final expr = node.expression;
      if (expr is FunctionExpression) {
        final body = expr.body;
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

      reporter
          .createChangeBuilder(
        message: "Use 'BlocSignalProvider.value(value: ...)'",
        priority: 100,
      )
          .addDartFileEdit((builder) {
        final parent = node.parent?.parent;
        if (parent is InstanceCreationExpression) {
          final ctor = parent.constructorName;
          if (ctor.name == null) {
            builder.addSimpleInsertion(ctor.type.end, '.value');
          }
        } else if (parent is MethodInvocation) {
          if (parent.target == null &&
              !parent.methodName.name.endsWith('.value')) {
            if (parent.typeArguments != null) {
              builder.addSimpleInsertion(
                parent.typeArguments!.end,
                '.value',
              );
            } else {
              builder.addSimpleReplacement(
                parent.methodName.sourceRange,
                '${parent.methodName.name}.value',
              );
            }
          }
        }

        if (returnedExpr != null) {
          builder.addSimpleReplacement(
            node.sourceRange,
            'value: ${returnedExpr.toSource()}',
          );
        } else {
          builder.addSimpleReplacement(
            node.name.label.sourceRange,
            'value',
          );
        }
      });
    });
  }
}
