import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:bloc_signals_lint/src/utils/bloc_container_utils.dart';

/// A lint rule that flags calls to top-level `effect()` inside `BlocSignalBase`
/// classes and mixins instead of the lifecycle-managed `createEffect()`.
class AvoidRawSignalEffectsInBloc extends AnalysisRule {
  /// Creates an [AvoidRawSignalEffectsInBloc] lint rule.
  new()
    : super(
        name: 'avoid_raw_signal_effects_in_bloc',
        description:
            'Flag calls to top-level effect() inside BlocSignalBase '
            'containers instead of createEffect().',
      );

  /// The diagnostic code reported by this rule.
  static const LintCode code = LintCode(
    'avoid_raw_signal_effects_in_bloc',
    'Directly calling top-level "effect()" inside a BlocSignal container '
        'can leak subscriptions when the container is closed.',
    correctionMessage:
        'Use "createEffect()" to ensure the effect is automatically disposed '
        'when close() is invoked.',
  );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addMethodInvocation(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  new(this.rule);

  final AvoidRawSignalEffectsInBloc rule;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name != 'effect') return;
    if (node.target != null) return; // Top-level effect() has no target

    final container = BlocContainerUtils.nearestContainerDeclaration(node);
    if (container == null) return;

    if (BlocContainerUtils.isBlocContainerDeclaration(container)) {
      rule.reportAtNode(node.methodName);
    }
  }
}
