// Ignore deprecated_member_use due to custom_lint_builder parameter signature.
// ignore_for_file: deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
import 'package:bloc_signals_lint/src/utils/bloc_container_utils.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// A lint rule that flags `BlocSignal` and `BlocSignalMixin` declarations
/// that use primitive or untyped types (`int`, `String`, `bool`, `double`,
/// `num`, `dynamic`, `Object`, etc.) for their `Event` generic type parameter.
class AvoidPrimitiveEventTypes extends DartLintRule {
  /// Creates an [AvoidPrimitiveEventTypes] lint rule.
  const AvoidPrimitiveEventTypes() : super(code: _code);

  static const _code = LintCode(
    name: 'avoid_primitive_event_types',
    problemMessage:
        'Avoid using primitive or untyped types ("{0}") for BlocSignal '
        'events. Events should be dedicated sealed classes or records.',
    correctionMessage: 'Define a dedicated event class or record (for example, '
        '"sealed class MyEvent {}") to model state transitions cleanly.',
  );

  static const _primitiveTypeNames = <String>{
    'int',
    'String',
    'bool',
    'double',
    'num',
    'dynamic',
    'Object',
    'void',
    'Null',
  };

  /// Returns whether [typeName] represents a primitive or untyped Dart type.
  static bool isPrimitiveType(String typeName) {
    final clean = typeName.replaceAll('?', '').trim();
    return _primitiveTypeNames.contains(clean);
  }

  /// Finds all AST nodes violating this rule within a class declaration.
  static List<AstNode> findViolations(ClassDeclaration node) {
    final violations = <AstNode>[];

    final extendsClause = node.extendsClause;
    if (extendsClause != null) {
      _checkNamedType(extendsClause.superclass, violations);
    }

    final withClause = node.withClause;
    if (withClause != null) {
      for (final mixinType in withClause.mixinTypes) {
        _checkNamedType(mixinType, violations);
      }
    }

    return violations;
  }

  /// Finds all AST nodes violating this rule within a mixin declaration's
  /// `on` constraints.
  static List<AstNode> findMixinViolations(MixinDeclaration node) {
    final violations = <AstNode>[];
    final onClause = node.onClause;
    if (onClause != null) {
      for (final constraint in onClause.superclassConstraints) {
        _checkNamedType(constraint, violations);
      }
    }
    return violations;
  }

  static void _checkNamedType(
    NamedType namedType,
    List<AstNode> violations,
  ) {
    final typeName = namedType.toSource().split('<').first.trim();
    final staticType = namedType.type;
    final isBlocType = _isBlocClassName(typeName) ||
        (staticType != null &&
            (BlocContainerUtils.blocSignalChecker
                    .isAssignableFromType(staticType) ||
                BlocContainerUtils.blocSignalMixinChecker
                    .isAssignableFromType(staticType)));

    if (!isBlocType) return;

    final typeArgs = namedType.typeArguments?.arguments;
    if (typeArgs == null || typeArgs.isEmpty) {
      if (_isBlocClassName(typeName)) {
        violations.add(namedType);
      }
    } else {
      final eventTypeNode = typeArgs.first;
      if (isPrimitiveType(eventTypeNode.toSource())) {
        violations.add(eventTypeNode);
      }
    }
  }

  static bool _isBlocClassName(String name) {
    return name == 'BlocSignal' ||
        name == 'ReplayBloc' ||
        name == 'HydratedBloc' ||
        name == 'HydratedBlocSignal' ||
        name == 'BlocSignalMixin' ||
        name == 'ReplayBlocMixin';
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
          arguments: [violation.toSource()],
        );
      }
    });
    context.registry.addMixinDeclaration((node) {
      for (final violation in findMixinViolations(node)) {
        reporter.atNode(
          violation,
          code,
          arguments: [violation.toSource()],
        );
      }
    });
  }
}
