// Ignore deprecated_member_use due to custom_lint_builder parameter signature.
// ignore_for_file: deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// An automated IDE quick-fix for `PreferNamedReplayConstructor` that rewrites
/// `super.positional(...)` to `super(initialState: ...)`.
///
/// Example:
/// ```dart
/// // Before:
/// CounterCubit(int initial, {int? limit})
///     : super.positional(initial, limit: limit);
///
/// // After:
/// CounterCubit(int initial, {int? limit})
///     : super(initialState: initial, limit: limit);
/// ```
class ReplacePositionalReplayConstructorFix extends DartFix {
  /// Creates a [ReplacePositionalReplayConstructorFix] instance.
  ReplacePositionalReplayConstructorFix();

  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addSuperConstructorInvocation((node) {
      if (!analysisError.sourceRange.intersects(node.sourceRange)) return;
      if (node.constructorName?.name != 'positional') return;

      final period = node.period;
      final constructorName = node.constructorName;
      if (period == null || constructorName == null) return;

      final args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final positionalArg =
          args.where((arg) => arg is! NamedExpression).firstOrNull;
      if (positionalArg == null) return;

      reporter
          .createChangeBuilder(
        message:
            "Replace 'super.positional(...)' with 'super(initialState: ...)'",
        priority: 100,
      )
          .addDartFileEdit((builder) {
        builder
          ..addDeletion(
            SourceRange(
              period.offset,
              constructorName.end - period.offset,
            ),
          )
          ..addSimpleInsertion(
            positionalArg.offset,
            'initialState: ',
          );
      });
    });
  }
}
