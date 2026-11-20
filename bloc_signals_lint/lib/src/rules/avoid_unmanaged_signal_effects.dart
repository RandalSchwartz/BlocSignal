// Ignore deprecated_member_use due to custom_lint_builder parameter signature.
// ignore_for_file: deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:bloc_signals_lint/src/utils/bloc_container_utils.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// A lint rule that flags unmanaged `effect()` calls created inside
/// Flutter `Widget` / `HookWidget` / `State` or Jaspr `Component` / `State`
/// methods without lifecycle cleanup, as well as direct `effect()` or
/// `computed()` allocations inside `build()`.
class AvoidUnmanagedSignalEffects extends DartLintRule {
  /// Creates an [AvoidUnmanagedSignalEffects] lint rule.
  const AvoidUnmanagedSignalEffects() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_unmanaged_signal_effects',
    problemMessage:
        'Signal "effect()" or "computed()" created inside widget scope '
        'without lifecycle disposal tracking.',
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
      final methodName = node.methodName.name;
      if (methodName != 'effect' && methodName != 'computed') return;
      if (node.target != null) return;

      final enclosing = BlocContainerUtils.nearestContainerDeclaration(node);
      if (enclosing is! ClassDeclaration ||
          !BlocContainerUtils.isUiComponentOrState(enclosing)) {
        return;
      }

      if (methodName == 'effect' && node.parent is ExpressionStatement) {
        reporter.atNode(node.methodName, code);
        return;
      }

      if (_isDirectBuildBodyAllocation(node)) {
        reporter.atNode(node.methodName, code);
      }
    });
  }

  static bool _isDirectBuildBodyAllocation(MethodInvocation node) {
    var current = node.parent;
    while (current != null) {
      if (current is FunctionExpression) {
        return false;
      }
      if (current is MethodDeclaration) {
        return current.name.lexeme == 'build';
      }
      if (current is ClassDeclaration || current is MixinDeclaration) {
        return false;
      }
      current = current.parent;
    }
    return false;
  }
}
