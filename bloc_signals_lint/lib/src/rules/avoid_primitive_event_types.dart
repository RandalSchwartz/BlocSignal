// Ignore deprecated_member_use due to custom_lint_builder parameter signature.
// ignore_for_file: deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/listener.dart';
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

  static const _blocSignalChecker = TypeChecker.fromName(
    'BlocSignal',
    packageName: 'bloc_signals',
  );

  static const _blocSignalMixinChecker = TypeChecker.fromName(
    'BlocSignalMixin',
    packageName: 'bloc_signals',
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

    // Check extends clause
    final extendsClause = node.extendsClause;
    if (extendsClause != null) {
      final superclass = extendsClause.superclass;
      final superclassName = superclass.toSource().split('<').first.trim();
      final staticType = superclass.type;
      final isBlocSuperclass = _isBlocClassName(superclassName) ||
          (staticType != null &&
              _blocSignalChecker.isAssignableFromType(staticType));

      if (isBlocSuperclass) {
        final typeArgs = superclass.typeArguments?.arguments;
        if (typeArgs == null || typeArgs.isEmpty) {
          if (_isBlocClassName(superclassName)) {
            violations.add(superclass);
          }
        } else {
          final eventTypeNode = typeArgs.first;
          if (isPrimitiveType(eventTypeNode.toSource())) {
            violations.add(eventTypeNode);
          }
        }
      }
    }

    // Check with clause
    final withClause = node.withClause;
    if (withClause != null) {
      for (final mixinType in withClause.mixinTypes) {
        final mixinName = mixinType.toSource().split('<').first.trim();
        final staticType = mixinType.type;
        final isBlocMixin = _isBlocClassName(mixinName) ||
            (staticType != null &&
                (_blocSignalMixinChecker.isAssignableFromType(staticType) ||
                    _blocSignalChecker.isAssignableFromType(staticType)));

        if (isBlocMixin) {
          final typeArgs = mixinType.typeArguments?.arguments;
          if (typeArgs == null || typeArgs.isEmpty) {
            if (_isBlocClassName(mixinName)) {
              violations.add(mixinType);
            }
          } else {
            final eventTypeNode = typeArgs.first;
            if (isPrimitiveType(eventTypeNode.toSource())) {
              violations.add(eventTypeNode);
            }
          }
        }
      }
    }

    return violations;
  }

  static bool _isBlocClassName(String name) {
    return name == 'BlocSignal' ||
        name == 'ReplayBloc' ||
        name == 'HydratedBloc' ||
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
      final violations = findViolations(node);
      for (final violation in violations) {
        reporter.atNode(
          violation,
          code,
          arguments: [violation.toSource()],
        );
      }
    });
  }
}
