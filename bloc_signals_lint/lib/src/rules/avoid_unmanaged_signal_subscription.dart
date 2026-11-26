import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';
import 'package:bloc_signals_lint/src/utils/type_checker.dart';

/// A lint rule that flags discarded `ReadonlySignal.subscribe(...)` calls
/// where the returned cleanup closure is not stored or returned.
class AvoidUnmanagedSignalSubscription extends AnalysisRule {
  /// Creates an [AvoidUnmanagedSignalSubscription] lint rule.
  new()
    : super(
        name: 'avoid_unmanaged_signal_subscription',
        description:
            'Flag discarded ReadonlySignal.subscribe(...) calls whose cleanup '
            'closure is not retained.',
      );

  /// The diagnostic code reported by this rule.
  static const LintCode code = LintCode(
    'avoid_unmanaged_signal_subscription',
    'The cleanup closure returned by "subscribe()" is discarded, which can '
        'leak the signal subscription.',
    correctionMessage:
        'Store the returned cleanup function and invoke it on disposal.',
  );

  static const _signalCheckers = [
    TypeChecker.fromName('ReadonlySignal', packageName: 'preact_signals'),
    TypeChecker.fromName('ReadonlySignal', packageName: 'signals'),
    TypeChecker.fromName('ReadonlySignal', packageName: 'signals_flutter'),
    TypeChecker.fromName('ReadonlySignal', packageName: 'signals_core'),
    TypeChecker.fromName('ReadonlySignal', packageName: 'bloc_signals'),
  ];

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addExpressionStatement(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  new(this.rule);

  final AvoidUnmanagedSignalSubscription rule;

  @override
  void visitExpressionStatement(ExpressionStatement node) {
    final expr = node.expression;
    if (expr is! MethodInvocation) return;
    if (expr.methodName.name != 'subscribe') return;

    final targetType = expr.target?.staticType;
    if (targetType == null ||
        targetType is DynamicType ||
        targetType is InvalidType) {
      return;
    }

    final isSignal = AvoidUnmanagedSignalSubscription._signalCheckers.any(
      (checker) => checker.isAssignableFromType(targetType),
    );
    if (isSignal) {
      rule.reportAtNode(expr.methodName);
    }
  }
}
