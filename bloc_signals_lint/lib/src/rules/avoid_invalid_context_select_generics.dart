// Ignore deprecated_member_use due to custom_lint_builder parameter signature.
// ignore_for_file: deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/listener.dart';
import 'package:bloc_signals_lint/src/utils/bloc_container_utils.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// A lint rule that catches incorrect usages of `context.select` with
/// missing, wrong-arity, raw `BlocSignalBase`, or non-`BlocSignalBase` generic
/// type parameters.
///
/// In `bloc_signals_flutter` and `bloc_signals_jaspr`, `context.select<B, R>`
/// requires 2 explicit generic parameters:
/// 1. `B`: A concrete `BlocSignalBase` container subtype
/// 2. `R`: The selected return value type
class AvoidInvalidContextSelectGenerics extends DartLintRule {
  /// Creates an [AvoidInvalidContextSelectGenerics] lint rule.
  const AvoidInvalidContextSelectGenerics() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_invalid_context_select_generics',
    problemMessage: 'In "bloc_signals_flutter" and "bloc_signals_jaspr", '
        '"context.select<B, R>" requires 2 explicit generic type parameters '
        '(<Bloc extends BlocSignalBase, Selected>).',
    correctionMessage: 'Specify both the concrete BlocSignalBase subtype and '
        'selected type: "context.select<MyBloc, Selected>((bloc) => ...)".',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((node) {
      if (node.methodName.name != 'select') return;

      if (!BlocContainerUtils.isBuildContextReceiver(node.target)) return;

      final typeArguments = node.typeArguments;
      if (typeArguments == null || typeArguments.arguments.length != 2) {
        reporter.atNode(typeArguments ?? node.methodName, _code);
        return;
      }

      final firstArg = typeArguments.arguments.first;
      final firstType = firstArg.type;
      if (firstType == null || firstType is InvalidType) return;

      if (firstType is DynamicType || firstType is VoidType) {
        reporter.atNode(typeArguments, _code);
        return;
      }

      final isBlocSubtype = BlocContainerUtils.blocSignalBaseChecker
          .isAssignableFromType(firstType);
      final isRawBase = firstArg is NamedType &&
          firstArg.typeArguments == null &&
          BlocContainerUtils.blocSignalBaseChecker.isExactlyType(firstType);
      if (!isBlocSubtype || isRawBase) {
        reporter.atNode(typeArguments, _code);
      }
    });
  }
}
