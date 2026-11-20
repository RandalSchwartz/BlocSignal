// Ignore deprecated_member_use due to custom_lint_builder parameter signature.
// ignore_for_file: deprecated_member_use

import 'package:analyzer/error/listener.dart';
import 'package:bloc_signals_lint/src/fixes/avoid_raw_signal_effects_in_bloc_fix.dart';
import 'package:bloc_signals_lint/src/utils/bloc_container_utils.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// A lint rule that flags calls to top-level `effect()` inside `BlocSignalBase`
/// classes and mixins instead of the lifecycle-managed `createEffect()`.
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

      final container = BlocContainerUtils.nearestContainerDeclaration(node);
      if (container == null) return;

      if (BlocContainerUtils.isBlocContainerDeclaration(container)) {
        reporter.atNode(
          node.methodName,
          code,
        );
      }
    });
  }
}
