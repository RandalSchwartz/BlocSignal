// Ignore deprecated_member_use due to custom_lint_builder parameter signature.
// ignore_for_file: deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:bloc_signals_lint/src/fixes/replace_positional_replay_constructor_fix.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// A lint rule that flags `super.positional(...)` invocations in
/// `ReplayCubit` and `ReplayBloc` subclasses, recommending the standard
/// `super(initialState: ...)`.
class PreferNamedReplayConstructor extends DartLintRule {
  /// Creates a [PreferNamedReplayConstructor] lint rule.
  const PreferNamedReplayConstructor() : super(code: _code);

  static const _code = LintCode(
    name: 'prefer_named_replay_constructor',
    problemMessage: 'Super-constructor call uses deprecated positional syntax '
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
  List<Fix> getFixes() => [ReplacePositionalReplayConstructorFix()];

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSuperConstructorInvocation((node) {
      if (node.constructorName?.name != 'positional') return;

      final classNode = node.thisOrAncestorOfType<ClassDeclaration>();
      if (classNode == null) return;

      final classElement = classNode.declaredFragment?.element;
      final extendsClause = classNode.extendsClause?.superclass.toSource();

      final isReplayContainer = (classElement != null &&
              (_replayCubitChecker.isSuperOf(classElement) ||
                  _replayBlocChecker.isSuperOf(classElement))) ||
          (extendsClause != null &&
              (extendsClause.startsWith('ReplayCubit') ||
                  extendsClause.startsWith('ReplayBloc')));

      if (isReplayContainer) {
        reporter.atNode(node, code);
      }
    });
  }
}
