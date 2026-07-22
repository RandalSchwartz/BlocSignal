// Ignore deprecated_member_use due to custom_lint_builder parameter signature.
// ignore_for_file: deprecated_member_use

import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// A lint rule that flags attempts to invoke stream transformer methods
/// directly on synchronous `BlocSignalBase` instances.
class AvoidStreamTransformersOnBlocSignal extends DartLintRule {
  /// Creates an [AvoidStreamTransformersOnBlocSignal] lint rule.
  const AvoidStreamTransformersOnBlocSignal() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_stream_transformers_on_bloc_signal',
    problemMessage:
        'Stream transformer method "{0}" should not be invoked directly on '
        'synchronous state container.',
    correctionMessage:
        'Convert state to a stream using ".toStream()" or use signal '
        'effects instead.',
  );

  static const _blocSignalBaseChecker = TypeChecker.fromName(
    'BlocSignalBase',
    packageName: 'bloc_signals',
  );

  static const _streamTransformerMethods = {
    'transform',
    'debounce',
    'throttle',
    'switchMap',
    'flatMap',
    'concatMap',
    'distinct',
    'expand',
  };

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((node) {
      final methodName = node.methodName.name;
      if (!_streamTransformerMethods.contains(methodName)) return;

      final target = node.target;
      if (target == null) return;

      final targetType = target.staticType;
      if (targetType == null) return;

      if (_blocSignalBaseChecker.isAssignableFromType(targetType)) {
        reporter.atNode(
          node.methodName,
          code,
          arguments: [methodName],
        );
      }
    });
  }
}
