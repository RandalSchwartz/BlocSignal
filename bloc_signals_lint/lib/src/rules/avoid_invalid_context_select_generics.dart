// Ignore deprecated_member_use due to custom_lint_builder parameter signature.
// ignore_for_file: deprecated_member_use

import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// A lint rule that catches incorrect usages of `context.select` with
/// 3 generic type parameters.
///
/// In `bloc_signals_flutter`, `context.select<B, R>` takes
/// 2 generic parameters:
/// 1. `B`: The `BlocSignalBase` container type
/// 2. `R`: The selected return value type
class AvoidInvalidContextSelectGenerics extends DartLintRule {
  /// Creates an [AvoidInvalidContextSelectGenerics] lint rule.
  const AvoidInvalidContextSelectGenerics() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_invalid_context_select_generics',
    problemMessage:
        'In "bloc_signals_flutter", "context.select<B, R>" takes 2 generic '
        'type parameters (<Bloc, Selected>) instead of 3.',
    correctionMessage: 'Remove the redundant State generic argument. Use '
        '"context.select<Bloc, Selected>((bloc) => ...)" instead.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((node) {
      if (node.methodName.name != 'select') return;

      final typeArguments = node.typeArguments;
      if (typeArguments != null && typeArguments.arguments.length > 2) {
        reporter.atNode(typeArguments, _code);
      }
    });
  }
}
