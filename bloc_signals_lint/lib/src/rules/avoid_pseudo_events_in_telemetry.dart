import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:bloc_signals_lint/src/utils/bloc_container_utils.dart';

/// A lint rule that flags `emitTelemetry('...')` calls inside `CubitSignal`
/// classes and mixins where the telemetry name matches UI event action patterns
/// (such as `Pressed`, `Clicked`, `Submitted`, `Requested`, `Tapped`, `Swiped`,
/// or `Event`).
///
/// In BlocSignal, state updates originate from method calls on Cubits or
/// declarative events on Blocs. Cubits must not use telemetry as a backdoor
/// pseudo-event bus.
class AvoidPseudoEventsInTelemetry extends AnalysisRule {
  /// Creates an [AvoidPseudoEventsInTelemetry] lint rule.
  new()
    : super(
        name: 'avoid_pseudo_events_in_telemetry',
        description:
            'Flag emitTelemetry calls inside CubitSignal that use UI '
            'pseudo-event action names.',
      );

  /// The diagnostic code reported by this rule.
  static const LintCode code = LintCode(
    'avoid_pseudo_events_in_telemetry',
    'Avoid using pseudo-event action names ("{0}") in "emitTelemetry" '
        'inside a CubitSignal.',
    correctionMessage:
        'Telemetry should record operational occurrences or domain '
        'milestones, not simulate user UI events inside a Cubit. '
        'If event modeling is needed, migrate to BlocSignal.',
  );

  static final _pseudoEventPattern = RegExp(
    r'(?:[_\-.]|^)(?:pressed|clicked|submitted|requested|tapped|swiped|event)$'
    r'|[a-z0-9](?:Pressed|Clicked|Submitted|Requested|Tapped|Swiped|Event)$',
  );

  /// Returns whether [name] resembles a UI or lifecycle event action name.
  static bool isPseudoEventName(String name) {
    return _pseudoEventPattern.hasMatch(name.trim());
  }

  /// Finds all AST nodes violating this rule within a class declaration.
  static List<AstNode> findViolations(ClassDeclaration node) {
    return _findViolationsInDeclaration(node);
  }

  /// Finds all AST nodes violating this rule within a mixin declaration.
  static List<AstNode> findMixinViolations(MixinDeclaration node) {
    return _findViolationsInDeclaration(node);
  }

  static List<AstNode> _findViolationsInDeclaration(AstNode declaration) {
    if (!BlocContainerUtils.isCubitOnlyContainer(declaration)) {
      return const [];
    }

    final violations = <AstNode>[];

    declaration.visitChildren(
      _TelemetryInvocationVisitor(declaration, (invocation, stringLiteral) {
        if (isPseudoEventName(stringLiteral.stringValue ?? '')) {
          violations.add(stringLiteral);
        }
      }),
    );

    return violations;
  }

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final visitor = _Visitor(this);
    registry
      ..addClassDeclaration(this, visitor)
      ..addMixinDeclaration(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  new(this.rule);

  final AvoidPseudoEventsInTelemetry rule;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    _reportViolations(AvoidPseudoEventsInTelemetry.findViolations(node));
  }

  @override
  void visitMixinDeclaration(MixinDeclaration node) {
    _reportViolations(AvoidPseudoEventsInTelemetry.findMixinViolations(node));
  }

  void _reportViolations(List<AstNode> violations) {
    for (final violation in violations) {
      rule.reportAtNode(
        violation,
        arguments: [
          violation.toSource().replaceAll("'", '').replaceAll('"', ''),
        ],
      );
    }
  }
}

class _TelemetryInvocationVisitor extends RecursiveAstVisitor<void> {
  new(this.hostDeclaration, this.onTelemetryCall);

  final AstNode hostDeclaration;
  final void Function(MethodInvocation invocation, SimpleStringLiteral literal)
  onTelemetryCall;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'emitTelemetry' &&
        BlocContainerUtils.isSelfOrUnqualifiedTarget(node.realTarget) &&
        identical(
          BlocContainerUtils.nearestContainerDeclaration(node),
          hostDeclaration,
        )) {
      final args = node.argumentList.arguments;
      if (args.isNotEmpty && args.first is SimpleStringLiteral) {
        onTelemetryCall(node, args.first as SimpleStringLiteral);
      }
    }
    super.visitMethodInvocation(node);
  }
}
