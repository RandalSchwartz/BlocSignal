import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';

/// A lint rule that flags manual calls to `.close()` on state containers
/// retrieved via `context.read<T>()` or `BlocSignalProvider.of(context)`.
class AvoidManualCloseOnProvidedBloc extends AnalysisRule {
  /// Creates an [AvoidManualCloseOnProvidedBloc] lint rule.
  new()
    : super(
        name: 'avoid_manual_close_on_provided_bloc',
        description:
            'Prevent manual close() calls on state containers managed by '
            'BlocSignalProvider.',
      );

  /// The diagnostic code reported by this rule.
  static const LintCode code = LintCode(
    'avoid_manual_close_on_provided_bloc',
    'Do not manually call close() on state containers managed by '
        'BlocSignalProvider.',
    correctionMessage:
        'Let BlocSignalProvider manage container disposal automatically when '
        'unmounted.',
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

  final AvoidManualCloseOnProvidedBloc rule;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name != 'close') return;

    final target = node.target;
    if (target == null) return;

    if (_isProviderLookup(target)) {
      rule.reportAtNode(node.methodName);
    }
  }

  bool _isProviderLookup(Expression target) {
    if (target is! MethodInvocation) return false;

    final receiver = target.target;
    if (receiver == null) return false;

    final name = target.methodName.name;
    if (name == 'read' || name == 'watch') {
      return _isBuildContext(receiver);
    }
    if (name == 'of') {
      return _isBlocSignalProvider(receiver);
    }
    return false;
  }

  bool _isBuildContext(Expression target) {
    final targetType = target.staticType;
    if (targetType != null &&
        targetType is! DynamicType &&
        targetType is! InvalidType) {
      return targetType.getDisplayString().contains('BuildContext');
    }
    final targetSource = target.toSource();
    return targetSource == 'context' ||
        targetSource.endsWith('.context') ||
        targetSource == 'ctx' ||
        targetSource.endsWith('.ctx');
  }

  bool _isBlocSignalProvider(Expression receiver) {
    final receiverSource = receiver.toSource();
    if (receiverSource == 'BlocSignalProvider' ||
        receiverSource.endsWith('.BlocSignalProvider')) {
      return true;
    }
    final receiverType = receiver.staticType;
    if (receiverType != null &&
        receiverType is! DynamicType &&
        receiverType is! InvalidType) {
      return receiverType.getDisplayString().contains('BlocSignalProvider');
    }
    return false;
  }
}
