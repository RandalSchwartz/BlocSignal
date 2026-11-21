import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:bloc_signals_lint/src/utils/bloc_container_utils.dart';

/// A lint rule that suggests using `context.read<T>()` instead of
/// `context.watch<T>()` inside event callback closures.
class PreferBlocSignalProviderReadInCallbacks extends AnalysisRule {
  /// Creates a [PreferBlocSignalProviderReadInCallbacks] lint rule.
  new()
    : super(
        name: 'prefer_bloc_signal_provider_read_in_callbacks',
        description:
            'Prefer context.read<T>() over context.watch<T>() inside event '
            'callback closures.',
      );

  /// The diagnostic code reported by this rule.
  static const LintCode code = LintCode(
    'prefer_bloc_signal_provider_read_in_callbacks',
    'Prefer using "context.read<T>()" inside event callbacks instead '
        'of "context.watch<T>()".',
    correctionMessage:
        'Change "context.watch<T>()" to "context.read<T>()" to prevent '
        'unnecessary rebuild registrations.',
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

  final PreferBlocSignalProviderReadInCallbacks rule;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name != 'watch') return;
    if (!BlocContainerUtils.isBuildContextReceiver(node.target)) return;

    final enclosingFunction = node.thisOrAncestorOfType<FunctionExpression>();
    if (enclosingFunction == null) return;

    final parentArg = enclosingFunction.thisOrAncestorOfType<NamedArgument>();
    if (parentArg != null) {
      final paramName = parentArg.name.lexeme;
      if (paramName.startsWith('on') || paramName.endsWith('Callback')) {
        rule.reportAtNode(node.methodName);
      }
    }
  }
}
