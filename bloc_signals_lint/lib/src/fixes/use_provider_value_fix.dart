// Ignore deprecated_member_use due to custom_lint_builder parameter signature.
// ignore_for_file: deprecated_member_use

import 'package:analyzer/error/error.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// An automated IDE quick-fix for `AvoidProvidingExistingInstanceWithCreate`
/// that rewrites `create:` to `value:`.
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

      reporter
          .createChangeBuilder(
        message: "Replace 'create:' with 'value:'",
        priority: 100,
      )
          .addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          node.name.label.sourceRange,
          'value',
        );
      });
    });
  }
}
