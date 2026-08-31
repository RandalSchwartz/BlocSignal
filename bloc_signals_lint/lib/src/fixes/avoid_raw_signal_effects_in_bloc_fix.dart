// Ignore deprecated_member_use due to custom_lint_builder parameter signature.
// ignore_for_file: deprecated_member_use

import 'package:analyzer/error/error.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// An automated IDE quick-fix for `AvoidRawSignalEffectsInBloc` that rewrites
/// unmanaged `effect(...)` calls to `createEffect(...)`.
///
/// Example:
/// ```dart
/// // Before:
/// effect(() { print(stateValue); });
///
/// // After:
/// createEffect(() { print(stateValue); });
/// ```
class AvoidRawSignalEffectsInBlocFix extends DartFix {
  /// Creates an [AvoidRawSignalEffectsInBlocFix] instance.
  AvoidRawSignalEffectsInBlocFix();

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
      if (node.methodName.name != 'effect') return;

      reporter
          .createChangeBuilder(
        message: "Replace 'effect' with 'createEffect'",
        priority: 100,
      )
          .addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          node.methodName.sourceRange,
          'createEffect',
        );
      });
    });
  }
}
