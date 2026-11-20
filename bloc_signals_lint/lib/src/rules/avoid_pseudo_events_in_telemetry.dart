// Ignore deprecated_member_use due to custom_lint_builder parameter signature.
// ignore_for_file: deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/listener.dart';
import 'package:bloc_signals_lint/src/utils/bloc_container_utils.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// A lint rule that flags `emitTelemetry('...')` calls inside `CubitSignal`
/// classes and mixins where the telemetry name matches UI event action patterns
/// (such as `Pressed`, `Clicked`, `Submitted`, `Requested`, `Tapped`, `Swiped`,
/// or `Event`).
///
/// In BlocSignal, state updates originate from method calls on Cubits or
/// declarative events on Blocs. Cubits must not use telemetry as a backdoor
/// pseudo-event bus.
class AvoidPseudoEventsInTelemetry extends DartLintRule {
  /// Creates an [AvoidPseudoEventsInTelemetry] lint rule.
  const AvoidPseudoEventsInTelemetry() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_pseudo_events_in_telemetry',
    problemMessage:
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
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((node) {
      for (final violation in findViolations(node)) {
        reporter.atNode(
          violation,
          code,
          arguments: [
            violation.toSource().replaceAll("'", '').replaceAll('"', ''),
          ],
        );
      }
    });
    context.registry.addMixinDeclaration((node) {
      for (final violation in findMixinViolations(node)) {
        reporter.atNode(
          violation,
          code,
          arguments: [
            violation.toSource().replaceAll("'", '').replaceAll('"', ''),
          ],
        );
      }
    });
  }
}

class _TelemetryInvocationVisitor extends RecursiveAstVisitor<void> {
  _TelemetryInvocationVisitor(this.hostDeclaration, this.onTelemetryCall);

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
