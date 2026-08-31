// Ignore deprecated_member_use due to custom_lint_builder parameter signature.
// ignore_for_file: deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:bloc_signals_lint/src/fixes/avoid_raw_signal_effects_in_bloc_fix.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// A lint rule that flags calls to top-level `effect()` inside `BlocSignalBase`
/// classes instead of the lifecycle-managed `createEffect()`.
class AvoidRawSignalEffectsInBloc extends DartLintRule {
  /// Creates an [AvoidRawSignalEffectsInBloc] lint rule.
  const AvoidRawSignalEffectsInBloc() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_raw_signal_effects_in_bloc',
    problemMessage:
        'Directly calling top-level "effect()" inside a BlocSignal container '
        'can leak subscriptions when the container is closed.',
    correctionMessage:
        'Use "createEffect()" to ensure the effect is automatically disposed '
        'when close() is invoked.',
  );

  static const _blocSignalBaseChecker = TypeChecker.fromName(
    'BlocSignalBase',
    packageName: 'bloc_signals',
  );

  @override
  List<Fix> getFixes() => [AvoidRawSignalEffectsInBlocFix()];

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((node) {
      if (node.methodName.name != 'effect') return;
      if (node.target != null) return; // Top-level effect() has no target

      final classNode = node.thisOrAncestorOfType<ClassDeclaration>();
      if (classNode == null) return;

      final classElement = classNode.declaredFragment?.element;
      final extendsClause = classNode.extendsClause?.superclass.toSource();
      final withClause = classNode.withClause?.toSource();

      final isBlocContainer = (classElement != null &&
              _blocSignalBaseChecker.isSuperOf(classElement)) ||
          (extendsClause != null &&
              (extendsClause.contains('BlocSignal') ||
                  extendsClause.contains('CubitSignal'))) ||
          (withClause != null &&
              (withClause.contains('CubitSignalMixin') ||
                  withClause.contains('BlocSignalMixin')));

      if (isBlocContainer) {
        reporter.atNode(
          node.methodName,
          code,
        );
      }
    });
  }
}
