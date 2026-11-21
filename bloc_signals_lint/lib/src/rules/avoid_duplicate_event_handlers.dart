import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';
import 'package:bloc_signals_lint/src/utils/bloc_container_utils.dart';

/// A lint rule that flags duplicate `on<E>` event handler
/// registrations for the same event type `E` across a `BlocSignal` or
/// `BlocSignalMixin` class or mixin declaration (enforcing at most one handler
/// per event type `E`).
class AvoidDuplicateEventHandlers extends AnalysisRule {
  /// Creates an [AvoidDuplicateEventHandlers] lint rule.
  new()
    : super(
        name: 'avoid_duplicate_event_handlers',
        description:
            'Flag duplicate on<E> event handler registrations for the same '
            'event type E in a BlocSignal class.',
      );

  /// The diagnostic code reported by this rule.
  static const LintCode code = LintCode(
    'avoid_duplicate_event_handlers',
    'Duplicate event handler registered for event type. '
        'Each event type should have at most one handler.',
    correctionMessage:
        'Remove the duplicate handler or consolidate logic into '
        'a single handler.',
  );

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

  final AvoidDuplicateEventHandlers rule;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    _checkDeclaration(node);
  }

  @override
  void visitMixinDeclaration(MixinDeclaration node) {
    _checkDeclaration(node);
  }

  void _checkDeclaration(AstNode declaration) {
    if (!BlocContainerUtils.isBlocSignalHost(declaration)) return;

    final registeredResolved = <DartType>{};
    final registeredUnresolved = <String>{};

    declaration.visitChildren(
      _OnMethodVisitor(declaration, (node, typeArg) {
        final resolvedType = typeArg.type;
        if (resolvedType != null &&
            resolvedType is! DynamicType &&
            resolvedType is! InvalidType) {
          if (!registeredResolved.add(resolvedType)) {
            rule.reportAtNode(node);
          }
          return;
        }

        final typeName = typeArg.toSource();
        if (!registeredUnresolved.add(typeName)) {
          rule.reportAtNode(node);
        }
      }),
    );
  }
}

class _OnMethodVisitor extends RecursiveAstVisitor<void> {
  new(this.hostDeclaration, this.onCallFound);

  final AstNode hostDeclaration;
  final void Function(MethodInvocation node, TypeAnnotation typeArg)
  onCallFound;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'on' &&
        BlocContainerUtils.isSelfOrUnqualifiedTarget(node.realTarget) &&
        identical(
          BlocContainerUtils.nearestContainerDeclaration(node),
          hostDeclaration,
        )) {
      final typeArgs = node.typeArguments?.arguments;
      if (typeArgs != null && typeArgs.isNotEmpty) {
        onCallFound(node, typeArgs.first);
      }
    }
    super.visitMethodInvocation(node);
  }
}
