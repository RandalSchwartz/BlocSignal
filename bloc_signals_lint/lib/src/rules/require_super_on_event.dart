// Ignore deprecated_member_use due to custom_lint_builder parameter signature.
// ignore_for_file: deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// A lint rule that requires `onEvent` overrides to invoke
/// `super.onEvent(event)` to preserve Zone context and event tracing.
class RequireSuperOnEvent extends DartLintRule {
  /// Creates a [RequireSuperOnEvent] lint rule.
  const RequireSuperOnEvent() : super(code: _code);

  static const _code = LintCode(
    name: 'require_super_on_event',
    problemMessage:
        "Overrides of 'onEvent' must call 'super.onEvent(event)' to preserve "
        'Zone context and transition tracing.',
    correctionMessage:
        "Add 'unawaited(Future.value(super.onEvent(event)));' or "
        "'await super.onEvent(event);' to your method body.",
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
    context.registry.addMethodDeclaration((node) {
      if (node.name.lexeme != 'onEvent') return;

      final classNode = node.thisOrAncestorOfType<ClassDeclaration>();
      if (classNode == null) return;
      final classElement = classNode.declaredFragment?.element;
      if (classElement == null) return;
      if (!_blocSignalBaseChecker.isSuperOf(classElement)) return;

      var callsSuperOnEvent = false;
      node.body.visitChildren(
        _SuperOnEventVisitor(() {
          callsSuperOnEvent = true;
        }),
      );

      if (!callsSuperOnEvent) {
        reporter.atToken(
          node.name,
          code,
        );
      }
    });
  }
}

class _SuperOnEventVisitor extends RecursiveAstVisitor<void> {
  _SuperOnEventVisitor(this.onSuperCallFound);

  final void Function() onSuperCallFound;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target is SuperExpression && node.methodName.name == 'onEvent') {
      onSuperCallFound();
    }
    super.visitMethodInvocation(node);
  }
}
