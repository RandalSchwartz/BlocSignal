// Ignore deprecated_member_use due to custom_lint_builder parameter signature.
// ignore_for_file: deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/listener.dart';
import 'package:bloc_signals_lint/src/fixes/add_super_on_event_fix.dart';
import 'package:bloc_signals_lint/src/utils/bloc_container_utils.dart';
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

  @override
  List<Fix> getFixes() => [AddSuperOnEventFix()];

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodDeclaration((node) {
      if (node.name.lexeme != 'onEvent') return;

      final container = BlocContainerUtils.nearestContainerDeclaration(node);
      if (container == null) return;
      if (!BlocContainerUtils.isBlocSignalHost(container)) return;

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
