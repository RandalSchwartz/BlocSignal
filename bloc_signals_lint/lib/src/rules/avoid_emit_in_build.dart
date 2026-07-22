// Ignore deprecated_member_use due to custom_lint_builder parameter signature.
// ignore_for_file: deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// A lint rule that flags calls to `emit()` or `add()` on state containers
/// inside Flutter `Widget.build()` methods.
class AvoidEmitInBuild extends DartLintRule {
  /// Creates an [AvoidEmitInBuild] lint rule.
  const AvoidEmitInBuild() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_emit_in_build',
    problemMessage:
        'State mutations ("{0}") should not be invoked directly inside '
        'build() methods.',
    correctionMessage:
        'Move state mutation or event dispatch to an event callback, '
        'lifecycle method, or BlocSignalListener.',
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
      final methodName = node.methodName.name;
      if (methodName != 'emit' && methodName != 'add') return;

      final target = node.target;
      if (target == null) return;
      final targetType = target.staticType;
      if (targetType == null) return;

      if (_blocSignalBaseChecker.isAssignableFromType(targetType)) {
        final enclosingMethod = node.thisOrAncestorOfType<MethodDeclaration>();
        if (enclosingMethod != null && enclosingMethod.name.lexeme == 'build') {
          reporter.atNode(
            node.methodName,
            code,
            arguments: [methodName],
          );
        }
      }
    });
  }
}
