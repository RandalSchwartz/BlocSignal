// Ignore deprecated_member_use due to custom_lint_builder parameter signature.
// ignore_for_file: deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// A lint rule that flags manual calls to `.close()` on state containers
/// retrieved via `context.read<T>()` or `BlocSignalProvider.of(context)`.
class AvoidManualCloseOnProvidedBloc extends DartLintRule {
  /// Creates an [AvoidManualCloseOnProvidedBloc] lint rule.
  const AvoidManualCloseOnProvidedBloc() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_manual_close_on_provided_bloc',
    problemMessage:
        'Do not manually call close() on state containers managed by BlocSignalProvider.',
    correctionMessage:
        'Let BlocSignalProvider manage container disposal automatically when unmounted.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((node) {
      if (node.methodName.name != 'close') return;

      final target = node.target;
      if (target == null) return;

      if (_isProviderLookup(target)) {
        reporter.atNode(node.methodName, code);
      }
    });
  }

  bool _isProviderLookup(Expression target) {
    if (target is MethodInvocation) {
      final name = target.methodName.name;
      if (name == 'read' || name == 'watch' || name == 'of') {
        return true;
      }
    }
    return false;
  }
}
