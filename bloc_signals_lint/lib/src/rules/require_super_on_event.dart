import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:bloc_signals_lint/src/utils/bloc_container_utils.dart';

/// A lint rule that requires `onEvent` overrides to invoke
/// `super.onEvent(event)` to preserve Zone context and event tracing.
class RequireSuperOnEvent extends AnalysisRule {
  /// Creates a [RequireSuperOnEvent] lint rule.
  new()
    : super(
        name: 'require_super_on_event',
        description:
            'Require onEvent overrides to invoke super.onEvent(event) to '
            'preserve Zone context and event tracing.',
      );

  /// The diagnostic code reported by this rule.
  static const LintCode code = LintCode(
    'require_super_on_event',
    "Overrides of 'onEvent' must call 'super.onEvent(event)' to preserve "
        'Zone context and transition tracing.',
    correctionMessage:
        "Add 'unawaited(Future.value(super.onEvent(event)));' or "
        "'await super.onEvent(event);' to your method body.",
  );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addMethodDeclaration(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  new(this.rule);

  final RequireSuperOnEvent rule;

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
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
      rule.reportAtToken(node.name);
    }
  }
}

class _SuperOnEventVisitor extends RecursiveAstVisitor<void> {
  new(this.onSuperCallFound);

  final void Function() onSuperCallFound;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target is SuperExpression && node.methodName.name == 'onEvent') {
      onSuperCallFound();
    }
    super.visitMethodInvocation(node);
  }
}
