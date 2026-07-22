// Ignore deprecated_member_use due to custom_lint_builder parameter signature.
// ignore_for_file: deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// A lint rule that prevents external code from invoking protected state
/// emissions (`emit()`) outside the owning state container class.
class AvoidDirectSignalMutationOutsideBloc extends DartLintRule {
  /// Creates an [AvoidDirectSignalMutationOutsideBloc] lint rule.
  const AvoidDirectSignalMutationOutsideBloc() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_direct_signal_mutation_outside_bloc',
    problemMessage:
        "Protected state emission 'emit()' should not be invoked directly "
        "outside class '{0}'.",
    correctionMessage:
        "Dispatch an event via '.add()' or invoke a public method on the "
        'state container instead.',
  );

  static const _blocSignalBaseChecker = TypeChecker.fromName(
    'BlocSignalBase',
    packageName: 'bloc_signals',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((node) {
      if (node.methodName.name != 'emit') return;

      final target = node.target;
      if (target == null) return;

      final targetType = target.staticType;
      if (targetType == null) return;

      if (_blocSignalBaseChecker.isAssignableFromType(targetType)) {
        final enclosingClass = node.thisOrAncestorOfType<ClassDeclaration>();
        final enclosingElement = enclosingClass?.declaredFragment?.element;

        if (enclosingElement != null &&
            _blocSignalBaseChecker.isSuperOf(enclosingElement)) {
          return;
        }

        reporter.atNode(
          node.methodName,
          code,
          arguments: [targetType.getDisplayString()],
        );
      }
    });
  }
}
