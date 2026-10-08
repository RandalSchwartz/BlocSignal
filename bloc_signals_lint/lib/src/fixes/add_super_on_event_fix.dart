// Ignore deprecated_member_use due to custom_lint_builder parameter signature.
// ignore_for_file: deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// An automated IDE quick-fix for `RequireSuperOnEvent` that inserts
/// `super.onEvent(event);` into `onEvent` overrides.
///
/// Respects the declared parameter name and converts arrow (`=>`) or empty
/// (`;`) function bodies into block bodies.
///
/// Example:
/// ```dart
/// // Before:
/// @override
/// void onEvent(MyEvent event) {
///   doSomething();
/// }
///
/// // After:
/// @override
/// void onEvent(MyEvent event) {
///   super.onEvent(event);
///   doSomething();
/// }
/// ```
class AddSuperOnEventFix extends DartFix {
  /// Creates an [AddSuperOnEventFix] instance.
  AddSuperOnEventFix();

  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addMethodDeclaration((node) {
      if (!analysisError.sourceRange.intersects(node.sourceRange)) return;

      final paramName =
          node.parameters?.parameters.firstOrNull?.name?.lexeme ?? 'event';
      final body = node.body;

      reporter
          .createChangeBuilder(
        message: "Add 'super.onEvent($paramName);'",
        priority: 100,
      )
          .addDartFileEdit((builder) {
        if (body is BlockFunctionBody) {
          builder.addSimpleInsertion(
            body.block.leftBracket.end,
            '\n    super.onEvent($paramName);',
          );
        } else if (body is ExpressionFunctionBody) {
          final keyword = body.keyword != null
              ? '${body.keyword!.lexeme}${body.star?.lexeme ?? ''} '
              : '';
          final expr = body.expression.toSource();
          builder.addSimpleReplacement(
            body.sourceRange,
            '$keyword{\n    super.onEvent($paramName);\n    $expr;\n  }',
          );
        } else if (body is EmptyFunctionBody) {
          builder.addSimpleReplacement(
            body.sourceRange,
            ' {\n    super.onEvent($paramName);\n  }',
          );
        }
      });
    });
  }
}
