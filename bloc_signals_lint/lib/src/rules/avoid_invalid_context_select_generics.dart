import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';
import 'package:bloc_signals_lint/src/utils/bloc_container_utils.dart';

/// A lint rule that catches incorrect usages of `context.select` with
/// missing, wrong-arity, raw `BlocSignalBase`, or non-`BlocSignalBase` generic
/// type parameters.
///
/// In `bloc_signals_flutter` and `bloc_signals_jaspr`, `context.select<B, R>`
/// requires 2 explicit generic parameters:
/// 1. `B`: A concrete `BlocSignalBase` container subtype
/// 2. `R`: The selected return value type
class AvoidInvalidContextSelectGenerics extends AnalysisRule {
  /// Creates an [AvoidInvalidContextSelectGenerics] lint rule.
  new()
    : super(
        name: 'avoid_invalid_context_select_generics',
        description:
            'Flag usages of context.select with more than 2 generic type '
            'parameters.',
      );

  /// The diagnostic code reported by this rule.
  static const LintCode code = LintCode(
    'avoid_invalid_context_select_generics',
    'In "bloc_signals_flutter" and "bloc_signals_jaspr", '
        '"context.select<B, R>" requires 2 explicit generic type parameters '
        '(<Bloc extends BlocSignalBase, Selected>).',
    correctionMessage:
        'Specify both the concrete BlocSignalBase subtype and '
        'selected type: "context.select<MyBloc, Selected>((bloc) => ...)".',
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

  final AvoidInvalidContextSelectGenerics rule;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name != 'select') return;
    if (!BlocContainerUtils.isBuildContextReceiver(node.target)) return;

    final typeArguments = node.typeArguments;
    if (typeArguments == null || typeArguments.arguments.length != 2) {
      rule.reportAtNode(typeArguments ?? node.methodName);
      return;
    }

    final firstArg = typeArguments.arguments.first;
    final firstType = firstArg.type;
    if (firstType == null || firstType is InvalidType) return;

    if (firstType is DynamicType || firstType is VoidType) {
      rule.reportAtNode(typeArguments);
      return;
    }

    final isBlocSubtype = BlocContainerUtils.blocSignalBaseChecker
        .isAssignableFromType(firstType);
    final isRawBase =
        firstArg is NamedType &&
        firstArg.typeArguments == null &&
        BlocContainerUtils.blocSignalBaseChecker.isExactlyType(firstType);
    if (!isBlocSubtype || isRawBase) {
      rule.reportAtNode(typeArguments);
    }
  }
}
