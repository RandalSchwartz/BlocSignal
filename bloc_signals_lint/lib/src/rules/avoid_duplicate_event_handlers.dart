// Ignore deprecated_member_use due to custom_lint_builder parameter signature.
// ignore_for_file: deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/listener.dart';
import 'package:bloc_signals_lint/src/utils/bloc_container_utils.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// A lint rule that flags duplicate `on<E>` event handler
/// registrations for the same event type `E` across a `BlocSignal` or
/// `BlocSignalMixin` class or mixin declaration (enforcing at most one handler
/// per event type `E`).
class AvoidDuplicateEventHandlers extends DartLintRule {
  /// Creates an [AvoidDuplicateEventHandlers] lint rule.
  const AvoidDuplicateEventHandlers() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_duplicate_event_handlers',
    problemMessage: 'Duplicate event handler registered for event type. '
        'Each event type should have at most one handler.',
    correctionMessage: 'Remove the duplicate handler or consolidate logic into '
        'a single handler.',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((classNode) {
      _checkDeclaration(classNode, reporter);
    });
    context.registry.addMixinDeclaration((mixinNode) {
      _checkDeclaration(mixinNode, reporter);
    });
  }

  void _checkDeclaration(AstNode declaration, ErrorReporter reporter) {
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
            reporter.atNode(node, code);
          }
          return;
        }

        final typeName = typeArg.toSource();
        if (!registeredUnresolved.add(typeName)) {
          reporter.atNode(node, code);
        }
      }),
    );
  }
}

class _OnMethodVisitor extends RecursiveAstVisitor<void> {
  _OnMethodVisitor(this.hostDeclaration, this.onCallFound);

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
