import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:bloc_signals_lint/src/utils/bloc_container_utils.dart';

/// A lint rule that flags `context.select(...)` and `context.value(...)`
/// invocations outside `build()` (such as inside event callbacks, closures,
/// `computed()`/`effect()`, or non-`build` lifecycle methods like `initState`,
/// `didChangeDependencies`, and `dispose`).
class AvoidContextSelectOutsideBuild extends AnalysisRule {
  /// Creates an [AvoidContextSelectOutsideBuild] lint rule.
  new()
    : super(
        name: 'avoid_context_select_outside_build',
        description:
            'Avoid calling context.select() or context.value() outside '
            'build() methods.',
      );

  /// The diagnostic code reported by this rule.
  static const LintCode code = LintCode(
    'avoid_context_select_outside_build',
    'Avoid calling "context.{0}(...)" outside build(), as reactive '
        'subscriptions can only be registered during widget/component build.',
    correctionMessage:
        'Use "context.read<B>()" for one-off reads in callbacks or lifecycle '
        'methods.',
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

  final AvoidContextSelectOutsideBuild rule;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final methodName = node.methodName.name;
    if (methodName != 'select' && methodName != 'value') return;
    if (!BlocContainerUtils.isBuildContextReceiver(node.target)) return;

    final enclosingMethod = node.thisOrAncestorOfType<MethodDeclaration>();
    if (enclosingMethod == null || !_isBuildMethod(enclosingMethod)) {
      rule.reportAtNode(node.methodName, arguments: [methodName]);
      return;
    }

    if (!_isOnlyInsideSyncBuilderCallbacks(node)) {
      rule.reportAtNode(node.methodName, arguments: [methodName]);
    }
  }

  static bool _isOnlyInsideSyncBuilderCallbacks(AstNode node) {
    var current = node.parent;
    while (current != null && current is! MethodDeclaration) {
      if (current is FunctionExpression) {
        final parent = current.parent;
        final isBuilderArg =
            parent is NamedArgument && parent.name.lexeme == 'builder';
        if (!isBuilderArg) {
          return false;
        }
      }
      current = current.parent;
    }
    return true;
  }

  static bool _isBuildMethod(MethodDeclaration method) {
    final name = method.name.lexeme;
    return name == 'build' ||
        name.startsWith('build') ||
        name.startsWith('_build');
  }
}
