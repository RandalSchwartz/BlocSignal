import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:bloc_signals_lint/src/utils/type_checker.dart';

/// A lint rule that flags `super.positional(...)` invocations in
/// `ReplayCubit` and `ReplayBloc` subclasses, recommending the standard
/// `super(initialState: ...)`.
class PreferNamedReplayConstructor extends AnalysisRule {
  /// Creates a [PreferNamedReplayConstructor] lint rule.
  new()
    : super(
        name: 'prefer_named_replay_constructor',
        description:
            'Flag deprecated super.positional(...) calls in ReplayCubit and '
            'ReplayBloc subclasses.',
      );

  /// The diagnostic code reported by this rule.
  static const LintCode code = LintCode(
    'prefer_named_replay_constructor',
    'Super-constructor call uses deprecated positional syntax '
        '"super.positional(...)".',
    correctionMessage:
        'Migrate to the standard named constructor "super(initialState: ...)".',
  );

  static const _replayCubitChecker = TypeChecker.fromName(
    'ReplayCubit',
    packageName: 'bloc_signals_replay',
  );

  static const _replayBlocChecker = TypeChecker.fromName(
    'ReplayBloc',
    packageName: 'bloc_signals_replay',
  );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addSuperConstructorInvocation(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  new(this.rule);

  final PreferNamedReplayConstructor rule;

  @override
  void visitSuperConstructorInvocation(SuperConstructorInvocation node) {
    if (node.constructorName?.name != 'positional') return;

    final classNode = node.thisOrAncestorOfType<ClassDeclaration>();
    if (classNode == null) return;

    final classElement = classNode.declaredFragment?.element;
    final extendsClause = classNode.extendsClause?.superclass.toSource();

    final isReplayContainer =
        (classElement != null &&
            (PreferNamedReplayConstructor._replayCubitChecker.isSuperOf(
                  classElement,
                ) ||
                PreferNamedReplayConstructor._replayBlocChecker.isSuperOf(
                  classElement,
                ))) ||
        (extendsClause != null &&
            (extendsClause.startsWith('ReplayCubit') ||
                extendsClause.startsWith('ReplayBloc')));

    if (isReplayContainer) {
      rule.reportAtNode(node);
    }
  }
}
