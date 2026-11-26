import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';
import 'package:bloc_signals_lint/src/utils/bloc_container_utils.dart';

/// A lint rule that flags `emit()` or `add()` state container mutations
/// inside `computed()` callbacks.
class AvoidEmitOrAddInComputed extends AnalysisRule {
  /// Creates an [AvoidEmitOrAddInComputed] lint rule.
  new()
    : super(
        name: 'avoid_emit_or_add_in_computed',
        description:
            'Avoid calling emit() or add() on state containers inside '
            'computed() callbacks.',
      );

  /// The diagnostic code reported by this rule.
  static const LintCode code = LintCode(
    'avoid_emit_or_add_in_computed',
    'Avoid calling "{0}()" inside a computed() callback.',
    correctionMessage:
        'computed() callbacks must be pure derivations. Move state mutations '
        'to an effect(), event handler, or method.',
    severity: DiagnosticSeverity.ERROR,
  );

  static const _signalPackages = <String>{
    'bloc_signals',
    'signals',
    'signals_core',
    'signals_flutter',
    'preact_signals',
  };

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

  final AvoidEmitOrAddInComputed rule;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final methodName = node.methodName.name;
    if (methodName != 'emit' && methodName != 'add') return;

    if (!_isInsideComputedCallback(node)) return;

    if (_isStateContainerMutation(node, methodName)) {
      rule.reportAtNode(node.methodName, arguments: [methodName]);
    }
  }

  static bool _isInsideComputedCallback(AstNode node) {
    var current = node.parent;
    while (current != null) {
      if (current is MethodDeclaration ||
          current is ConstructorDeclaration ||
          current is ClassDeclaration ||
          current is MixinDeclaration) {
        return false;
      }
      if (current is FunctionExpression) {
        final parent = current.parent;
        if (parent is ArgumentList) {
          final grandParent = parent.parent;
          if (grandParent is MethodInvocation &&
              grandParent.methodName.name == 'computed' &&
              _isSignalComputedInvocation(grandParent)) {
            return true;
          }
        }
      }
      current = current.parent;
    }
    return false;
  }

  static bool _isSignalComputedInvocation(MethodInvocation invocation) {
    final target = invocation.target;
    if (target != null &&
        (target is! SimpleIdentifier || target.element is! PrefixElement)) {
      return false;
    }
    final libraryUri = invocation.methodName.element?.library?.uri;
    return libraryUri != null &&
        libraryUri.isScheme('package') &&
        AvoidEmitOrAddInComputed._signalPackages.contains(
          libraryUri.pathSegments.firstOrNull,
        );
  }

  static bool _isStateContainerMutation(
    MethodInvocation node,
    String methodName,
  ) {
    final target = node.realTarget;
    if (BlocContainerUtils.isSelfOrUnqualifiedTarget(target)) {
      final enclosing = BlocContainerUtils.nearestContainerDeclaration(node);
      if (enclosing == null) return false;
      return methodName == 'emit'
          ? BlocContainerUtils.isBlocContainerDeclaration(enclosing)
          : BlocContainerUtils.isBlocSignalHost(enclosing);
    }

    final targetType = target!.staticType;
    if (targetType == null) return false;
    if (methodName == 'add') {
      return BlocContainerUtils.blocSignalChecker.isAssignableFromType(
            targetType,
          ) ||
          BlocContainerUtils.blocSignalMixinChecker.isAssignableFromType(
            targetType,
          );
    }
    return BlocContainerUtils.blocSignalBaseChecker.isAssignableFromType(
          targetType,
        ) ||
        BlocContainerUtils.cubitSignalMixinChecker.isAssignableFromType(
          targetType,
        ) ||
        BlocContainerUtils.blocSignalMixinChecker.isAssignableFromType(
          targetType,
        );
  }
}
