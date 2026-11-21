import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:bloc_signals_lint/src/utils/type_checker.dart';

/// A lint rule that flags attempts to invoke stream transformer methods
/// directly on synchronous `BlocSignalBase` instances.
class AvoidStreamTransformersOnBlocSignal extends AnalysisRule {
  /// Creates an [AvoidStreamTransformersOnBlocSignal] lint rule.
  new()
    : super(
        name: 'avoid_stream_transformers_on_bloc_signal',
        description:
            'Prevent invoking stream transformer methods directly on '
            'synchronous BlocSignalBase instances.',
      );

  /// The diagnostic code reported by this rule.
  static const LintCode code = LintCode(
    'avoid_stream_transformers_on_bloc_signal',
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

  final AvoidStreamTransformersOnBlocSignal rule;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final methodName = node.methodName.name;
    if (!AvoidStreamTransformersOnBlocSignal._streamTransformerMethods.contains(
      methodName,
    )) {
      return;
    }

    final target = node.target;
    if (target == null) return;

    final targetType = target.staticType;
    if (targetType == null) return;

    if (AvoidStreamTransformersOnBlocSignal._blocSignalBaseChecker
        .isAssignableFromType(targetType)) {
      rule.reportAtNode(node.methodName, arguments: [methodName]);
    }
  }
}
