// Ignore deprecated_member_use due to custom_lint_builder parameter signature.
// ignore_for_file: deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:bloc_signals_lint/src/fixes/prefer_read_in_callbacks_fix.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// A lint rule that suggests using `context.read<T>()` instead of
/// `context.watch<T>()` inside event callback closures.
class PreferBlocSignalProviderReadInCallbacks extends DartLintRule {
  /// Creates a [PreferBlocSignalProviderReadInCallbacks] lint rule.
  const PreferBlocSignalProviderReadInCallbacks() : super(code: _code);

  static const _code = LintCode(
    name: 'prefer_bloc_signal_provider_read_in_callbacks',
    problemMessage:
        'Prefer using "context.read<T>()" inside event callbacks instead '
        'of "context.watch<T>()".',
    correctionMessage:
        'Change "context.watch<T>()" to "context.read<T>()" to prevent '
        'unnecessary rebuild registrations.',
  );

  @override
  List<Fix> getFixes() => [PreferReadInCallbacksFix()];

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((node) {
      if (node.methodName.name != 'watch') return;

      final target = node.target;
      if (target == null) return;
      if (target.toSource() != 'context') return;

      final enclosingFunction = node.thisOrAncestorOfType<FunctionExpression>();
      if (enclosingFunction == null) return;

      final parentArg =
          enclosingFunction.thisOrAncestorOfType<NamedExpression>();
      if (parentArg != null) {
        final paramName = parentArg.name.label.name;
        if (paramName.startsWith('on') || paramName.endsWith('Callback')) {
          reporter.atNode(node.methodName, code);
        }
      }
    });
  }
}
