// Ignore deprecated_member_use due to custom_lint_builder parameter signature.
// ignore_for_file: deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// A lint rule that flags duplicate `on<E>` event handler
/// registrations for the same event type `E` across a `BlocSignal` class
/// declaration (enforcing at most one handler per event type `E`).

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

  static const _blocSignalChecker = TypeChecker.fromName(
    'BlocSignal',
    packageName: 'bloc_signals',
  );

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((classNode) {
      final element = classNode.declaredFragment?.element;
      if (element == null) return;
      if (!_blocSignalChecker.isSuperOf(element)) return;

      final registeredTypes = <String>{};

      classNode.visitChildren(
        _OnMethodVisitor((node, typeName) {
          if (registeredTypes.contains(typeName)) {
            reporter.atNode(node, code);
          } else {
            registeredTypes.add(typeName);
          }
        }),
      );
    });
  }
}

class _OnMethodVisitor extends RecursiveAstVisitor<void> {
  _OnMethodVisitor(this.onDuplicateFound);

  final void Function(AstNode node, String typeName) onDuplicateFound;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'on') {
      final typeArgs = node.typeArguments?.arguments;
      if (typeArgs != null && typeArgs.isNotEmpty) {
        final typeName = typeArgs.first.toSource();
        onDuplicateFound(node, typeName);
      }
    }
    super.visitMethodInvocation(node);
  }
}
