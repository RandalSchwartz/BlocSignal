// Ignore deprecated_member_use due to custom_lint_builder parameter signature.
// ignore_for_file: deprecated_member_use

import 'package:analyzer/error/error.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// An automated IDE quick-fix for `RequireSuperOnEvent` that inserts
/// `super.onEvent(event);` into `onEvent` overrides.
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

      reporter
          .createChangeBuilder(
        message: "Add 'super.onEvent(event);'",
        priority: 100,
      )
          .addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.body.offset + 1,
          '\n    super.onEvent(event);',
        );
      });
    });
  }
}
