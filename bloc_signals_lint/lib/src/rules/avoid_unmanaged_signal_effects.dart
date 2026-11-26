import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:bloc_signals_lint/src/utils/bloc_container_utils.dart';

/// A lint rule that flags unmanaged `effect()` calls created inside
/// Flutter `Widget` / `HookWidget` / `State` or Jaspr `Component` / `State`
/// methods without lifecycle cleanup, as well as direct `effect()` or
/// `computed()` allocations inside `build()`.
class AvoidUnmanagedSignalEffects extends AnalysisRule {
  /// Creates an [AvoidUnmanagedSignalEffects] lint rule.
  new()
    : super(
        name: 'avoid_unmanaged_signal_effects',
        description:
            'Flag unmanaged effect() calls inside Widget or State classes '
            'without lifecycle disposal tracking.',
      );

  /// The diagnostic code reported by this rule.
  static const LintCode code = LintCode(
    'avoid_unmanaged_signal_effects',
    'Signal "effect()" or "computed()" created inside widget scope '
        'without lifecycle disposal tracking.',
    correctionMessage:
        'Store effect cleanup function and dispose in dispose() or use '
        'BlocSignalListener instead.',
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

  final AvoidUnmanagedSignalEffects rule;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final methodName = node.methodName.name;
    if (methodName != 'effect' && methodName != 'computed') return;
    if (node.target != null) return;

    final enclosing = BlocContainerUtils.nearestContainerDeclaration(node);
    if (enclosing == null ||
        !BlocContainerUtils.isUiComponentOrState(enclosing)) {
      return;
    }

    if (_isDirectBuildBodyAllocation(node)) {
      // Handled by `avoid_signal_creation_in_build` to avoid duplicate
      // diagnostics on direct `build()` allocations.
      return;
    }

    if (methodName == 'effect' && node.parent is ExpressionStatement) {
      rule.reportAtNode(node.methodName);
    }
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
