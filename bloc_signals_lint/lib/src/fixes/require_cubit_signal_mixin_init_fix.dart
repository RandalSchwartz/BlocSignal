// Ignore deprecated_member_use due to custom_lint_builder parameter signature.
// ignore_for_file: deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// An automated IDE quick-fix for `RequireCubitSignalMixinInit` that inserts
/// `initCubitSignal(initialState: ...);` into uninitialized constructor bodies.
///
/// Example:
/// ```dart
/// // Before:
/// MyService() {}
///
/// // After:
/// MyService() {
///   initCubitSignal(initialState: TODO_INITIAL_STATE);
/// }
/// ```
class RequireCubitSignalMixinInitFix extends DartFix {
  /// Creates a [RequireCubitSignalMixinInitFix] instance.
  RequireCubitSignalMixinInitFix();

  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addConstructorDeclaration((node) {
      if (!analysisError.sourceRange.intersects(node.sourceRange)) return;

      final body = node.body;
      reporter
          .createChangeBuilder(
        message: "Add 'initCubitSignal(initialState: ...);'",
        priority: 100,
      )
          .addDartFileEdit((builder) {
        if (body is BlockFunctionBody) {
          builder.addSimpleInsertion(
            body.offset + 1,
            '\n    initCubitSignal(initialState: TODO_INITIAL_STATE);',
          );
        } else if (body is EmptyFunctionBody) {
          builder.addSimpleReplacement(
            body.sourceRange,
            '{\n    initCubitSignal(initialState: TODO_INITIAL_STATE);\n  }',
          );
        }
      });
    });
  }
}
