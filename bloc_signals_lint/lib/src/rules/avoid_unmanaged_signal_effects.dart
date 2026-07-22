// Ignore deprecated_member_use due to custom_lint_builder parameter signature.
// ignore_for_file: deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// A lint rule that flags unmanaged `effect()` calls created inside
/// Flutter `Widget` or `State` methods without lifecycle cleanup.
class AvoidUnmanagedSignalEffects extends DartLintRule {
  /// Creates an [AvoidUnmanagedSignalEffects] lint rule.
  const AvoidUnmanagedSignalEffects() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_unmanaged_signal_effects',
    problemMessage:
        'Signal "effect()" created inside widget scope without lifecycle '
        'disposal tracking.',
    correctionMessage:
        'Store effect cleanup function and dispose in dispose() or use '
        'BlocSignalListener instead.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((node) {
      if (node.methodName.name != 'effect') return;

      final enclosingClass = node.thisOrAncestorOfType<ClassDeclaration>();
      if (enclosingClass == null) return;

      final extendsClause = enclosingClass.extendsClause;
      if (extendsClause == null) return;
      final supertypeName = extendsClause.superclass.name2.lexeme;

      if (supertypeName == 'State' ||
          supertypeName == 'StatelessWidget' ||
          supertypeName == 'StatefulWidget') {
        final parent = node.parent;
        if (parent is ExpressionStatement) {
          reporter.atNode(node.methodName, code);
        }
      }
    });
  }
}
