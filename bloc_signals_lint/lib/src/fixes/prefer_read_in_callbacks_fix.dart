// Ignore deprecated_member_use due to custom_lint_builder parameter signature.
// ignore_for_file: deprecated_member_use

import 'package:analyzer/error/error.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// An automated IDE quick-fix for
/// `PreferBlocSignalProviderReadInCallbacks` that rewrites
/// `context.watch<T>()` to `context.read<T>()`.
class PreferReadInCallbacksFix extends DartFix {
  /// Creates a [PreferReadInCallbacksFix] instance.
  PreferReadInCallbacksFix();

  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addMethodInvocation((node) {
      if (!analysisError.sourceRange.intersects(node.sourceRange)) return;
      if (node.methodName.name != 'watch') return;

      reporter
          .createChangeBuilder(
        message: "Replace 'watch' with 'read'",
        priority: 100,
      )
          .addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          node.methodName.sourceRange,
          'read',
        );
      });
    });
  }
}
